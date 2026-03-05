import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final String price;

  const ProductCard({super.key, required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder (lecture Ch 3.1: Placeholder widget)
          const Expanded(
            child: Placeholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text('RM $price'),
          ),
        ],
      ),
    );
  }
}
