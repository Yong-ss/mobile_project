import 'package:flutter/material.dart';
import '../../widgets/product_card.dart';
import 'product_details_screen.dart';
import '../../utils/globals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/snackbar_helper.dart';

class SellerPageScreen extends StatefulWidget {
  final String? sellerId; // 可选参数：要查看的商家 ID
  const SellerPageScreen({super.key, this.sellerId});

  @override
  State<SellerPageScreen> createState() => _SellerPageScreenState();
}

class _SellerPageScreenState extends State<SellerPageScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allSellerProducts = [];
  Map<String, dynamic>? _sellerProfile; // 存店主资料

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      setState(() => _isLoading = true);

      // 1. 确定要查看哪个卖家的 ID
      final targetSellerId = widget.sellerId ?? currentUser!['id'];

      // 2. 先去抓店主的个人资料 (店名、头像、加入日期)
      final profile = await _supabase
          .from('user')
          .select('shop_name, shop_pic, shop_created_at')
          .eq('id', targetSellerId)
          .single();

      // 3. 再去抓这个卖家的商品列表
      final products = await _supabase
          .from('product')
          .select('*')
          .eq('seller_id', targetSellerId)
          .eq('for_sale', true);

      // 4. 全部抓完，一次性更新 UI
      setState(() {
        _sellerProfile = profile;
        _allSellerProducts = List<Map<String, dynamic>>.from(products);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        snackbar('Error loading shop: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 逻辑：直接使用刚才抓回来的 _sellerProfile 资料
    final String shopName = _sellerProfile?['shop_name'] ?? 'Shop Name';
    final String shopLogo = _sellerProfile?['shop_pic'] ?? '';
    final String joinDate = _sellerProfile?['shop_created_at'] != null
        ? _sellerProfile!['shop_created_at'].toString().split('T')[0]
        : 'Unknown';

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
                              builder: (context) => ProductDetailsScreen(
                                productId: product['id'],
                              ),
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
