import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../utils/globals.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../cart/cart_screen.dart';
import '../../utils/snackbar_helper.dart';

class ChatScreen extends StatefulWidget {
  final String remoteUserId;
  final String remoteUserName;
  final List<String> relatedRemoteIds;
  final Map<String, dynamic>? initialProduct;

  const ChatScreen({
    super.key,
    required this.remoteUserId,
    required this.remoteUserName,
    this.relatedRemoteIds = const [],
    this.initialProduct,
  });


  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _uuid = const Uuid();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isLive = false;
  bool _isSyncing = false;
  String? _error;
  String? _currentUserId;
  bool _isSending = false;

  // Pagination
  int _chatPage = 0;
  final int _pageSize = 20;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;

  // High-Performance Sync State
  List<Map<String, dynamic>> _serverMessages = [];
  final List<Map<String, dynamic>> _pendingMessages = [];

  void _endSession() async {
    if (_messages.any((m) => m['content'].toString().contains('"type":"session_ended"'))) return;
    final sessionData = {'type': 'session_ended'};
    final content = jsonEncode(sessionData);
    _sendMessage(manualContent: content);
    _sessionCountdownTimer?.cancel();
  }

  void _startSessionTimer({int? resetSeconds}) {
    _sessionCountdownTimer?.cancel();
    if (_messages.any((m) => m['content'].toString().contains('"type":"session_ended"'))) return;

    if (resetSeconds != null) {
      setState(() => _sessionRemainingSeconds = resetSeconds);
    }

    _sessionCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_sessionRemainingSeconds > 0) {
          setState(() => _sessionRemainingSeconds--);
        } else {
          _endSession();
          timer.cancel();
        }
      }
    });
  }

  String _formatSessionTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }


  // User Presence State
  String _remoteUserStatus = 'Offline';
  Color _statusColor = Colors.grey;

  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  RealtimeChannel? _statusChannel;
  Timer? _pollingTimer;
  Timer? _connectionCheckTimer;
  Timer? _sessionCountdownTimer;
  int _sessionRemainingSeconds = 300; // 5 minutes
  DateTime? _historyLimit;

  @override
  void initState() {
    super.initState();
    _currentUserId = currentUser?['id'];
    _scrollController.addListener(_onScroll);
    _initializeChat().then((_) {
      if (widget.initialProduct != null) {
        _sendProductMessage(widget.initialProduct!);
      }
    });
  }

  Future<void> _fetchHistoryLimit() async {
    try {
      final res = await _supabase
          .from('hidden_chat')
          .select('hidden_at')
          .eq('user_id', _currentUserId!)
          .eq('remote_user_id', widget.remoteUserId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _historyLimit = DateTime.parse(res['hidden_at']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching history limit: $e');
    }
  }

  Future<void> _sendProductMessage(Map<String, dynamic> product) async {
    final productData = {
      'type': 'product',
      'id': product['id'],
      'name': product['name'],
      'price': product['price']?.toString() ?? '0.00',
      'image': (product['image_url']?.toString() ?? '').split(',')[0],
      'seller_id': product['seller_id'],
      'stock': product['quantity'] ?? 0,
    };

    final content = jsonEncode(productData);

    // Check if the last message was the same product to avoid spam
    if (_messages.isNotEmpty) {
      final lastMsg = _messages.last;
      if (lastMsg['content'] == content) return;
    }

    _sendMessage(manualContent: content);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    _statusChannel?.unsubscribe();
    _pollingTimer?.cancel();
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100) {
      if (!_isLoadingOlder && _hasMoreOlder) {
        _fetchMoreOlderMessages();
      }
    }
  }

  Future<void> _initializeChat() async {
    if (_currentUserId == null) return;

    await _fetchHistoryLimit();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    _pollingTimer?.cancel();
    _connectionCheckTimer?.cancel();

    try {
      // 1. Initial fetches
      await Future.wait([
        _fetchMessages(),
        _fetchRemoteUserStatus(),
        _markAsRead(), // New: Mark incoming messages as read
      ]);


      // 2. Setup high-speed streams
      _setupLiveStream();
      _setupStatusSubscription();

      // 3. Status watchdog
      _connectionCheckTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_isLive) {
          _startPolling();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Sync issue: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRemoteUserStatus() async {
    try {
      final data = await _supabase
          .from('user')
          .select('user_status')
          .eq('id', widget.remoteUserId)
          .maybeSingle();

      if (data != null && mounted) {
        _updateStatusState(data['user_status']);
      }
    } catch (e) {
      debugPrint('Error fetching user status: $e');
    }
  }

  void _setupStatusSubscription() {
    _statusChannel?.unsubscribe();

    _statusChannel = _supabase.channel('user_status_${widget.remoteUserId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'user',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.remoteUserId,
      ),
      callback: (payload) {
        if (mounted) {
          _updateStatusState(payload.newRecord['user_status']);
        }
      },
    )
        .subscribe();
  }

  void _updateStatusState(String? status) {
    if (status == null) return;

    setState(() {
      _remoteUserStatus = status;
      switch (status.replaceAll(' ', '').toLowerCase()) {
        case 'online':
          _statusColor = Colors.greenAccent;
          break;
        case 'idle':
        case 'away':
          _statusColor = Colors.orangeAccent;
          break;
        case 'donotdisturb':
        case 'busy':
        case 'dnd':
          _statusColor = Colors.redAccent;
          break;
        default:
          _statusColor = Colors.grey;
      }
    });
  }

  void _setupLiveStream() {
    _streamSubscription?.cancel();

    _streamSubscription = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen(
          (data) {
        final incoming = data.where((m) {
          if (_historyLimit != null) {
            final createdAt = DateTime.parse(m['created_at']);
            return createdAt.isAfter(_historyLimit!);
          }
          return true;
        }).toList();

        if (mounted) {
          final myId = _currentUserId?.toLowerCase();

          final targetIds = {widget.remoteUserId, ...widget.relatedRemoteIds}.map((id) => id.toString().toLowerCase()).toSet();

          final chatMessages = incoming.where((msg) {
            final sId = msg['sender_id']?.toString().toLowerCase();
            final rId = msg['receiver_id']?.toString().toLowerCase();

            return (sId == myId && targetIds.contains(rId)) || (targetIds.contains(sId) && rId == myId);
          }).toList();

          // New: If we see new messages from ANY of the target IDs, mark them as read
          final hasUnreadFromRemote = chatMessages.any((m) =>
          targetIds.contains(m['sender_id']?.toString().toLowerCase()) &&
              m['is_read'] != true
          );

          if (hasUnreadFromRemote) {
            _markAsRead();
          }



          setState(() {
            _serverMessages = List<Map<String, dynamic>>.from(chatMessages);
            // Deduplicate: If any server message matches a pending one, remove the pending one
            _pendingMessages.removeWhere((pending) {
              return _serverMessages.any((srv) =>
              srv['content'] == pending['content'] &&
                  srv['sender_id'] == pending['sender_id']
              );
            });

            _messages = [..._serverMessages, ..._pendingMessages];
            _isLoading = false;
            _isLive = true;
            _isSyncing = false;
            _pollingTimer?.cancel();
            _startSessionTimer(resetSeconds: 300);
          });
          _scrollToBottom();

        }
      },
      onError: (err) {
        debugPrint('Live Stream Connection Error: $err');
        if (mounted && !_isSyncing) _startPolling();
      },
    );
  }

  void _startPolling() {
    if (_isLive || !mounted) return;
    _pollingTimer?.cancel();

    setState(() => _isSyncing = true);

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && !_isLive) {
        _fetchMessages(isBackground: true);
        _fetchRemoteUserStatus(); // Also poll status if live fails
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    try {
      final List<String> targetIds = {
        widget.remoteUserId,
        ...widget.relatedRemoteIds
      }.toList();

      setState(() {
        _chatPage = 0;
        _hasMoreOlder = true;
      });

      final res = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_currentUserId,receiver_id.in.("${targetIds.join('","')}")),and(sender_id.in.("${targetIds.join('","')}"),receiver_id.eq.$_currentUserId)')
          .order('created_at', ascending: false)
          .limit(_pageSize);

      if (mounted) {
        List<Map<String, dynamic>> incoming = List<Map<String, dynamic>>.from(res).reversed.toList();

        // Filter by history limit (per-user non-destructive deletion)
        if (_historyLimit != null) {
          incoming = incoming.where((m) {
            final createdAt = DateTime.parse(m['created_at']);
            return createdAt.isAfter(_historyLimit!);
          }).toList();
        }

        setState(() {
          _serverMessages = incoming;
          _messages = [..._serverMessages, ..._pendingMessages];
          _isLoading = false;
          if (isBackground) _isSyncing = true;

          // Calculate sticky timer based on last message
          if (_messages.isNotEmpty && !_messages.any((m) => m['content'].toString().contains('"type":"session_ended"'))) {
            final lastMsgAt = DateTime.parse(_messages.last['created_at']).toUtc();
            final now = DateTime.now().toUtc();
            final difference = now.difference(lastMsgAt).inSeconds;

            // If less than 5 minutes has passed, set timer to remaining
            if (difference < 300) {
              _startSessionTimer(resetSeconds: 300 - difference);
            } else {
              // More than 5 minutes passed while away, auto-end it
              _sessionRemainingSeconds = 0;
              _endSession();
            }
          }
        });
        _hasMoreOlder = res.length == _pageSize;
        _scrollToBottom(immediate: !isBackground);
      }

    } catch (e) {
      debugPrint('Sync Fetch Error: $e');
      if (!isBackground) rethrow;
    }
  }

  Future<void> _fetchMoreOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreOlder) return;

    setState(() => _isLoadingOlder = true);
    try {
      _chatPage++;
      final List<String> targetIds = {
        widget.remoteUserId,
        ...widget.relatedRemoteIds
      }.toList();

      final from = _chatPage * _pageSize;
      final to = from + _pageSize - 1;

      final res = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_currentUserId,receiver_id.in.("${targetIds.join('","')}")),and(sender_id.in.("${targetIds.join('","')}"),receiver_id.eq.$_currentUserId)')
          .order('created_at', ascending: false)
          .range(from, to);

      if (mounted) {
        final olderMessages = List<Map<String, dynamic>>.from(res).reversed.toList();

        // Save current scroll position to maintain position after prepending
        final previousScrollOffset = _scrollController.position.pixels;
        final previousMaxScroll = _scrollController.position.maxScrollExtent;

        setState(() {
          _serverMessages.insertAll(0, olderMessages);
          _messages = [..._serverMessages, ..._pendingMessages];
          _hasMoreOlder = res.length == _pageSize;
        });

        // Use a post-frame callback to adjust scroll position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newMaxScroll = _scrollController.position.maxScrollExtent;
            final scrollIncrease = newMaxScroll - previousMaxScroll;
            _scrollController.jumpTo(previousScrollOffset + scrollIncrease);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching older messages: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOlder = false);
    }
  }

  Future<void> _sendMessage({String? manualContent}) async {
    final text = manualContent ?? _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || _isSending) return;

    final tempId = _uuid.v4();
    final optimisticMsg = {
      'id': tempId,
      'sender_id': _currentUserId,
      'receiver_id': widget.remoteUserId,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_sending': true,
    };

    setState(() {
      _pendingMessages.add(optimisticMsg);
      _messages = [..._serverMessages, ..._pendingMessages];
      _isSending = true;
    });
    if (manualContent == null) _messageController.clear();
    _scrollToBottom();

    try {
      // Use select().single() for instant notification of success
      final response = await _supabase.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.remoteUserId,
        'content': text,
      }).select().single();

      if (mounted) {
        setState(() {
          // Replace immediately in local state
          _pendingMessages.removeWhere((m) => m['id'] == tempId);
          // If the server message isn't in _serverMessages yet, we can add it to _serverMessages temporarily
          // so it shows WITH ticks immediately.
          if (!_serverMessages.any((m) => m['id'] == response['id'])) {
            _serverMessages.add(response);
          }
          _messages = [..._serverMessages, ..._pendingMessages];
          _startSessionTimer(resetSeconds: 300); // Reset timer on send
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingMessages.removeWhere((m) => m['id'] == tempId);
          _messages = [..._serverMessages, ..._pendingMessages];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _markAsRead() async {
    if (_currentUserId == null) return;

    final List<String> targetSenderIds = {
      widget.remoteUserId,
      ...widget.relatedRemoteIds
    }.toList();

    try {
      // 1. Fetch the exact IDs of messages that need marking as read
      final data = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', _currentUserId!)
          .inFilter('sender_id', targetSenderIds)
          .not('is_read', 'eq', true);

      final List<dynamic> rows = data as List;
      if (rows.isEmpty) return;

      final List<String> idsToUpdate = rows.map((r) => r['id'].toString()).toList();
      debugPrint('ID-Direct Clear: Attempting to update ${idsToUpdate.length} specific messages');

      // 2. Update by specific ID list (This is harder for RLS to block if select is allowed)
      final response = await _supabase
          .from('messages')
          .update({'is_read': true})
          .inFilter('id', idsToUpdate)
          .select();

      debugPrint('ID-Direct SUCCESS: ${response.length} messages updated.');
    } catch (e) {
      debugPrint('ID-Direct Error: $e');
    }
  }







  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return 'Today';
    if (msgDate == yesterday) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(date);
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (immediate) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 400,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['sender_id'].toString().toLowerCase() == _currentUserId?.toLowerCase();
    final isSending = message['is_sending'] == true;
    final createdAt = DateTime.tryParse(message['created_at'] ?? '')?.toLocal() ?? DateTime.now();
    final timeStr = DateFormat('HH:mm').format(createdAt);
    final String content = message['content'] ?? '';

    bool isProduct = false;
    bool isSessionEnded = false;
    Map<String, dynamic>? productInfo;
    if (content.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          if (decoded['type'] == 'product') {
            productInfo = Map<String, dynamic>.from(decoded);
            isProduct = true;
          } else if (decoded['type'] == 'session_ended') {
            isSessionEnded = true;
          }
        }
      } catch (_) {}
    }

    if (isSessionEnded) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            "Chat Session Ended",
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 2,
              bottom: 2,
              left: isMe ? 60 : 8,
              right: isMe ? 8 : 60,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white // White bubble for sent messages
                  : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF202C33) : Colors.white),

              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),

                  blurRadius: 1,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: isProduct ? ProductChatCard(
              product: productInfo!,
              isMe: isMe,
              time: timeStr,
              isSending: isSending,
              currentUserId: _currentUserId,
            ) : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, right: 55),
                  child: Text(
                    message['content'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.black87 : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                      fontSize: 16,
                    ),

                  ),
                ),
                PositionChanged(
                  right: 0,
                  bottom: -2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isMe ? Colors.black54 : Colors.grey.shade500,
                          fontSize: 11,
                        ),

                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isSending ? Icons.access_time_rounded : Icons.done_all_rounded,
                          size: 14,
                          color: isSending ? Colors.black45 : Colors.blueAccent, // Blue double ticks
                        ),

                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.remoteUserName)),
        body: const Center(child: Text("Please sign in to chat.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.remoteUserName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _remoteUserStatus,
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.9), letterSpacing: 0.1),
                    ),
                    if (!_messages.any((m) => m['content'].toString().contains('"type":"session_ended"'))) ...[
                      const SizedBox(width: 6),
                      Text(
                        "• ${_formatSessionTime(_sessionRemainingSeconds)}",
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (!_messages.any((m) => m['content'].toString().contains('"type":"session_ended"')))
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'end') _endSession();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'end',
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text("End Chat"),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0B141A)
              : const Color(0xFFEFE7DE),
          child: Column(


            children: [
              Expanded(
                child: _isLoading
                    ? const ChatDetailSkeleton()
                    : _error != null
                    ? _buildErrorState()
                    : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _messages.length + (_hasMoreOlder ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0 && _hasMoreOlder) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: _isLoadingOlder
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const SizedBox(height: 10), // Gap when not loading yet
                        ),
                      );
                    }

                    final adjustedIndex = _hasMoreOlder ? index - 1 : index;
                    final message = _messages[adjustedIndex];
                    final date = DateTime.tryParse(message['created_at'] ?? '')?.toLocal() ?? DateTime.now();

                    bool showDateHeader = false;
                    if (adjustedIndex == 0) {
                      showDateHeader = true;
                    } else {
                      final prevDate = DateTime.tryParse(_messages[adjustedIndex - 1]['created_at'] ?? '')?.toLocal() ?? DateTime.now();
                      if (!_isSameDay(date, prevDate)) {
                        showDateHeader = true;
                      }
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showDateHeader) _buildDateSeparator(_formatDateSeparator(date)),
                        _buildMessageBubble(message),
                      ],
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))

                  ],
                ),
                child: Row(
                  children: [
                    if (!_messages.any((m) => m['content'].toString().contains('"type":"session_ended"')))
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 5,
                          minLines: 1,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      )
                    else
                      const Expanded(
                        child: Center(
                          child: Text(
                            "This session has ended.",
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    if (!_messages.any((m) => m['content'].toString().contains('"type":"session_ended"')))
                      const SizedBox(width: 10),
                    if (!_messages.any((m) => m['content'].toString().contains('"type":"session_ended"')))
                      GestureDetector(
                        onTap: () => _sendMessage(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))
                            ],
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No messages yet.\nSay hello!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sync_problem_rounded, size: 56, color: Colors.orange.shade300),
          const SizedBox(height: 16),
          Text(
            "Sync Connection Issue",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _error ?? "We couldn't connect to the live chat feed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeChat,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Reconnect Now"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade800.withValues(alpha: 0.8)
              : Colors.blueGrey.shade100.withValues(alpha: 0.9),

          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),

              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.blueGrey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class PositionChanged extends StatelessWidget {
  final double? right;
  final double? bottom;
  final Widget child;

  const PositionChanged({super.key, this.right, this.bottom, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: child,
    );
  }
}

class ProductChatCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isMe;
  final String time;
  final bool isSending;
  final String? currentUserId;

  const ProductChatCard({
    super.key,
    required this.product,
    required this.isMe,
    required this.time,
    required this.isSending,
    this.currentUserId,
  });

  @override
  State<ProductChatCard> createState() => _ProductChatCardState();
}

class _ProductChatCardState extends State<ProductChatCard> {
  int? _currentStock;
  bool _isActionLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _currentStock = widget.product['stock'];
    _fetchLatestStock();
  }

  Future<void> _fetchLatestStock() async {
    try {
      final res = await _supabase
          .from('product')
          .select('quantity')
          .eq('id', widget.product['id'])
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _currentStock = res['quantity'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching stock: $e');
    }
  }

  Future<void> _handleBuyNow() async {
    if (widget.currentUserId == null) {
      snackbar('Please login to buy', Colors.orange);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final response = await _supabase
          .from('cart_item')
          .select('id, quantity')
          .eq('user_id', widget.currentUserId!)
          .eq('product_id', widget.product['id'])
          .maybeSingle();

      if (response == null) {
        await _supabase.from('cart_item').insert({
          'user_id': widget.currentUserId,
          'product_id': widget.product['id'],
          'quantity': 1,
        });
      } else {
        await _supabase
            .from('cart_item')
            .update({'quantity': (response['quantity'] as int) + 1})
            .eq('id', response['id']);
      }

      if (mounted) {
        snackbar('Added to cart!', Colors.green);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartScreen()),
        );
      }
    } catch (e) {
      if (mounted) snackbar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isViewerSeller = widget.product['seller_id']?.toString() == widget.currentUserId?.toString();

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.product['image'] ?? '',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product['name'] ?? 'Product',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.2,
                          color: widget.isMe ? Colors.black87 : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'RM ${widget.product['price']}',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isViewerSeller ? null : _handleBuyNow,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isViewerSeller
                      ? [Colors.grey.shade600, Colors.grey.shade700]
                      : [Colors.blue.shade600, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: (isViewerSeller ? Colors.grey : Colors.blue).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: _isActionLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isViewerSeller) ...[
                    const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    isViewerSeller ? 'In Stock: ${_currentStock ?? '...'}' : 'Buy Now',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.time,
                style: TextStyle(
                  color: widget.isMe ? Colors.black54 : Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
              if (widget.isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  widget.isSending ? Icons.access_time_rounded : Icons.done_all_rounded,
                  size: 13,
                  color: widget.isSending ? Colors.black45 : Colors.blueAccent,
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
