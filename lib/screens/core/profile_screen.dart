import 'package:flutter/material.dart';
import '../order/order_history_screen.dart';
import '../order/seller_orders_screen.dart';
import '../product/my_listings_screen.dart';
import '../dashboard/sales_dashboard_screen.dart';

// ProfileScreen is StatefulWidget because it tracks seller mode toggle
// (Lecture Ch 3.1: stateful widget for UI that changes with interaction)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSeller = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Avatar area
            Container(
              width: double.infinity,
              color: Colors.lightBlue.shade50,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    child: Icon(Icons.person, size: 48),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'John Doe',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text('johndoe@email.com',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Common Buyer Menu ──
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('My Orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const OrderHistoryScreen()),
                );
              },
            ),
            const Divider(),

            // ── Seller Mode Toggle ──
            if (!_isSeller)
              ListTile(
                leading: const Icon(Icons.store, color: Colors.lightBlue),
                title: const Text('Become a Seller',
                    style: TextStyle(color: Colors.lightBlue)),
                subtitle: const Text('Start listing products to sell'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _isSeller = true;
                  });
                },
              ),

            // ── Seller-Only Menus (shown only after enabling seller mode) ──
            if (_isSeller) ...[
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('My Listings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MyListingsScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.inbox),
                title: const Text('Seller Orders'),
                subtitle: const Text('Manage incoming orders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SellerOrdersScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Sales Dashboard'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SalesDashboardScreen()),
                  );
                },
              ),
            ],
            const Divider(),

            // ── Logout ──
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title:
                  const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}
