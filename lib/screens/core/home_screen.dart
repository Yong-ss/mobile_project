import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shop/shop_screen.dart';
import '../shop/product_details_screen.dart';
import '../cart/cart_screen.dart';
import '../core/profile_screen.dart';
import '../../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final int _selectedIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _featuredProducts = [];

  // 原有的分类列表保持图标样式
  final List<Map<String, dynamic>> _categories = const [
    {'label': 'Furniture', 'icon': Icons.chair},
    {'label': 'Electronics', 'icon': Icons.devices},
    {'label': 'Fashion', 'icon': Icons.checkroom},
    {'label': 'Beauty', 'icon': Icons.face},
    {'label': 'Groceries', 'icon': Icons.shopping_basket},
    {'label': 'Others', 'icon': Icons.grid_view},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllProducts();
  }

  Future<void> _fetchAllProducts() async {
    try {
      setState(() => _isLoading = true);
      
      final data = await _supabase
          .from('product')
          .select('*')
          .eq('for_sale', true)
          .order('created_at', ascending: false)
          .limit(10); // 首页先展示最新的 10 个

      setState(() {
        _featuredProducts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // 静默失败或简单报错
      }
    }
  }

  void _onNavItemTapped(int index) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopScreen()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
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
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllProducts, // 下拉刷新
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Banner ──
                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.lightBlue.shade100, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '🛍️ Welcome to Priscon!',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text('Buy & Sell with your community'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Categories ──
                _buildSectionHeader('Categories'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          // TODO: 传分类参数去 ShopScreen
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopScreen()));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.lightBlue.shade50,
                                child: Icon(_categories[index]['icon'] as IconData, color: Colors.lightBlue),
                              ),
                              const SizedBox(height: 6),
                              Text(_categories[index]['label'] as String, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Featured Products Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Latest Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopScreen())),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),

                // ── Featured GridView ──
                _isLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                    : _featuredProducts.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No products found')))
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _featuredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _featuredProducts[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: product['id'])),
                                  );
                                },
                                child: ProductCard(
                                  name: product['name'] ?? 'Unnamed',
                                  price: product['price'].toString(),
                                  imageUrl: product['image_url'],
                                ),
                              );
                            },
                          ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
