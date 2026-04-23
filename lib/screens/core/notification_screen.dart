import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/globals.dart';
import '../../utils/translations.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'announcement_details_screen.dart';
import '../order/order_details_screen.dart';
import '../order/seller_order_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScreen extends StatefulWidget {
  final bool isSystemOnly;
  const NotificationScreen({super.key, this.isSystemOnly = false});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  int _activeTabIndex = 0;
  bool _isLoading = true;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _paymentReminders = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic>? _applicationStatus;
  Set<String> _readIds = {};

  StreamSubscription? _orderSubscription;
  final ScrollController _annScrollController = ScrollController();
  final ScrollController _orderScrollController = ScrollController();

  int _annPage = 0;
  int _orderPage = 0;
  final int _pageSize = 10;

  bool _isAnnLoadingMore = false;
  bool _hasMoreAnn = true;
  bool _isOrderLoadingMore = false;
  bool _hasMoreOrder = true;

  @override
  void initState() {
    super.initState();
    final bool isAdmin = currentUser?['role'] == 'admin';
    _tabController = TabController(
        length: (widget.isSystemOnly || isAdmin) ? 2 : 4,
        vsync: this
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
    _annScrollController.addListener(_onAnnScroll);
    _orderScrollController.addListener(_onOrderScroll);
    _loadReadIds();
    _fetchAllNotifications();
    _setupRealtimeOrders();
  }

  bool _isInitialLoadDone = false;

  void _setupRealtimeOrders() {
    final userId = currentUser?['id'];
    if (userId == null) return;

    // Listen for new or updated orders for this seller
    _orderSubscription = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('seller_id', userId)
        .listen((data) {
      if (widget.isSystemOnly && _isInitialLoadDone) {
        // Check if any order in 'data' is NOT in our current '_orders' list
        final existingIds = _orders.map((o) => o['id'].toString()).toSet();
        final incomingIds = data.map((o) => o['id'].toString()).toSet();

        // If there's a new ID that wasn't there before, it's a truly new incoming order
        final hasNewOrder = incomingIds.any((id) => !existingIds.contains(id));

        if (hasNewOrder) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('New Order Received!', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.lightBlue,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              )
          );
        }
      }

      // Refresh list when a change occurs
      _fetchAllNotifications().then((_) {
        if (mounted) setState(() => _isInitialLoadDone = true);
      });
    });
  }
  void _onOrderScroll() {
    if (_orderScrollController.position.pixels >= _orderScrollController.position.maxScrollExtent - 200) {
      if (!_isOrderLoadingMore && _hasMoreOrder) {
        _fetchMoreOrders();
      }
    }
  }

  void _onAnnScroll() {
    if (_annScrollController.position.pixels >= _annScrollController.position.maxScrollExtent - 200) {
      if (!_isAnnLoadingMore && _hasMoreAnn) {
        _fetchMoreAnnouncements();
      }
    }
  }

  Future<void> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _readIds = (prefs.getStringList('read_notification_ids') ?? []).toSet();
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    if (_readIds.contains(id)) return;
    setState(() {
      _readIds.add(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_notification_ids', _readIds.toList());
  }

  Future<void> _markAllAsRead() async {
    final List<String> allIds = [
      ..._announcements.map((e) => e['id'].toString()),
      ..._paymentReminders.map((e) => e['id'].toString()),
      ..._orders.map((e) => e['id'].toString()),
      ..._logs.map((e) => e['id'].toString()),
      if (_applicationStatus != null) _applicationStatus!['id'].toString(),
    ];

    setState(() {
      _readIds.addAll(allIds);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_notification_ids', _readIds.toList());
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _tabController.dispose();
    _annScrollController.dispose();
    _orderScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllNotifications() async {
    setState(() => _isLoading = true);
    _annPage = 0;
    _orderPage = 0;
    _hasMoreAnn = true;
    _hasMoreOrder = true;
    try {
      final userId = currentUser?['id'];
      final rawRole = currentUser?['role']?.toString().toLowerCase() ?? '';
      String targetRole = 'All Users';
      if (rawRole == 'admin') {
        targetRole = 'All Users';
      } else if (widget.isSystemOnly) {
        // Seller Central Context
        targetRole = 'Sellers';
      } else {
        // Buyer/General Context
        targetRole = 'Customers';
      }

      final now = DateTime.now().toIso8601String();

      // 1. Fetch System Announcements (Page 0)
      final annRes = await _supabase
          .from('announcements')
          .select()
          .eq('status', 'published')
          .lte('publish_at', now)
          .or('target_role.eq.All Users,target_role.eq.$targetRole')
          .order('publish_at', ascending: false)
          .range(0, _pageSize - 1);

      _announcements = List<Map<String, dynamic>>.from(annRes).where((ann) {
        if (ann['expire_at'] == null) return true;
        final expireAt = DateTime.tryParse(ann['expire_at'].toString());
        return expireAt == null || expireAt.isAfter(DateTime.now());
      }).toList();

      _hasMoreAnn = annRes.length == _pageSize;

      // 2. Fetch Payment Reminders
      if (userId != null) {
        final orderRes = await _supabase
            .from('orders')
            .select()
            .eq('buyer_id', userId)
            .eq('status', 'Awaiting Payment')
            .order('created_at', ascending: false);
        _paymentReminders = List<Map<String, dynamic>>.from(orderRes);
      }

      // 3. Fetch Application Status (Current state)
      if (userId != null) {
        final userRes = await _supabase.from('user').select().eq('id', userId).maybeSingle();
        _applicationStatus = userRes;
      }

      // 4. Fetch Orders (Buyer tracking or Seller notification)
      if (userId != null) {
        if (widget.isSystemOnly) {
          // Seller Mode: New Orders
          final sellerOrdersRes = await _supabase
              .from('orders')
              .select('*, buyer:buyer_id(*), order_items:order_item(*, product:product_id(*))')
              .eq('seller_id', userId)
              .order('created_at', ascending: false)
              .limit(_pageSize);
          _orders = List<Map<String, dynamic>>.from(sellerOrdersRes);
        } else {
          // Buyer Mode: Order Status Tracking (exclude Awaiting Payment)
          final buyerOrdersRes = await _supabase
              .from('orders')
              .select('*, order_items:order_item(*, product:product_id(*))')
              .eq('buyer_id', userId)
              .neq('status', 'Awaiting Payment')
              .order('created_at', ascending: false)
              .limit(_pageSize);
          _orders = List<Map<String, dynamic>>.from(buyerOrdersRes);
        }
        _hasMoreOrder = _orders.length == _pageSize;
      }

      // 5. Fetch Logs for Admins
      if (currentUser?['role'] == 'admin') {
        // Fetch new users (registrations)
        final userLogsRes = await _supabase
            .from('user')
            .select('id, username, is_seller, created_at')
            .order('created_at', ascending: false)
            .limit(10);

        final List<Map<String, dynamic>> registrationLogs = List<Map<String, dynamic>>.from(userLogsRes).map((u) {
          final bool isSeller = u['is_seller'] == true;
          return {
            'id': u['id'],
            'title': isSeller ? 'New Seller Registered' : 'New User Registered',
            'content': 'User ${u['username']} just joined the platform.',
            'created_at': u['created_at'],
            'icon': isSeller ? Icons.storefront : Icons.person_add,
            'iconColor': Colors.green,
            'type': 'registration'
          };
        }).toList();

        // Fetch system audit logs
        final auditLogsRes = await _supabase
            .from('system_logs')
            .select()
            .order('created_at', ascending: false)
            .limit(20);

        final List<Map<String, dynamic>> auditLogs = List<Map<String, dynamic>>.from(auditLogsRes).map((l) {
          return {
            'id': l['id'],
            'title': l['action'],
            'content': l['details'],
            'created_at': l['created_at'],
            'icon': Icons.history,
            'iconColor': Colors.blueGrey,
            'type': 'audit'
          };
        }).toList();

        _logs = [...registrationLogs, ...auditLogs];
        _logs.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      }

    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoadDone = true;
        });
      }
    }
  }

  Future<void> _fetchMoreOrders() async {
    if (_isOrderLoadingMore || !_hasMoreOrder) return;

    setState(() => _isOrderLoadingMore = true);
    try {
      _orderPage++;
      final userId = currentUser?['id'];
      if (userId == null) return;

      final from = _orderPage * _pageSize;
      final to = from + _pageSize - 1;

      List<dynamic> res;
      if (widget.isSystemOnly) {
        res = await _supabase
            .from('orders')
            .select('*, buyer:buyer_id(*), order_items:order_item(*, product:product_id(*))')
            .eq('seller_id', userId)
            .order('created_at', ascending: false)
            .range(from, to);
      } else {
        res = await _supabase
            .from('orders')
            .select('*, order_items:order_item(*, product:product_id(*))')
            .eq('buyer_id', userId)
            .neq('status', 'Awaiting Payment')
            .order('created_at', ascending: false)
            .range(from, to);
      }

      if (mounted) {
        setState(() {
          _orders.addAll(List<Map<String, dynamic>>.from(res));
          _hasMoreOrder = res.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more orders: $e');
    } finally {
      if (mounted) setState(() => _isOrderLoadingMore = false);
    }
  }

  Future<void> _fetchMoreAnnouncements() async {
    if (_isAnnLoadingMore || !_hasMoreAnn) return;

    setState(() => _isAnnLoadingMore = true);
    try {
      _annPage++;
      final rawRole = currentUser?['role']?.toString().toLowerCase() ?? '';
      String targetRole = 'All Users';
      if (rawRole == 'admin') {
        targetRole = 'All Users';
      } else if (widget.isSystemOnly) {
        targetRole = 'Sellers';
      } else {
        targetRole = 'Customers';
      }

      final now = DateTime.now().toIso8601String();
      final from = _annPage * _pageSize;
      final to = from + _pageSize - 1;

      final annRes = await _supabase
          .from('announcements')
          .select()
          .eq('status', 'published')
          .lte('publish_at', now)
          .or('target_role.eq.All Users,target_role.eq.$targetRole')
          .order('publish_at', ascending: false)
          .range(from, to);

      final newAnns = List<Map<String, dynamic>>.from(annRes).where((ann) {
        if (ann['expire_at'] == null) return true;
        final expireAt = DateTime.tryParse(ann['expire_at'].toString());
        return expireAt == null || expireAt.isAfter(DateTime.now());
      }).toList();

      if (mounted) {
        setState(() {
          _announcements.addAll(newAnns);
          _hasMoreAnn = annRes.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more announcements: $e');
    } finally {
      if (mounted) setState(() => _isAnnLoadingMore = false);
    }
  }

  Widget _buildOrderList() {
    if (_orders.isEmpty) return _buildEmptyState(widget.isSystemOnly ? 'No new orders' : 'No order status updates');

    return ListView.builder(
      controller: _orderScrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length + (_hasMoreOrder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _orders.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final order = _orders[index];
        final orderItems = order['order_items'] as List<dynamic>? ?? [];
        final firstItem = orderItems.isNotEmpty ? orderItems[0] : null;
        final product = firstItem?['product'] as Map<String, dynamic>?;
        final productName = product?['name'] ?? 'Multiple Items';
        final buyerName = widget.isSystemOnly ? (order['buyer']?['username'] ?? 'Unknown Buyer') : '';

        final status = order['status'] ?? 'Pending';
        String title = widget.isSystemOnly ? 'New Order Placed' : 'Order Status Update';
        String content = widget.isSystemOnly
            ? '$buyerName bought $productName'
            : 'Your order for $productName is $status';

        return _buildNotificationCard(
          notificationId: order['id'].toString(),
          title: title,
          content: content,
          date: order['created_at'],
          icon: widget.isSystemOnly ? Icons.add_shopping_cart : Icons.local_shipping,
          iconColor: Colors.orange,
          onTap: () {
            if (widget.isSystemOnly) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SellerOrderDetailScreen(orderId: order['id'].toString()),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailsScreen(orderId: order['id']),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark && currentUser?['role'] != 'admin';
    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(t('notifications'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.lightBlue,
                isDark ? Colors.grey.shade900 : Colors.white
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      t('categories'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      )
                  ),
                  TextButton(
                    onPressed: _markAllAsRead,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      t('read_all'),
                      style: const TextStyle(fontSize: 12, color: Colors.lightBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            _buildCategoryBar(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.lightBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                      _getCategoryTitle(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      )
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _isLoading ? _buildShimmerList() : _buildSystemList(),
                  if (currentUser?['role'] == 'admin') ...[
                    _isLoading ? _buildShimmerList() : _buildLogsList(),
                  ] else if (widget.isSystemOnly) ...[
                    _isLoading ? _buildShimmerList() : _buildOrderList(),
                  ] else ...[
                    _isLoading ? _buildShimmerList() : _buildApplicationList(),
                    _isLoading ? _buildShimmerList() : _buildPaymentList(),
                    _isLoading ? _buildShimmerList() : _buildOrderList(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryTitle() {
    final catId = _getCategoryId(_activeTabIndex);
    if (catId == 'System') return 'System Announcements';
    if (catId == 'Application') return 'Application Updates';
    if (catId == 'Payment') return 'Payment Reminders';
    if (catId == 'Logs') return 'System Logs';
    if (catId == 'Order') {
      return widget.isSystemOnly ? 'Incoming Orders' : 'Order Status Updates';
    }
    return 'Notifications';
  }

  String _getCategoryId(int index) {
    final bool isAdmin = currentUser?['role'] == 'admin';
    if (isAdmin) {
      if (index == 0) return 'System';
      return 'Logs';
    }
    if (widget.isSystemOnly) {
      if (index == 0) return 'System';
      return 'Order';
    } else {
      if (index == 0) return 'System';
      if (index == 1) return 'Application';
      if (index == 2) return 'Payment';
      return 'Order';
    }
  }

  Widget _buildCategoryBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark && currentUser?['role'] != 'admin';
    final List<Map<String, dynamic>> categories = [
      {'id': 'System', 'icon': Icons.campaign_rounded, 'label': 'System'},
    ];

    if (widget.isSystemOnly) {
      categories.addAll([
        {'id': 'Order', 'icon': Icons.inventory_2_outlined, 'label': t('new_orders')},
      ]);
    } else {
      categories.addAll([
        {'id': 'Application', 'icon': Icons.assignment_ind_rounded, 'label': 'Application'},
        {'id': 'Payment', 'icon': Icons.account_balance_wallet_rounded, 'label': 'Payment'},
        {'id': 'Order', 'icon': Icons.local_shipping_outlined, 'label': t('order')},
      ]);
    }

    if (currentUser?['role'] == 'admin') {
      categories.clear();
      categories.add({'id': 'System', 'icon': Icons.campaign_rounded, 'label': 'System'});
      categories.add({'id': 'Logs', 'icon': Icons.assignment_rounded, 'label': 'Logs'});
    }

    return Container(
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        dividerColor: Colors.transparent,
        indicatorColor: Colors.lightBlue,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.lightBlue,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.grey,
        indicatorPadding: EdgeInsets.zero,
        tabs: categories.map((cat) {
          final bool isSelected = _getCategoryId(_activeTabIndex) == cat['id'];
          return Tab(
            height: 90,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cat['icon'] as IconData,
                  size: 24,
                  color: isSelected ? Colors.lightBlue : (isDark ? Colors.white38 : Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  cat['label'] as String,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSystemList() {
    if (_announcements.isEmpty) return _buildEmptyState('No system announcements');

    return ListView.builder(
      controller: _annScrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _announcements.length + (_hasMoreAnn ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _announcements.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final ann = _announcements[index];
        return _buildNotificationCard(
          notificationId: ann['id'].toString(),
          title: ann['title'] ?? 'System Update',
          content: ann['content'] ?? '',
          date: ann['publish_at'],
          icon: Icons.campaign,
          iconColor: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnnouncementDetailsScreen(announcement: ann),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApplicationList() {
    if (_applicationStatus == null || _applicationStatus!['seller_application_status'] == 'none') {
      return _buildEmptyState('No application updates');
    }

    final status = _applicationStatus!['seller_application_status'];
    final reason = _applicationStatus!['rejection_reason'];

    Color statusColor = Colors.orange;
    String title = 'Application Pending';
    String message = 'Your seller application is currently under review.';
    IconData icon = Icons.hourglass_empty;

    if (status == 'approved') {
      statusColor = Colors.green;
      title = 'Application Approved!';
      message = 'Congratulations! You are now a verified seller. You can start listing products.';
      icon = Icons.check_circle;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      title = 'Application Rejected';
      message = 'Your application was rejected. Reason: ${reason ?? "Not specified"}. Tap to re-apply.';
      icon = Icons.error;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildNotificationCard(
          notificationId: _applicationStatus!['id'].toString(),
          title: title,
          content: message,
          date: _applicationStatus!['updated_at'] ?? _applicationStatus!['created_at'],
          icon: icon,
          iconColor: statusColor,
          onTap: status == 'rejected' ? () => Navigator.pop(context) : null,
        ),
      ],
    );
  }

  Widget _buildPaymentList() {
    if (_paymentReminders.isEmpty) return _buildEmptyState('No pending payments');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paymentReminders.length,
      itemBuilder: (context, index) {
        final order = _paymentReminders[index];
        return _buildNotificationCard(
          notificationId: order['id'].toString(),
          title: 'Payment Reminder',
          content: 'Order #${order['id'].toString().substring(0, 8)} is awaiting payment. Total: RM${order['total_amount']}',
          date: order['created_at'],
          icon: Icons.payment,
          iconColor: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailsScreen(orderId: order['id']),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard({
    required String notificationId,
    required String title,
    required String content,
    String? date,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    String timeStr = '';
    if (date != null) {
      final dt = DateTime.tryParse(date) ?? DateTime.now();
      timeStr = DateFormat('MMM dd, HH:mm').format(dt);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark && currentUser?['role'] != 'admin';
    final bool isUnread = !_readIds.contains(notificationId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread
            ? (isDark ? Colors.lightBlue.withValues(alpha: 0.12) : Colors.lightBlue.shade50)
            : (isDark ? Theme.of(context).cardColor : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: isUnread ? Colors.lightBlue.withValues(alpha: 0.3) : Colors.white10) : null,
        boxShadow: (isDark || isUnread)
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () {
          _markAsRead(notificationId);
          if (onTap != null) onTap();
        },
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
              content,
              style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                  fontSize: 13,
                  height: 1.4
              )
          ),
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    if (_logs.isEmpty) return _buildEmptyState('No system logs found');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildNotificationCard(
          notificationId: log['id'].toString(),
          title: log['title'] ?? 'System Activity',
          content: log['content'] ?? '',
          date: log['created_at'],
          icon: log['icon'] as IconData,
          iconColor: log['iconColor'] as Color,
          onTap: () => _showLogDetails(log),
        );
      },
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    final bool isAdmin = currentUser?['role'] == 'admin';
    final isDark = Theme.of(context).brightness == Brightness.dark && !isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isAdmin ? const Color(0xFFF8F9FA) : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isAdmin ? Colors.grey.shade300 : (isDark ? Colors.white12 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (log['iconColor'] as Color).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(log['icon'] as IconData, color: log['iconColor'] as Color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log['title'] ?? 'System Activity',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: isAdmin ? Colors.black87 : (isDark ? Colors.white : Colors.black87)
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.parse(log['created_at'])),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.lightBlue),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isAdmin ? Colors.white : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAdmin ? Colors.grey.shade200 : (isDark ? Colors.white10 : Colors.grey.shade100),
                  ),
                  boxShadow: isAdmin ? [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))] : [],
                ),
                child: Text(
                  log['content'] ?? 'No details available.',
                  style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isAdmin ? Colors.black87 : (isDark ? Colors.white70 : Colors.black87)
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark && currentUser?['role'] != 'admin';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: isDark ? Colors.white10 : Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(
              message,
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                  fontWeight: FontWeight.w500
              )
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    final isDark = Theme.of(context).brightness == Brightness.dark && currentUser?['role'] != 'admin';
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BaseSkeleton(
          width: double.infinity,
          height: 100,
          borderRadius: 16,
          isDarkOverride: isDark,
        ),
      ),
    );
  }

  String t(String key) => Translations.translate(key);
}