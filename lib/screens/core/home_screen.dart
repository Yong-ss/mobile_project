import 'package:flutter/material.dart';
import '../shop/shop_screen.dart';
import '../shop/product_details_screen.dart';
import '../cart/cart_screen.dart';
import '../core/profile_screen.dart';
import '../../widgets/product_card.dart';

// HomeScreen: StatefulWidget — tracks BottomNavigationBar selection
// 4 tabs: Home / Shop / Cart / Profile (Ch 3.1: stateful for interactive UI)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _selectedIndex = 0;

  final List<Map<String, String>> _featuredProducts = const [
    {'name': 'Wireless Headphones', 'price': '89.00'},
    {'name': 'Cotton T-Shirt', 'price': '25.00'},
    {'name': 'Mechanical Keyboard', 'price': '199.00'},
    {'name': 'Running Shoes', 'price': '150.00'},
  ];

  final List<Map<String, dynamic>> _categories = const [
    {'label': 'Electronics', 'icon': Icons.devices},
    {'label': 'Fashion', 'icon': Icons.checkroom},
    {'label': 'Books', 'icon': Icons.book},
    {'label': 'Sports', 'icon': Icons.sports_soccer},
    {'label': 'Food', 'icon': Icons.fastfood},
    {'label': 'More', 'icon': Icons.grid_view},
  ];

  void _onNavItemTapped(int index) {
    // Push-only nav: Home stays as root, no index drift on back
    if (index == 1) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ShopScreen()));
    } else if (index == 2) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const CartScreen()));
    } else if (index == 3) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: Colors.lightBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // required for 4 tabs
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Shop'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner ──
              Container(
                width: double.infinity,
                height: 160,
                color: Colors.lightBlue.shade100,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '🛍️ Welcome to Priscon!',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text('Buy & Sell with your community'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Categories ──
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Categories',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 88,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        // Tap category → go to Shop (filter logic added later)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ShopScreen()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  Colors.lightBlue.shade50,
                              child: Icon(
                                _categories[index]['icon'] as IconData,
                                color: Colors.lightBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _categories[index]['label'] as String,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── Featured Products header + View All ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Featured Products',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ShopScreen()),
                        );
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Featured GridView (just 4 items) ──
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemCount: _featuredProducts.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const ProductDetailsScreen()),
                      );
                    },
                    child: ProductCard(
                      name: _featuredProducts[index]['name']!,
                      price: _featuredProducts[index]['price']!,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
