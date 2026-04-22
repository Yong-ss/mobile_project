import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../../widgets/product_card.dart';
import 'product_details_screen.dart';
import '../cart/cart_screen.dart';
import '../../utils/globals.dart';
import '../../utils/circular_reveal_route.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/translations.dart';

// Member 2: ShopScreen — full product browsing with category filter chips
class ShopScreen extends StatefulWidget {
  final String? initialCategory;
  const ShopScreen({super.key, this.initialCategory});

  @override
  State<ShopScreen> createState() => ShopScreenState();
}

class ShopScreenState extends State<ShopScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();

  bool _isSpeechEnabled = false;
  bool _isListening = false;
  final ValueNotifier<String> _speechTextNotifier = ValueNotifier<String>("");
  final ValueNotifier<bool> _isErrorNotifier = ValueNotifier<bool>(false);
  Timer? _autoDismissTimer;
  Timer? _silenceTimer;

  // Dynamic Data
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<String> _categories = [t('all')];
  String _selectedCategory = t('all');
  bool _isLoading = true;

  // Pagination
  final ScrollController _scrollController = ScrollController();
  int _page = 0;
  final int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Cart State
  int _cartCount = 0;
  bool _isDraggingOverCart = false;
  final ValueNotifier<bool> _isDraggingProductNotifier = ValueNotifier<bool>(false);
  final GlobalKey _cartButtonKey = GlobalKey();

  Future<void> _addToSupabaseCart(Map<String, dynamic> product) async {
    final supabase = Supabase.instance.client;
    final user = currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('add_to_cart_login')),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final response = await supabase
          .from('cart_item')
          .select('id, quantity')
          .eq('user_id', user['id'])
          .eq('product_id', product['id'])
          .maybeSingle();

      if (response == null) {
        // Only insert if it doesn't exist
        await supabase.from('cart_item').insert({
          'user_id': user['id'],
          'product_id': product['id'],
          'quantity': 1,
        });

        HapticFeedback.lightImpact();
        _fetchCartCount(); // Refresh count
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${t('added_to_cart')} (${product['name']})'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // If it exists, increment quantity
        final newQuantity = (response['quantity'] as int) + 1;
        await supabase
            .from('cart_item')
            .update({'quantity': newQuantity})
            .eq('id', response['id']);

        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${t('increased_quantity')} ${product['name']} $newQuantity'),
              backgroundColor: Colors.blueAccent,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  Future<void> _fetchCartCount() async {
    if (currentUser == null) return;
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('cart_item')
          .select('id')
          .eq('user_id', currentUser!['id']);

      setState(() {
        _cartCount = response.length;
      });
    } catch (e) {
      debugPrint('Error fetching cart count: $e');
    }
  }

  void setCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _searchController.clear(); // Clear search when switching categories
      _filterProducts();
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    } else {
      _selectedCategory = t('all');
    }
    _scrollController.addListener(_onScroll);
    _fetchProducts();
    _fetchCategories(); // Separate category fetch
    _fetchCartCount();
    _initSpeech();
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _speechToText.stop();
    _autoDismissTimer?.cancel();
    _silenceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreProducts();
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('product')
          .select('category')
          .eq('for_sale', true);

      final List<dynamic> data = response;
      final Set<String> uniqueCategories = data
          .map((p) => p['category'] as String?)
          .where((c) => c != null && c.isNotEmpty)
          .map((c) => c!)
          .toSet();

      if (mounted) {
        setState(() {
          _categories = [t('all'), ...uniqueCategories.toList()..sort()];
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _hasMore = true;
    });
    try {
      final supabase = Supabase.instance.client;

      var query = supabase.from('product').select().eq('for_sale', true);

      if (_selectedCategory != t('all')) {
        query = query.eq('category', _selectedCategory);
      }

      final searchTerm = _searchController.text.trim();
      if (searchTerm.isNotEmpty) {
        query = query.ilike('name', '%$searchTerm%');
      }

      final response = await query
          .order('name', ascending: true)
          .limit(_pageSize);

      final List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(response);

      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _hasMore = products.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching products: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      _page++;
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      final supabase = Supabase.instance.client;
      var query = supabase.from('product').select().eq('for_sale', true);

      if (_selectedCategory != t('all')) {
        query = query.eq('category', _selectedCategory);
      }

      final searchTerm = _searchController.text.trim();
      if (searchTerm.isNotEmpty) {
        query = query.ilike('name', '%$searchTerm%');
      }

      final response = await query
          .order('name', ascending: true)
          .range(from, to);

      final List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _allProducts.addAll(products);
          _filteredProducts = _allProducts;
          _hasMore = products.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more products: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _filterProducts() {
    // We now fetch from server when filtering/searching
    _fetchProducts();
  }

  void _initSpeech() async {
    _isSpeechEnabled = await _speechToText.initialize(
      onError: (error) => debugPrint('STT Error: $error'),
      onStatus: (status) {
        if (status == 'done') {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
    setState(() {});
  }

  void _startListening() async {
    if (!_isSpeechEnabled) return;

    _speechTextNotifier.value = "";
    _isErrorNotifier.value = false;
    _cancelAutoDismissTimer();
    _cancelSilenceTimer();

    _showVoiceSearchBottomSheet();

    _startSilenceTimer(); // Initial 3s silence detection

    await _speechToText.listen(
      onResult: (result) {
        _speechTextNotifier.value = result.recognizedWords;
        _startSilenceTimer(); // Reset silence timer on results

        if (result.finalResult) {
          _cancelSilenceTimer();
          _searchController.text = result.recognizedWords;
          _filterProducts();
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && Navigator.canPop(context)) Navigator.pop(context);
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
      ),
    );

    setState(() {
      _isListening = true;
    });
  }

  void _startSilenceTimer() {
    _cancelSilenceTimer();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      if (_isListening) {
        _stopListening();
      }
    });
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void _startAutoDismissTimer() {
    _cancelAutoDismissTimer();
    _autoDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _cancelAutoDismissTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  void _stopListening() async {
    await _speechToText.stop();
    _cancelSilenceTimer();

    setState(() {
      _isListening = false;
      // If we stopped but have no words, it's a silence error
      if (_speechTextNotifier.value.isEmpty) {
        _isErrorNotifier.value = true;
        _startAutoDismissTimer();
      }
    });
  }

  void _showVoiceSearchBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.45,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28),
                        onPressed: () {
                          _stopListening();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isErrorNotifier,
                    builder: (context, isError, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _speechTextNotifier,
                        builder: (context, words, _) {
                          bool hasWords = words.isNotEmpty;
                          return Column(
                            children: [
                              Text(
                                !hasWords ? (isError ? t('didnt_hear_that') : t('listening')) : words,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: hasWords ? Colors.black87 : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (isError)
                                Text(
                                  t('mic_error_sub'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      _cancelAutoDismissTimer();
                      _cancelSilenceTimer();
                      if (_isListening) {
                        _stopListening();
                      } else {
                        // Restart listening correctly within the bottom sheet
                        _speechTextNotifier.value = "";
                        _isErrorNotifier.value = false;
                        _startListeningFromInsideSheet(setSheetState);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('mic_try_again'),
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _stopListening();
      _cancelAutoDismissTimer();
      _cancelSilenceTimer();
    });
  }

  void _startListeningFromInsideSheet(StateSetter setSheetState) async {
    if (!_isSpeechEnabled) return;

    _startSilenceTimer();

    await _speechToText.listen(
      onResult: (result) {
        _speechTextNotifier.value = result.recognizedWords;
        _startSilenceTimer();

        if (result.finalResult) {
          _cancelSilenceTimer();
          _searchController.text = result.recognizedWords;
          _filterProducts();
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && Navigator.canPop(context)) Navigator.pop(context);
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
      ),
    );

    setState(() {
      _isListening = true;
      _isErrorNotifier.value = false;
    });
    setSheetState(() {});
  }


  @override
  Widget build(BuildContext context) {
    bool isFocused = _searchFocusNode.hasFocus;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text(t('shop'), style: const TextStyle(fontWeight: FontWeight.bold))),
        floatingActionButton: DragTarget<Map<String, dynamic>>(
          onWillAcceptWithDetails: (details) {
            setState(() => _isDraggingOverCart = true);
            return true;
          },
          onLeave: (data) => setState(() => _isDraggingOverCart = false),
          onAcceptWithDetails: (details) {
            setState(() => _isDraggingOverCart = false);
            _addToSupabaseCart(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            return SizedBox(
              width: 130,
              height: 130,
              child: Container(
                alignment: Alignment.bottomRight,
                child: AnimatedScale(
                  scale: _isDraggingOverCart ? 1.3 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: FloatingActionButton(
                    key: _cartButtonKey,
                    onPressed: () async {
                      await CircularRevealPageRoute.push(context, _cartButtonKey, const CartScreen());
                      _fetchCartCount();
                    },
                    backgroundColor: Colors.lightBlue,
                    elevation: _isDraggingOverCart ? 15 : 6,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: _isDraggingOverCart ? [
                          BoxShadow(
                            color: Colors.lightBlue.withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 6,
                          )
                        ] : [],
                      ),
                      child: Center(
                        child: Badge(
                          label: Text(_cartCount.toString()),
                          backgroundColor: Colors.red,
                          isLabelVisible: _cartCount > 0,
                          offset: const Offset(6, -6),
                          child: const Icon(Icons.shopping_cart, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        body: _isLoading
            ? const ShopSkeleton()
            : SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Search bar (Ch 3.1: TextField)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white)
                                  : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C).withValues(alpha: 0.5) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isFocused ? Colors.lightBlue : Colors.transparent,
                                width: isFocused ? 2 : 0,
                              ),
                              boxShadow: isFocused
                                  ? [
                                BoxShadow(
                                  color: Colors.lightBlue.withValues(alpha: isFocused ? 0.1 : 0.0),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 2),
                                )
                              ]
                                  : [],
                            ),
                            child: TextField(
                              focusNode: _searchFocusNode,
                              controller: _searchController,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: t('search_products'),
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onChanged: (value) {
                                _filterProducts();
                              },
                              onSubmitted: (_) => _searchFocusNode.unfocus(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _startListening,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.lightBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic_none,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Category filter chips row (Ch 3.1: horizontal ListView + FilterChip)
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: FilterChip(
                            label: Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.lightBlue.shade800
                                    : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (bool value) {
                              setState(() {
                                _selectedCategory = category;
                                _filterProducts();
                              });
                            },
                            selectedColor: Colors.lightBlue.shade100,
                            checkmarkColor: Colors.lightBlue,
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white10
                                : Colors.grey.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // GridView of products (Ch 3.1: GridView)
                  Expanded(
                    child: _isLoading && _allProducts.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredProducts.isEmpty
                        ? Center(child: Text(t('no_products_found')))
                        : CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                final product = _filteredProducts[index];
                                return LongPressDraggable<Map<String, dynamic>>(
                                  data: product,
                                  feedback: Material(
                                    elevation: 20,
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.transparent,
                                    child: Transform.scale(
                                      scale: 1.05,
                                      child: Container(
                                        width: 150,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 30,
                                              offset: const Offset(0, 10),
                                            )
                                          ],
                                        ),
                                        child: product['image_url'] != null
                                            ? ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.network(product['image_url'].toString().split(',')[0], fit: BoxFit.cover),
                                        )
                                            : const Icon(Icons.shopping_bag, size: 50),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.2,
                                    child: ProductCard(
                                      name: product['name'] ?? 'Unknown',
                                      price: product['price'].toString(),
                                      imageUrl: product['image_url'],
                                    ),
                                  ),
                                  onDragStarted: () {
                                    HapticFeedback.heavyImpact();
                                    _isDraggingProductNotifier.value = true;
                                  },
                                  onDragEnd: (details) {
                                    _isDraggingProductNotifier.value = false;
                                  },
                                  onDraggableCanceled: (velocity, offset) {
                                    _isDraggingProductNotifier.value = false;
                                  },
                                  child: GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProductDetailsScreen(
                                            productId: product['id'],
                                          ),
                                        ),
                                      );
                                      // Refresh count when returning from details
                                      _fetchCartCount();
                                    },
                                    child: ProductCard(
                                      name: product['name'] ?? 'Unknown',
                                      price: product['price'].toString(),
                                      imageUrl: product['image_url'],
                                    ),
                                  ),
                                );
                              },
                              childCount: _filteredProducts.length,
                            ),
                          ),
                        ),
                        if (_isLoadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                ],
              ),

              // FOCUS OVERLAY
              ValueListenableBuilder<bool>(
                valueListenable: _isDraggingProductNotifier,
                builder: (context, isDragging, child) {
                  return IgnorePointer(
                    ignoring: !isDragging,
                    child: AnimatedOpacity(
                      opacity: isDragging ? 0.6 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(color: Colors.black),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}