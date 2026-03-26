import 'package:flutter/material.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Dummy cart items moved to state (Ch 3.3: StatefulWidget)
  final List<Map<String, dynamic>> _cartItems = [
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
                    subtitle: Text('Price: RM ${(item['price'] as double).toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Decrement button
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              if ((item['qty'] as int) > 1) {
                                item['qty'] = (item['qty'] as int) - 1;
                              }
                            });
                          },
                        ),
                        // Quantity display
                        Text(
                          '${item['qty']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        // Increment button
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              item['qty'] = (item['qty'] as int) + 1;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _cartItems.removeAt(index);
                            });
                          },
                        ),
                      ],
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
