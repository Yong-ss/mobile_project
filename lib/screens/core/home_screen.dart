import 'dart:async';
import 'package:flutter/material.dart';
import '../shop/shop_screen.dart';
import '../shop/product_details_screen.dart';
import '../cart/cart_screen.dart';
import '../core/profile_screen.dart';
import '../../widgets/product_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import 'announcement_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final int _selectedIndex = 0;

  // Announcements state
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingAnnouncements = true;
  final PageController _pageController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  // Products state
  List<Map<String, dynamic>> _featuredProducts = [];
  bool _isLoadingProducts = true;

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
    _fetchAnnouncements();
    _fetchProducts();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_announcements.isNotEmpty && _pageController.hasClients) {
        int nextIndex = (_currentBannerIndex + 1) % _announcements.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _fetchAnnouncements(),
      _fetchProducts(),
    ]);
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final userRole = currentUser?['role'] ?? 'Customer';

      final response = await _supabase
          .from('announcements')
          .select('id, title, content, image_url, priority_level, created_at')
          .eq('status', 'published')
          .not('image_url', 'is', null)
          .or('target_role.eq.All Users,target_role.eq.${userRole}s') // e.g. Customers or Sellers
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        final List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(response);

        // Define priority order: High (0), Medium (1), Low (2)
        final Map<String, int> priorityMap = {'High': 0, 'Medium': 1, 'Low': 2};

        fetched.sort((a, b) {
          // Compare priority levels first
          int pA = priorityMap[a['priority_level']] ?? 3;
          int pB = priorityMap[b['priority_level']] ?? 3;
          if (pA != pB) return pA.compareTo(pB);

          // Within same priority, sort by date (newest first)
          DateTime dateA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime(0);
          DateTime dateB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime(0);
          return dateB.compareTo(dateA);
        });

        setState(() {
          _announcements = fetched;
          _isLoadingAnnouncements = false;
        });
        if (_announcements.isNotEmpty) {
          _startBannerTimer();
        }
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      if (mounted) {
        setState(() {
          _isLoadingAnnouncements = false;
        });
      }
    }
  }

  Future<void> _fetchProducts() async {
    try {
      if (mounted) setState(() => _isLoadingProducts = true);

      final data = await _supabase
          .from('product')
          .select('*')
          .eq('for_sale', true)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _featuredProducts = List<Map<String, dynamic>>.from(data);
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
      if (mounted) {
        setState(() => _isLoadingProducts = false);
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
        onRefresh: _handleRefresh,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Welcome Banner Section ──
                Container(
                  width: double.infinity,
                  color: Colors.lightBlue.shade100,
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🛍️ Welcome to Priscon!',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Buy & Sell with your community',
                        style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Banner / Announcement Slider ──
                if (_isLoadingAnnouncements)
                  const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
                else if (_announcements.isNotEmpty)
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: _announcements.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentBannerIndex = index;
                            });
                            // Reset timer on manual swipe to prevent double-sliding
                            _startBannerTimer();
                          },
                          itemBuilder: (context, index) {
                            final ann = _announcements[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AnnouncementDetailsScreen(announcement: ann),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(ann['image_url']),
                                    fit: BoxFit.cover,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    ann['title'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _announcements.length,
                                  (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentBannerIndex == index ? 16 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentBannerIndex == index ? Colors.white : Colors.white60,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                _isLoadingProducts
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