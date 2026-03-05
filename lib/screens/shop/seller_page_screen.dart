import 'package:flutter/material.dart';
import '../../widgets/product_card.dart';
import 'product_details_screen.dart';

class SellerPageScreen extends StatelessWidget {
  const SellerPageScreen({super.key});

  final List<Map<String, String>> _sellerProducts = const [
    {'name': 'Bluetooth Speaker', 'price': '60.00'},
    {'name': 'Phone Charger', 'price': '20.00'},
    {'name': 'USB Hub', 'price': '35.00'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Shop')),
      body: Column(
        children: [
          // Seller banner
          Container(
            width: double.infinity,
            color: Colors.lightBlue.shade50,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Icon(Icons.store, size: 36),
                ),
                SizedBox(height: 8),
                Text(
                  'Ahmad Store',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('Kuala Lumpur • Joined 2023',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Products',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Seller's product list
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: _sellerProducts.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductDetailsScreen(),
                      ),
                    );
                  },
                  child: ProductCard(
                    name: _sellerProducts[index]['name']!,
                    price: _sellerProducts[index]['price']!,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
