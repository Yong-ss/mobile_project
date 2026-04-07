import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_page_screen.dart';
import '../cart/cart_screen.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int? productId;

  const ProductDetailsScreen({super.key, this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _productData;
  Map<String, dynamic>? _sellerData;

  // Animation & Badge state
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _cartKey = GlobalKey();
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProductAndSeller();
    _fetchCartCount();
  }

  Future<void> _fetchCartCount() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('cart_item')
          .select('id') // Just need to count the rows
          .eq('user_id', user['id']);

      if (mounted) {
        setState(() => _cartCount = response.length);
      }
    } catch (e) {
      debugPrint('Error fetching cart count: $e');
    }
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

  void _runFlyToCartAnimation({bool isNewItem = false}) {
    final RenderBox? imageBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? cartBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;

    if (imageBox == null || cartBox == null) return;

    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _FlyToCartOverlay(
        startPosition: imageOffset(imageBox),
        endPosition: cartOffset(cartBox),
        imageUrl: _productData?['image_url'] ?? '',
        onComplete: () {
          overlayEntry?.remove();
          if (isNewItem) {
            setState(() => _cartCount++);
          }
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  Offset imageOffset(RenderBox box) => box.localToGlobal(Offset.zero);
  Offset cartOffset(RenderBox box) => box.localToGlobal(Offset.zero) + Offset(box.size.width / 2, box.size.height / 2);

  Future<void> _addToSupabaseCart() async {
    if (_productData == null) return;

    String prodName = _productData?['name'] ?? 'unknown product';
    final user = currentUser;

    if (user == null) {
      if (mounted) snackbar('Please login to add items to your cart', Colors.orange);
      return;
    }

    try {
      final response = await _supabase
          .from('cart_item')
          .select('id, quantity')
          .eq('user_id', user['id'])
          .eq('product_id', _productData!['id'])
          .maybeSingle();

      bool isNewItem = response == null;

      // Trigger animation
      _runFlyToCartAnimation(isNewItem: isNewItem);

      if (isNewItem) {
        await _supabase.from('cart_item').insert({
          'user_id': user['id'],
          'product_id': _productData!['id'],
          'quantity': 1,
        });
        if (mounted) snackbar('Added $prodName to cart!', Colors.green);
      } else {
        final newQuantity = (response['quantity'] as int) + 1;
        await _supabase
            .from('cart_item')
            .update({'quantity': newQuantity})
            .eq('id', response['id']);
        if (mounted) snackbar('Increased $prodName quantity to $newQuantity', Colors.blueAccent);
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: ProductDetailsSkeleton());
    }

    if (_productData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Product not found!')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData!['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                key: _cartKey,
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Container(
                      key: ValueKey<int>(_cartCount),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品主图
            SizedBox(
              key: _imageKey,
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

class _FlyToCartOverlay extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final String imageUrl;
  final VoidCallback onComplete;

  const _FlyToCartOverlay({
    required this.startPosition,
    required this.endPosition,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<_FlyToCartOverlay> createState() => _FlyToCartOverlayState();
}

class _FlyToCartOverlayState extends State<_FlyToCartOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart);
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double t = _animation.value;
        final double x = widget.startPosition.dx + (widget.endPosition.dx - widget.startPosition.dx) * t;
        final double y = widget.startPosition.dy + (widget.endPosition.dy - widget.startPosition.dy) * t;
        final double size = 100 * (1 - t * 0.8);
        final double opacity = 1 - (t * 0.5);

        return Positioned(
          left: x - (size / 2),
          top: y - (size / 2),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size / 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size / 4),
                child: Image.network(widget.imageUrl, fit: BoxFit.cover),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProductDetailsSkeleton extends StatelessWidget {
  const ProductDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Basic placeholder for skeleton
    return const Center(child: CircularProgressIndicator());
  }
}