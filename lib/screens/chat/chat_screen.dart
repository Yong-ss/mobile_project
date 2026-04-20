import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../utils/globals.dart';
import '../../widgets/shimmer_skeletons.dart';

class ChatScreen extends StatefulWidget {
  final String remoteUserId;
  final String remoteUserName;

  const ChatScreen({
    super.key,
    required this.remoteUserId,
    required this.remoteUserName,
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

  // High-Performance Sync State
  List<Map<String, dynamic>> _serverMessages = [];
  final List<Map<String, dynamic>> _pendingMessages = [];


  // User Presence State
  String _remoteUserStatus = 'Offline';
  Color _statusColor = Colors.grey;

  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  RealtimeChannel? _statusChannel;
  Timer? _pollingTimer;
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    _currentUserId = currentUser?['id'];
    _initializeChat();
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

  Future<void> _initializeChat() async {
    if (_currentUserId == null) return;

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
        if (mounted) {
          final myId = _currentUserId?.toLowerCase();
          final remoteId = widget.remoteUserId.toLowerCase();

          final chatMessages = data.where((msg) {
            final sId = msg['sender_id']?.toString().toLowerCase();
            final rId = msg['receiver_id']?.toString().toLowerCase();
            return (sId == myId && rId == remoteId) || (sId == remoteId && rId == myId);
          }).toList();

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
      final res = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_currentUserId,receiver_id.eq.${widget.remoteUserId}),and(sender_id.eq.${widget.remoteUserId},receiver_id.eq.$_currentUserId)')
          .order('created_at', ascending: true);

      if (mounted) {
        final incoming = List<Map<String, dynamic>>.from(res);

        setState(() {
          _serverMessages = incoming;
          _messages = [..._serverMessages, ..._pendingMessages];
          _isLoading = false;
          if (isBackground) _isSyncing = true;
        });
        _scrollToBottom(immediate: !isBackground);
      }

    } catch (e) {
      debugPrint('Sync Fetch Error: $e');
      if (!isBackground) rethrow;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

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
    _messageController.clear();
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
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: Stack(
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
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.remoteUserName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _remoteUserStatus,
                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.9), letterSpacing: 0.2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0B141A)
                : const Color(0xFFEFE7DE),
            image: const DecorationImage(
              image: AssetImage('assets/images/chat_bg.png'),
              fit: BoxFit.cover,
              opacity: 0.05,
            ),
          ),
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
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final date = DateTime.tryParse(message['created_at'] ?? '')?.toLocal() ?? DateTime.now();

                    bool showDateHeader = false;
                    if (index == 0) {
                      showDateHeader = true;
                    } else {
                      final prevDate = DateTime.tryParse(_messages[index - 1]['created_at'] ?? '')?.toLocal() ?? DateTime.now();
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
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))
                  ],
                ),
                child: Row(
                  children: [
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
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _isSending ? null : _sendMessage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
                          ],
                        ),
                        child: _isSending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
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
              ? Colors.grey.shade800.withOpacity(0.8)
              : Colors.blueGrey.shade100.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
