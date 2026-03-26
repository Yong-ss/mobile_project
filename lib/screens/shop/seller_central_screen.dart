import 'package:flutter/material.dart';
import '../order/seller_orders_screen.dart';
import '../product/my_listings_screen.dart';
import '../dashboard/sales_dashboard_screen.dart';

class SellerCentralScreen extends StatefulWidget {
  final String shopName;

  const SellerCentralScreen({
    super.key,
    required this.shopName,
  });

  @override
  State<SellerCentralScreen> createState() => _SellerCentralScreenState();
}

class _SellerCentralScreenState extends State<SellerCentralScreen> {
  late String _currentShopName;
  final TextEditingController _shopNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentShopName = widget.shopName;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  void _showEditShopDialog() {
    _shopNameController.text = _currentShopName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Shop Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Stack(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.store, size: 40),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 14,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        padding: EdgeInsets.zero,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            TextField(
              controller: _shopNameController,
              decoration: const InputDecoration(
                labelText: 'Shop Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentShopName = _shopNameController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Central'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditShopDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Shop Banner
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.store, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentShopName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text('Seller Account', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.blue),
              title: const Text('My Listings'),
              subtitle: const Text('View and manage your products'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyListingsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inbox, color: Colors.blue),
              title: const Text('Seller Orders'),
              subtitle: const Text('Manage incoming customer orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SellerOrdersScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.blue),
              title: const Text('Sales Dashboard'),
              subtitle: const Text('Track your earnings and performance'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SalesDashboardScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
