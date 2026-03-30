import 'package:flutter/material.dart';
import '../../widgets/product_card.dart';
import 'product_details_screen.dart';
import '../../utils/globals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerPageScreen extends StatefulWidget {
  const SellerPageScreen({super.key});

  @override
  State<SellerPageScreen> createState() => _SellerPageScreenState();
}

class _SellerPageScreenState extends State<SellerPageScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allSellerProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      setState(() => _isLoading = true);

      final allProductData = await _supabase
          .from('product')
          .select('*')
          .eq('seller_id', currentUser!['id'])
          .eq('for_sale', true); // 只显示上架的商品

      setState(() {
        _allSellerProducts = List<Map<String, dynamic>>.from(allProductData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String shopName = currentUser!['shop_name'] ?? 'Mystery Shop';
    final String shopLogo = currentUser!['shop_pic'] ?? '';
    final String joinDate = currentUser!['shop_created_at'] != null
        ? currentUser!['shop_created_at'].toString().split('T')[0]
        : '2023';

    return Scaffold(
      appBar: AppBar(title: const Text('Seller Shop')),
      body: Column(
        children: [
          // Seller banner
          Container(
            width: double.infinity,
            color: Colors.lightBlue.shade50,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  backgroundImage: (shopLogo.isNotEmpty)
                      ? NetworkImage(shopLogo)
                      : null,
                  child: (shopLogo.isEmpty)
                      ? const Icon(Icons.store, size: 36)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  shopName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Joined on: $joinDate',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Products',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),

          // Seller's product grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allSellerProducts.isEmpty
                ? const Center(child: Text('No products available'))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: _allSellerProducts.length,
                    itemBuilder: (context, index) {
                      final product = _allSellerProducts[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProductDetailsScreen(),
                            ),
                          );
                        },
                        child: ProductCard(
                          name: product['name'] ?? 'No Name',
                          price: product['price'].toString(),
                          imageUrl: product['image_url'],
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
