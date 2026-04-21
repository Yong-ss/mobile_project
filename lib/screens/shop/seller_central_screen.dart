import 'package:flutter/material.dart';
import '../../utils/circular_reveal_route.dart';
import '../order/seller_orders_screen.dart';
import '../product/my_listings_screen.dart';
import '../dashboard/sales_dashboard_screen.dart';
import '../../utils/globals.dart';
import '../shop/seller_page_screen.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/translations.dart';
import 'seller_settings_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../widgets/chat_badge_icon.dart';



class SellerCentralScreen extends StatefulWidget {
  final String shopName;

  const SellerCentralScreen({super.key, required this.shopName});

  @override
  State<SellerCentralScreen> createState() => _SellerCentralScreenState();
}

class _SellerCentralScreenState extends State<SellerCentralScreen> {
  late String _currentShopName;
  String _shopCreatedAt = '';
  bool _isLoading = true;
  final GlobalKey _viewShopButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentShopName = currentUser?['shop_name'] ?? '';
    _shopCreatedAt = currentUser?['shop_created_at']?.toString() ?? 'Unknown';

    // Premium Reveal Strategy: 1s Shimmer
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('seller_central')),
        centerTitle: false,
        actions: [
          ChatBadgeIcon(
            isSellerMode: true,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen(isSellerMode: true)),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              // TODO: Navigate to seller notifications
              snackbar('Notifications coming soon!', Colors.blue);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SellerSettingsScreen()),
              );
              if (result == true) {
                setState(() {
                  _currentShopName = currentUser?['shop_name'] ?? '';
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const SellerCentralSkeleton() // Use the new skeleton
          : SingleChildScrollView(
        child: Column(
          children: [
            // Shop Banner
            Container(
              width: double.infinity,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF303030)
                  : Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.blue.shade50,
                    backgroundImage:
                    (currentUser?['shop_pic'] != null &&
                        currentUser!['shop_pic'].toString().isNotEmpty)
                        ? NetworkImage(currentUser!['shop_pic'])
                        : null,
                    child:
                    (currentUser?['shop_pic'] == null ||
                        currentUser!['shop_pic'].toString().isEmpty)
                        ? Icon(Icons.store, size: 40, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.blue)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentShopName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${t('created_at')}: ${_shopCreatedAt.split('T')[0]}',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: _viewShopButtonKey ,
                    onPressed: () => CircularRevealPageRoute.push(
                      context,
                      _viewShopButtonKey,
                      const SellerPageScreen(),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(t('view_my_shop')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.lightBlueAccent : Colors.blue,
                      side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.lightBlueAccent : Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.blue),
              title: Text(t('my_listings')),
              subtitle: Text(t('manage_products_sub')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyListingsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inbox, color: Colors.blue),
              title: Text(t('seller_orders')),
              subtitle: Text(t('manage_incoming_orders_sub')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SellerOrdersScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.blue),
              title: Text(t('sales_dashboard')),
              subtitle: Text(t('track_performance_sub')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalesDashboardScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}