import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../utils/globals.dart';

class NotificationBell extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isSellerMode;

  const NotificationBell({
    super.key,
    required this.onPressed,
    this.isSellerMode = false,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _shakeController;
  int _unreadCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11), // 8s still + 3s shake cycle
    );
    WidgetsBinding.instance.addObserver(this);
    _checkUnreadNotifications();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkUnreadNotifications();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUnreadNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = currentUser?['id'];
      if (userId == null) return;

      // Determine target role
      final rawRole = currentUser?['role']?.toString().toLowerCase() ?? '';
      String targetRole = 'All Users';

      if (rawRole == 'admin') {
        targetRole = 'All Users';
      } else if (widget.isSellerMode) {
        targetRole = 'Sellers';
      } else {
        targetRole = 'Customers';
      }

      final now = DateTime.now().toIso8601String();

      // 1. Fetch relevant published announcements
      final annRes = await supabase
          .from('announcements')
          .select('id, expire_at')
          .eq('status', 'published')
          .lte('publish_at', now)
          .or('target_role.eq.All Users,target_role.eq.$targetRole');

      // 2. Fetch read history from Supabase
      final readRes = await supabase
          .from('notification_read')
          .select('notification_id')
          .eq('user_id', userId);

      final Set<String> readIds = (readRes as List)
          .map((e) => e['notification_id'].toString())
          .toSet();

      int count = 0;
      for (var ann in annRes) {
        // Filter out expired ones
        if (ann['expire_at'] != null) {
          final expireAt = DateTime.tryParse(ann['expire_at'].toString());
          if (expireAt != null && expireAt.isBefore(DateTime.now())) continue;
        }

        if (!readIds.contains(ann['id'].toString())) {
          count++;
        }
      }

      // 3. Fetch Orders (Seller Mode: Incoming Orders, Buyer Mode: Payment Reminders/Status Updates)
      if (widget.isSellerMode) {
        final sellerOrdersRes = await supabase
            .from('orders')
            .select('id')
            .eq('seller_id', userId);

        for (var order in sellerOrdersRes) {
          if (!readIds.contains(order['id'].toString())) {
            count++;
          }
        }
      } else {
        // Buyer Mode: Awaiting Payment or other updates
        final buyerOrdersRes = await supabase
            .from('orders')
            .select('id')
            .eq('buyer_id', userId);

        for (var order in buyerOrdersRes) {
          if (!readIds.contains(order['id'].toString())) {
            count++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _unreadCount = count;
          if (_unreadCount > 0) {
            if (!_shakeController.isAnimating) {
              _shakeController.repeat();
            }
          } else {
            _shakeController.stop();
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking unread notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        // Oscillation animation logic: 8s still, 3s shake
        double angle = 0;
        if (_unreadCount > 0) {
          const double stillRatio = 8 / 11;
          if (_shakeController.value > stillRatio) {
            // Normalize the last 3 seconds to a 0.0-1.0 range for the shake
            double shakeT = (_shakeController.value - stillRatio) / (1 - stillRatio);
            angle = sin(shakeT * pi * 8) * 0.40;
          }
        }

        return Transform.rotate(
          angle: angle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: widget.onPressed,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
