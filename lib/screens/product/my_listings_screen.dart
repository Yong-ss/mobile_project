import 'package:flutter/material.dart';
import 'upload_product_screen.dart';

// Member 4: My Listings — displays seller's own products (Read / Delete / Edit)
class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  // Dummy seller product list
  final List<Map<String, String>> _myProducts = const [
    {'name': 'Bluetooth Speaker', 'price': '60.00', 'status': 'Active'},
    {'name': 'Phone Charger', 'price': '20.00', 'status': 'Active'},
    {'name': 'USB Hub', 'price': '35.00', 'status': 'Sold Out'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UploadProductScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _myProducts.length,
        itemBuilder: (context, index) {
          final product = _myProducts[index];
          final isSoldOut = product['status'] == 'Sold Out';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              // Product image placeholder (Ch 3.1: Placeholder)
              leading: const SizedBox(
                width: 50,
                height: 50,
                child: Placeholder(),
              ),
              title: Text(product['name']!),
              subtitle: Text(
                'RM ${product['price']} • ${product['status']}',
                style: TextStyle(
                  color: isSoldOut ? Colors.red : Colors.green,
                ),
              ),
              // PopupMenuButton replaces 3-widget trailing row to prevent overflow
              // on small screens (Ch 3.1: PopupMenuButton)
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UploadProductScreen()),
                    );
                  }
                  // 'delete' logic added later
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),

      // FAB for adding a new product
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const UploadProductScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
