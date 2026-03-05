import 'package:flutter/material.dart';
import 'seller_page_screen.dart';
import '../cart/cart_screen.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image placeholder (Ch 3.1: Placeholder)
            const SizedBox(
              width: double.infinity,
              height: 280,
              child: Placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bluetooth Speaker',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'RM 60.00',
                    style: TextStyle(fontSize: 20, color: Colors.lightBlue),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A high-quality portable Bluetooth speaker with 10 hours battery life and 360° surround sound. Perfect for outdoor use.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Seller info row
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        child: Icon(Icons.person),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Seller: Ahmad Store',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Kuala Lumpur', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SellerPageScreen(),
                            ),
                          );
                        },
                        child: const Text('View Shop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Add to cart
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CartScreen()),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('Add to Cart', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
