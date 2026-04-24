import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_page_screen.dart';
import '../chat/chat_screen.dart';
import '../cart/cart_screen.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/translations.dart';
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

  // Carousel state
  late PageController _carouselController;
  Timer? _carouselTimer;
  int _currentCarouselPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchProductAndSeller();
    _fetchCartCount();
    _carouselController = PageController();
  }

  void _startCarouselTimer(int totalPages) {
    _carouselTimer?.cancel();
    if (totalPages <= 1) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_carouselController.hasClients) {
        _currentCarouselPage = (_currentCarouselPage + 1) % totalPages;
        _carouselController.animateToPage(
          _currentCarouselPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _fetchCartCount() async {
    final user = currentUser;
    if (user == null) {
      if (mounted) setState(() => _cartCount = 0);
      return;
    }

    try {
      // Use a count query to get the accurate number of distinct products in cart
      final response = await _supabase
          .from('cart_item')
          .select('id')
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

        final urls = (productData['image_url']?.toString() ?? '').split(',').where((u) => u.trim().isNotEmpty).toList();
        _startCarouselTimer(urls.length);
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
        imageUrl: (_productData?['image_url']?.toString() ?? '').split(',')[0],
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

  Offset imageOffset(RenderBox box) => box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
  Offset cartOffset(RenderBox box) => box.localToGlobal(Offset.zero) + Offset(box.size.width / 2, box.size.height / 2);

  Future<void> _addToSupabaseCart() async {
    if (_productData == null) return;

    String prodName = _productData?['name'] ?? 'unknown product';
    final user = currentUser;

    if (user == null) {
      if (mounted) snackbar(t('add_to_cart_login'), Colors.orange);
      return;
    }

    try {
      // 1. Check stock first
      final int availableStock = _productData!['quantity'] ?? 0;

      final response = await _supabase
          .from('cart_item')
          .select('id, quantity')
          .eq('user_id', user['id'])
          .eq('product_id', _productData!['id'])
          .maybeSingle();

      int currentInCart = response != null ? (response['quantity'] as int) : 0;

      if (currentInCart >= availableStock) {
        if (mounted) snackbar(t('all_stock_in_cart'), Colors.orange);
        return;
      }

      bool isNewItem = response == null;

      // Trigger animation
      _runFlyToCartAnimation(isNewItem: isNewItem);

      if (isNewItem) {
        await _supabase.from('cart_item').insert({
          'user_id': user['id'],
          'product_id': _productData!['id'],
          'quantity': 1,
        });
        if (mounted) snackbar('${t('added_to_cart_msg')} $prodName', Colors.green);
      } else {
        final newQuantity = currentInCart + 1;
        await _supabase
            .from('cart_item')
            .update({'quantity': newQuantity})
            .eq('id', response['id']);
        if (mounted) snackbar('${t('increased_quantity')} $prodName ($newQuantity)', Colors.blueAccent);
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
        appBar: AppBar(title: Text(t('error'))),
        body: Center(child: Text(t('no_products_found'))),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? const Color(0xFF212121) : Colors.white,
      child: SafeArea(
        top: true,
        child: Scaffold(
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
                if (_productData!['image_url'] != null && _productData!['image_url'].toString().isNotEmpty)
                  Builder(
                    builder: (context) {
                      final urls = _productData!['image_url'].toString().split(',').where((u) => u.trim().isNotEmpty).toList();

                      return SizedBox(
                        key: _imageKey, // Assign key here for animation start point
                        height: 350,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            PageView.builder(
                              controller: _carouselController,
                              itemCount: urls.length,
                              onPageChanged: (index) {
                                _currentCarouselPage = index;
                                // Restart timer on manual swipe
                                _startCarouselTimer(urls.length);
                              },
                              itemBuilder: (context, index) {
                                return Image.network(
                                  urls[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                                );
                              },
                            ),
                            // Page Indicator Dots
                            if (urls.length > 1)
                              Positioned(
                                bottom: 12,
                                child: ListenableBuilder(
                                  listenable: _carouselController,
                                  builder: (context, _) {
                                    int currentPage = 0;
                                    if (_carouselController.hasClients) {
                                      currentPage = _carouselController.page?.round() ?? 0;
                                    }
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(urls.length, (index) {
                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          width: currentPage == index ? 12 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: currentPage == index ? Colors.blue : Colors.white70,
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  const SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: Center(child: Icon(Icons.inventory_2, size: 80, color: Colors.grey)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _productData!['name'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 14,
                                color: _getStockColor(_productData!['quantity'] ?? 0),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getStockLabel(_productData!['quantity'] ?? 0),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _getStockColor(_productData!['quantity'] ?? 0),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'RM ${(double.tryParse(_productData!['price'].toString()) ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStockColor(_productData!['quantity'] ?? 0).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getStockLabel(_productData!['quantity'] ?? 0),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getStockColor(_productData!['quantity'] ?? 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('description'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _productData!['description'] ?? t('no_description_provided'),
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                      const SizedBox(height: 24),

                      // 重点：卖家资料卡 (Premium Profile-style Card)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF303030) : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.blue.shade100,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.lightBlue.withValues(alpha: 0.3), width: 1.5),
                              ),
                              child: CircleAvatar(
                                backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.blue.shade100,
                                backgroundImage: (_sellerData?['shop_pic'] != null)
                                    ? NetworkImage(_sellerData!['shop_pic'].toString().split(',')[0])
                                    : null,
                                child: (_sellerData?['shop_pic'] == null)
                                    ? const Icon(Icons.store, color: Colors.lightBlue)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _sellerData?['shop_name'] ?? t('mystery_shop'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    t('official_seller'),
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_sellerData?['id'] != null && _sellerData?['id'] != currentUser?['id'])
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        remoteUserId: _sellerData!['id'],
                                        remoteUserName: _sellerData!['shop_name'] ?? 'Unknown Seller',
                                        initialProduct: _productData,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.lightBlue),
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
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.lightBlue,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Text(t('visit_shop'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 购买按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_productData!['quantity'] ?? 0) > 0 ? _addToSupabaseCart : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: (_productData!['quantity'] ?? 0) > 0 ? Colors.lightBlue : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon((_productData!['quantity'] ?? 0) > 0 ? Icons.shopping_cart : Icons.not_interested),
                          label: Text(
                            (_productData!['quantity'] ?? 0) > 0 ? t('add_to_cart') : t('out_of_stock'),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStockColor(int quantity) {
    if (quantity <= 0) return Colors.red;
    if (quantity < 5) return Colors.red;
    if (quantity < 10) return Colors.orange;
    return Colors.green;
  }

  String _getStockLabel(int quantity) {
    if (quantity <= 0) return t('out_of_stock');
    if (quantity < 5) return 'Last In Stock: $quantity';
    if (quantity < 10) return 'Remaining Stock: $quantity';
    return '${t('in_stock')}: $quantity';
  }

  String t(String key) => Translations.translate(key);
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