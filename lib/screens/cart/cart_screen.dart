import 'package:flutter/material.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  // Dummy cart items
  final List<Map<String, dynamic>> _cartItems = const [
    {'name': 'Bluetooth Speaker', 'price': 60.0, 'qty': 1},
    {'name': 'Denim Jacket', 'price': 85.0, 'qty': 2},
  ];

  @override
  Widget build(BuildContext context) {
    double total = _cartItems.fold(
        0, (sum, item) => sum + (item['price'] as double) * (item['qty'] as int));

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: Column(
        children: [
          // Cart items ListView (Ch 3.1: ListView)
          Expanded(
            child: ListView.builder(
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: const SizedBox(
                      width: 50,
                      height: 50,
                      child: Placeholder(),
                    ),
                    title: Text(item['name'] as String),
                    subtitle: Text('Qty: ${item['qty']}'),
                    trailing: Text(
                      'RM ${((item['price'] as double) * (item['qty'] as int)).toStringAsFixed(2)}',

                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),

          // Total + checkout row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: RM ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CheckoutScreen()),
                    );
                  },
                  child: const Text('Checkout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
