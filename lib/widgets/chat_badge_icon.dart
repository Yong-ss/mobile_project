import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/globals.dart';

class ChatBadgeIcon extends StatefulWidget {
  final bool isSellerMode;
  final VoidCallback onPressed;

  const ChatBadgeIcon({
    super.key,
    required this.isSellerMode,
    required this.onPressed,
  });

  @override
  State<ChatBadgeIcon> createState() => _ChatBadgeIconState();
}

class _ChatBadgeIconState extends State<ChatBadgeIcon> {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToMessages() {
    final myId = currentUser?['id'];
    if (myId == null) return;

    _channel = _supabase
        .channel('public:messages_badge')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'receiver_id',
        value: myId,
      ),
      callback: (payload) {
        _loadUnreadCount();
      },
    )
        .subscribe();
  }

  Future<void> _loadUnreadCount() async {
    final myId = currentUser?['id'];
    if (myId == null) return;

    try {
      // 1. Fetch all unread messages for this user
      final List<dynamic> unreadRes = await _supabase
          .from('messages')
          .select('sender_id')
          .eq('receiver_id', myId)
          .eq('is_read', false);

      if (unreadRes.isEmpty) {
        if (mounted) setState(() { _unreadCount = 0; _isLoading = false; });
        return;
      }

      // 2. Identify unique senders
      final uniqueSenders = unreadRes.map((m) => m['sender_id'].toString()).toSet().toList();

      // 3. For each sender, determine if the chat belongs to the current "Mode" (Buyer or Seller)
      int localizedCount = 0;

      for (var senderId in uniqueSenders) {
        // Find the FIRST message ever exchanged between myId and senderId
        final List<dynamic> threadStart = await _supabase
            .from('messages')
            .select('sender_id, receiver_id')
            .or('and(sender_id.eq.$myId,receiver_id.eq.$senderId),and(sender_id.eq.$senderId,receiver_id.eq.$myId)')
            .order('created_at', ascending: true)
            .limit(1);

        if (threadStart.isNotEmpty) {
          final firstMsg = threadStart[0];
          final bool initiatedByMe = firstMsg['sender_id'] == myId;

          bool include = false;
          if (widget.isSellerMode) {
            // Seller Mode: We received the invitation (someone messaged our shop)
            include = !initiatedByMe;
          } else {
            // Buyer Mode: We started the chat with another shop
            include = initiatedByMe;
          }

          if (include) {
            localizedCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _unreadCount = localizedCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          onPressed: widget.onPressed,
        ),
        if (!_isLoading && _unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

      ],
    );
  }
}
