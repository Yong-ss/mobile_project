import 'package:flutter/material.dart';
import '../../widgets/product_card.dart';
import 'product_details_screen.dart';

// Member 2: ShopScreen — full product browsing with category filter chips
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  final List<Map<String, String>> _products = const [
    {'name': 'Bluetooth Speaker', 'price': '60.00', 'cat': 'Electronics'},
    {'name': 'Denim Jacket', 'price': '85.00', 'cat': 'Fashion'},
    {'name': 'Notebook Set', 'price': '15.00', 'cat': 'Books'},
    {'name': 'Desk Lamp', 'price': '40.00', 'cat': 'Electronics'},
    {'name': 'Yoga Mat', 'price': '55.00', 'cat': 'Sports'},
    {'name': 'Phone Stand', 'price': '12.00', 'cat': 'Electronics'},
    {'name': 'Cotton T-Shirt', 'price': '25.00', 'cat': 'Fashion'},
    {'name': 'USB Hub', 'price': '35.00', 'cat': 'Electronics'},
  ];

  final List<String> _categories = const [
    'All',
    'Electronics',
    'Fashion',
    'Books',
    'Sports',
    'Food',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: Column(
        children: [
          // Search bar (Ch 3.1: TextField)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Category filter chips row (Ch 3.1: horizontal ListView + FilterChip)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isFirst = index == 0; // "All" selected by default visually
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_categories[index]),
                    selected: isFirst,
                    onSelected: (value) {}, // filter logic added later
                    selectedColor: Colors.lightBlue.shade100,
                    checkmarkColor: Colors.lightBlue,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // GridView of products (Ch 3.1: GridView)
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: _products.length,
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
                    name: _products[index]['name']!,
                    price: _products[index]['price']!,
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
