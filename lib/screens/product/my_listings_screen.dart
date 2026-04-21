import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import 'upload_product_screen.dart';
import '../../utils/snackbar_helper.dart';
import 'edit_product.dart';
import '../../utils/circular_reveal_route.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/translations.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _myProducts = [];
  String _selectedCategory = 'All';
  final GlobalKey _addKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchMyProducts();
  }

  Future<void> _fetchMyProducts() async {
    try {
      setState(() => _isLoading = true);
      final data = await _supabase
          .from('product')
          .select('*')
          .eq('seller_id', currentUser!['id'])
          .order('created_at', ascending: false);

      setState(() {
        _myProducts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        snackbar('${t('error')}: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          t('my_listings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMyProducts,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCategorySelector(),
            Expanded(
              child: _isLoading
                  ? const MyListingsSkeleton()
                  : _filteredProducts().isEmpty
                  ? _buildEmptyState()
                  : _buildProductList(_filteredProducts()),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: _addKey,
        onPressed: () {
          CircularRevealPageRoute.push(
            context,
            _addKey,
            const UploadProductScreen(),
          ).then((_) => _fetchMyProducts());
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 'All'
                ? t('no_products_found')
                : '${t('empty_in')} $_selectedCategory',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 55,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: shopCategories.length,
        itemBuilder: (context, index) {
          final category = shopCategories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (val) =>
              val ? setState(() => _selectedCategory = category) : null,
              selectedColor: Colors.blue.withValues(alpha: 0.15),
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.lightBlueAccent : Colors.blue)
                    : (isDark ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList(List<Map<String, dynamic>> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final bool isForSale = product['for_sale'] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05)
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProductScreen(product: product),
                ),
              ).then((value) {
                if (value == true) _fetchMyProducts();
              });
            },
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _buildProductImage(product['image_url']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RM ${product['price']}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 12,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${t('stock')}: ${product['quantity']}',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildStatusDot(isForSale),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductImage(String? url) {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: (url != null && url.isNotEmpty)
            ? Image.network(
          url.split(',')[0],
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) =>
          const Icon(Icons.image_not_supported),
        )
            : const Icon(Icons.image, color: Colors.grey),
      ),
    );
  }

  Widget _buildStatusDot(bool isActive) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isActive ? t('active') : t('inactive'),
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredProducts() {
    if (_selectedCategory == 'All') return _myProducts;
    return _myProducts
        .where((p) => p['category'] == _selectedCategory)
        .toList();
  }
}