import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/globals.dart';
import '../../utils/translations.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'chat_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadConversations();
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

      // 2. Identify unique participants, their FIRST message (role) and LAST message (preview)
      final Map<String, dynamic> firstMessages = {};
      final Map<String, dynamic> lastMessages = {};

      for (var msg in allMessages) {
        final remoteId = msg['sender_id'] == myId ? msg['receiver_id'] : msg['sender_id'];

        // The first time we see this remoteId, it's the EARLIEST message (due to asc order)
        if (!firstMessages.containsKey(remoteId)) {
          firstMessages[remoteId] = msg;
        }
        // Always update lastMessages to the current one (latest seen)
        lastMessages[remoteId] = msg;
      }

      // 3. Fetch user information for these unique participants
      final List<dynamic> usersData = await _supabase
          .from('user')
          .select('id, username, user_pic, google_profile_image, shop_name, shop_pic')
          .inFilter('id', lastMessages.keys.toList());

      // 4. Merge user profile and filter by Role (Seller vs Buyer)
      final List<Map<String, dynamic>> combined = [];
      for (var user in usersData) {
        final remoteId = user['id'];
        final firstMsg = firstMessages[remoteId];

        // Logic:
        // - In Seller Mode, we only show chats where WE were the RECEIVER of the first message (Inquiry).
        // - In Buyer Mode (default), we only show chats where WE were the SENDER of the first message (Inquiry).
        bool shouldInclude = false;
        if (widget.isSellerMode) {
          shouldInclude = firstMsg['receiver_id'] == myId;
        } else {
          shouldInclude = firstMsg['sender_id'] == myId;
        }

        if (shouldInclude) {
          combined.add({
            ...user,
            'last_message': lastMessages[remoteId]?['content'] ?? '',
            'last_message_time': lastMessages[remoteId]?['created_at'] ?? '',
          });
        }
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isSellerMode ? (t('Messages') ?? 'Customer Chats') : (t('Messages') ?? 'Messages'),
            style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        elevation: 0,
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
            final displayName = chat['username'] ?? chat['shop_name'] ?? 'Unknown User';
            final profilePic = chat['user_pic'] ?? chat['google_profile_image'] ?? chat['shop_pic'];
            final lastMsg = chat['last_message'] ?? '';
            final timeStr = _formatDateTime(chat['last_message_time'] ?? '');

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade100,
                backgroundImage: (profilePic != null && profilePic.toString().isNotEmpty)
                    ? NetworkImage(profilePic)
                    : null,
                child: (profilePic == null || profilePic.toString().isEmpty)
                    ? const Icon(Icons.person, color: Colors.blue)
                    : null,
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  lastMsg,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      remoteUserId: chat['id'],
                      remoteUserName: displayName,
                    ),
                  ),
                ).then((_) => _loadConversations()); // Refresh when back
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