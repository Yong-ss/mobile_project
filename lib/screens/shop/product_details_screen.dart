import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_page_screen.dart';
import '../cart/cart_screen.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int? productId; // 接收传进来的商品 ID

  const ProductDetailsScreen({super.key, this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _productData;
  Map<String, dynamic>? _sellerData;

  @override
  void initState() {
    super.initState();
    _fetchProductAndSeller();
  }

  Future<void> _fetchProductAndSeller() async {
    try {
      setState(() => _isLoading = true);

      final productData = await _supabase
          .from('product')
          .select('*')
          .eq('id', widget.productId ?? 0)
          .single();

      final sellerData = await _supabase
          .from('user')
          .select('shop_name, shop_pic, id')
          .eq('id', productData['seller_id'])
          .single();

      setState(() {
        _productData = productData;
        _sellerData = sellerData;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        snackbar('Error: $e', Colors.red);
      }
    }
  }

  Future<void> _addToSupabaseCart() async {

    if (_productData == null) return;
    
    String prodName = _productData?['name'] ?? 'unknown product';

    final user = currentUser;
    if (user == null) {
      if (mounted) {
        snackbar('Please login to add items to your cart', Colors.orange);
      }
      return;
    }

    try {
      final response = await _supabase
          .from('cart_item')
          .select('id, quantity')
          .eq('user_id', user['id'])
          .eq('product_id', _productData!['id'])
          .maybeSingle();

      if (response == null) {
        await _supabase.from('cart_item').insert({
          'user_id': user['id'],
          'product_id': _productData!['id'],
          'quantity': 1,
        });

        if (mounted) {
          snackbar('Added $prodName to cart!', Colors.green);
        }
      } else {
        if (mounted) {
          snackbar('$prodName is already in your cart', Colors.blueGrey);
        }
      }
    } catch (e) {
      print('Error adding to cart: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_productData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Product not found!')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_productData!['name'])),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品主图
            SizedBox(
              width: double.infinity,
              height: 300,
              child: (_productData!['image_url'] != null)
                  ? Image.network(_productData!['image_url'], fit: BoxFit.cover)
                  : const Placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _productData!['name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${_productData!['price']}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _productData!['description'] ?? 'No description provided.',
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  const SizedBox(height: 24),

                  // 重点：卖家资料卡
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: (_sellerData?['shop_pic'] != null)
                              ? NetworkImage(_sellerData!['shop_pic'])
                              : null,
                          child: (_sellerData?['shop_pic'] == null)
                              ? const Icon(Icons.store)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sellerData?['shop_name'] ?? 'Mystery Shop',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Official Seller',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SellerPageScreen(
                                  sellerId: _productData!['seller_id'],
                                ),
                              ),
                            );
                          },
                          child: const Text('Visit Shop'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 购买按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addToSupabaseCart,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text(
                        'Add to Cart',
                        style: TextStyle(fontSize: 18),
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
