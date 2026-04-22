import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';
import '../../utils/globals.dart';
import '../../utils/translations.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'chat_screen.dart';
import '../../utils/snackbar_helper.dart';

class ChatListScreen extends StatefulWidget {
  final bool isSellerMode;

  const ChatListScreen({
    super.key,
    this.isSellerMode = false,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = {}; // We'll store the remoteUserId


  @override
  void initState() {
    super.initState();
    _loadConversations();
    _setupRealtimeListener();
  }

  Timer? _refreshTimer;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _setupRealtimeListener() {
    final myId = currentUser?['id'];
    if (myId == null) return;

    _realtimeChannel = _supabase
        .channel('public:messages:chat_list')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final newRecord = payload.newRecord;
        final oldRecord = payload.oldRecord;

        final senderId = newRecord['sender_id']?.toString() ?? oldRecord['sender_id']?.toString();
        final receiverId = newRecord['receiver_id']?.toString() ?? oldRecord['receiver_id']?.toString();

        if (senderId == myId.toString() || receiverId == myId.toString()) {
          // Debounce refresh to avoid spamming database calls
          _refreshTimer?.cancel();
          _refreshTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) {
              debugPrint('ChatList: Real-time update triggered (debounced)');
              _loadConversations();
            }
          });
        }
      },
    )
        .subscribe();
  }



  Future<void> _loadConversations() async {
    final myId = currentUser?['id'];
    if (myId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch recent messages involving current user
      final List<dynamic> allMessages = await _supabase
          .from('messages')
          .select('*')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: true); // Ascending helps find the FIRST message

      if (allMessages.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Identify unique participants and group by Display Name (Twin-ID resolution)
      // First, we need user names to group successfully
      final Set<String> allRemoteIds = {};
      for (var msg in allMessages) {
        allRemoteIds.add(msg['sender_id'] == myId ? msg['receiver_id'] : msg['sender_id']);
      }

      final List<dynamic> usersData = await _supabase
          .from('user')
          .select('id, username, shop_name, user_pic, google_profile_image, shop_pic')
          .inFilter('id', allRemoteIds.toList());

      final Map<String, Map<String, dynamic>> userMap = {
        for (var u in usersData) u['id']: u
      };

      final Map<String, Map<String, dynamic>> groupedConversations = {};

      for (var msg in allMessages) {
        final remoteId = msg['sender_id'] == myId ? msg['receiver_id'] : msg['sender_id'];
        final user = userMap[remoteId];
        if (user == null) continue;

        final String displayName;
        if (widget.isSellerMode) {
          // As a Seller, you are talking to Buyers. Group by their username.
          displayName = user['username'] ?? 'Unknown User';
        } else {
          // As a Buyer, you are talking to Sellers. Group by their shop name.
          displayName = (user['shop_name'] != null && user['shop_name'].toString().isNotEmpty)
              ? user['shop_name']
              : (user['username'] ?? 'Unknown User');
        }

        // Logic:
        // - In Seller Mode, we only show chats where WE were the RECEIVER of the first message.
        // - In Buyer Mode, we only show chats where WE were the SENDER of the first message.
        final bool isToMe = msg['receiver_id']?.toString().toLowerCase() == myId.toString().toLowerCase();

        if (!groupedConversations.containsKey(displayName)) {
          // Mode filter based on the very first message for this NAME
          bool shouldInclude = false;
          if (widget.isSellerMode) {
            shouldInclude = msg['receiver_id'] == myId;
          } else {
            shouldInclude = msg['sender_id'] == myId;
          }


          if (!shouldInclude) continue;

          groupedConversations[displayName] = {
            ...user,
            'display_name': displayName,
            'last_message': msg['content'] ?? '',
            'last_message_time': msg['created_at'] ?? '',
            'unread_count': 0,
            'related_ids': <String>{remoteId},
          };
        }

        final conv = groupedConversations[displayName]!;
        conv['related_ids'].add(remoteId);

        // Update to latest message
        conv['last_message'] = msg['content'] ?? '';
        conv['last_message_time'] = msg['created_at'] ?? '';

        // Tally unread
        if (isToMe && msg['is_read'] != true) {
          conv['unread_count'] = (conv['unread_count'] as int) + 1;
        }
      }

      // 4. Fetch hidden chat timestamps
      final List<dynamic> hiddenData = await _supabase
          .from('hidden_chat')
          .select('remote_user_id, hidden_at')
          .eq('user_id', myId);

      final Map<String, String> hiddenMap = {
        for (var h in hiddenData) h['remote_user_id'].toString(): h['hidden_at'].toString()
      };

      final List<Map<String, dynamic>> combined = groupedConversations.values
          .where((c) {
        final remoteId = c['id'].toString();
        final hiddenAtStr = hiddenMap[remoteId];
        if (hiddenAtStr == null) return true;

        try {
          final hiddenAt = DateTime.parse(hiddenAtStr).toUtc();
          final lastMsgAt = DateTime.parse(c['last_message_time'].toString()).toUtc();

          // Only show if the last message is strictly AFTER the hidden timestamp
          return lastMsgAt.isAfter(hiddenAt);
        } catch (e) {
          debugPrint('Error comparing timestamps: $e');
          return true;
        }
      })
          .map((c) {
        return {
          ...c,
          'related_ids': (c['related_ids'] as Set<String>).toList(),
        };
      }).toList();

      // 5. Final Sort by time descending (newest first)
      combined.sort((a, b) => (b['last_message_time'] as String).compareTo(a['last_message_time'] as String));

      if (mounted) {
        setState(() {
          _conversations = combined;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSelectedChats() async {
    final myId = currentUser?['id'];
    if (myId == null || _selectedChatIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Conversations?"),
        content: Text("Are you sure you want to delete ${_selectedChatIds.length} conversation(s)? This will hide them from your list but won't delete messages for the other person."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);

        final now = DateTime.now().toUtc().toIso8601String();

        for (final remoteId in _selectedChatIds) {
          // Use upsert to handle both insert and update in one call
          await _supabase.from('hidden_chat').upsert({
            'user_id': myId,
            'remote_user_id': remoteId,
            'hidden_at': now,
          }, onConflict: 'user_id, remote_user_id');
        }

        if (mounted) {
          setState(() {
            _isSelectionMode = false;
            _selectedChatIds.clear();
          });
          _loadConversations();
          snackbar("Conversations hidden", Colors.green);
        }
      } catch (e) {
        debugPrint('Error hiding chats: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          snackbar("Error hiding chats: $e", Colors.red);
        }
      }
    }
  }

  String _formatDateTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    final date = DateTime.tryParse(timestamp)?.toLocal() ?? DateTime.now();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return DateFormat.jm().format(date); // e.g. 4:25 PM
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat.MMMd().format(date); // e.g. Apr 21
    }
  }

  String _getMessagePreview(String content) {
    if (content.trim().isEmpty) return '';
    if (content.startsWith('{') && content.contains('"type":')) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          if (decoded['type'] == 'product') {
            return 'Product: ${decoded['name'] ?? 'Unknown'}';
          }
          if (decoded['type'] == 'session_ended') {
            return 'Chat Ended';
          }
        }
        return content;
      } catch (_) {
        return content;
      }
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isSelectionMode ? "${_selectedChatIds.length} Selected" : t('messages'),
            style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _isSelectionMode = false;
              _selectedChatIds.clear();
            });
          },
        )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteSelectedChats,
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadConversations,
            ),
        ],
      ),

      body: _isLoading
          ? const ChatListSkeleton()
          : _conversations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _conversations.length,
          separatorBuilder: (context, index) => const Divider(indent: 84, height: 1),
          itemBuilder: (context, index) {
            final chat = _conversations[index];
            final displayName = chat['display_name'] ?? 'Unknown User';

            final String? profilePic;
            if (widget.isSellerMode) {
              profilePic = chat['user_pic'] ?? chat['google_profile_image'];
            } else {
              profilePic = chat['shop_pic'] ?? chat['user_pic'] ?? chat['google_profile_image'];
            }

            final lastMsg = chat['last_message'] ?? '';
            final timeStr = _formatDateTime(chat['last_message_time'] ?? '');

            return ListTile(
              selected: _selectedChatIds.contains(chat['id']),
              selectedTileColor: Colors.blue.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: (profilePic != null && profilePic.toString().isNotEmpty)
                        ? NetworkImage(profilePic)
                        : null,
                    child: (profilePic == null || profilePic.toString().isEmpty)
                        ? const Icon(Icons.person, color: Colors.blue)
                        : null,
                  ),
                  if (_isSelectionMode)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedChatIds.contains(chat['id'])
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: _selectedChatIds.contains(chat['id']) ? Colors.blue : Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: (chat['unread_count'] ?? 0) > 0 ? Colors.blue.shade600 : Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: (chat['unread_count'] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if ((chat['unread_count'] ?? 0) > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chat['unread_count']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),


              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _getMessagePreview(lastMsg),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontStyle: lastMsg.trim().startsWith('{') ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onTap: () {
                if (_isSelectionMode) {
                  setState(() {
                    if (_selectedChatIds.contains(chat['id'])) {
                      _selectedChatIds.remove(chat['id']);
                      if (_selectedChatIds.isEmpty) _isSelectionMode = false;
                    } else {
                      _selectedChatIds.add(chat['id']);
                    }
                  });
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        remoteUserId: chat['id'],
                        remoteUserName: displayName,
                        relatedRemoteIds: List<String>.from(chat['related_ids'] ?? []),
                      ),
                    ),
                  ).then((_) => _loadConversations()); // Refresh when back
                }
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedChatIds.add(chat['id']);
                  });
                }
              },

            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              widget.isSellerMode ? Icons.chat_bubble_outline_rounded : Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey.shade300
          ),
          const SizedBox(height: 20),
          Text(
            widget.isSellerMode ? "No incoming chat" : "No conversations yet",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isSellerMode
                ? "Wait for customer chat to appear here."
                : "Contact a seller or buyer to start chatting!",
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}