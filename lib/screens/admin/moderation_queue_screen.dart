import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/globals.dart';

class ModerationQueueScreen extends StatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;
  bool _isFetchingMore = false;
  bool _isSelectionMode = false;
  bool _allSelected = false;
  final int _pageSize = 20;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isFetchingMore && _hasMore) {
          _fetchProducts(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (loadMore) {
      if (mounted) {
        setState(() => _isFetchingMore = true);
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _offset = 0;
          _hasMore = true;
          _products.clear();
        });
      }
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('product')
          .select('*, seller:seller_id(shop_name, email)')
          .order('name', ascending: true)
          .range(_offset, _offset + _pageSize - 1);

      final List<Map<String, dynamic>> newProducts = List<Map<String, dynamic>>.from(response).map((p) => {...p, 'isChecked': false}).toList();

      setState(() {
        if (loadMore) {
          _products.addAll(newProducts);
        } else {
          _products = newProducts;
        }
        _isLoading = false;
        _isFetchingMore = false;
        _hasMore = newProducts.length == _pageSize;
        _offset += newProducts.length;
      });
    } catch (e) {
      debugPrint('Error fetching moderation items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _logAction(String action, String details) async {
    try {
      await Supabase.instance.client.from('system_logs').insert({
        'admin_id': currentUser?['email'] ?? 'Unknown Admin',
        'action': action,
        'details': details,
      });
    } catch (e) {
      debugPrint('Error logging action: $e');
    }
  }

  void _deleteProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Violation Deletion'),
        content: Text('Are you sure you want to delete "${product['name']}"? This will permanently remove it from the seller\'s shop and the marketplace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Supabase.instance.client.from('product').delete().eq('id', product['id']);

                await _logAction('Delete Violating Product', 'Deleted "${product['name']}" from shop "${product['seller']?['shop_name']}"');

                if (!mounted) return;
                setState(() {
                  _products.removeWhere((p) => p['id'] == product['id']);
                });
                snackbar('Product removed successfully', Colors.green);
              } catch (e) {
                if (mounted) snackbar('Error removing product: $e', Colors.red);
              }
            },
            child: const Text('Delete for Violation'),
          ),
        ],
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: ThemeData.light(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text('Product Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: (product['image_url'] != null && product['image_url'].isNotEmpty)
                          ? Image.network(
                        product['image_url'].toString().split(',')[0],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                        ),
                      )
                          : Container(height: 200, color: Colors.grey.shade100, child: const Icon(Icons.image, size: 80, color: Colors.grey)),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow('Product Name', product['name'] ?? 'N/A', isTitle: true),
                    _buildDetailRow('Shop Name', product['seller']?['shop_name'] ?? 'Unknown'),
                    _buildDetailRow('Price', 'RM ${(double.tryParse(product['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}'),
                    _buildDetailRow('Category', product['category'] ?? 'N/A'),
                    const Divider(height: 32, color: Colors.black12),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text(product['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: isTitle ? 18 : 16, fontWeight: isTitle ? FontWeight.bold : FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      final search = _searchQuery.toLowerCase();
      final name = p['name'].toString().toLowerCase();
      final shop = (p['seller']?['shop_name'] ?? '').toString().toLowerCase();
      return name.contains(search) || shop.contains(search);
    }).toList();

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(_isSelectionMode ? '${_products.where((p) => p['isChecked'] == true).length} Selected' : 'Moderation Queue', style: const TextStyle(fontWeight: FontWeight.bold)),
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.lightBlue.withValues(alpha: 0.2),
          centerTitle: true,
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: Icon(_allSelected ? Icons.check_box : Icons.check_box_outline_blank),
                onPressed: _toggleSelectAll,
                tooltip: 'Select All',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: _deleteSelectedProducts,
                tooltip: 'Bulk Delete',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  for (var p in _products) {
                    p['isChecked'] = false;
                  }
                }),
              ),
            ]
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.lightBlue, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchProducts,
            color: Colors.lightBlue,
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _isLoading
                      ? _buildSkeleton()
                      : filteredProducts.isEmpty
                      ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No products found.'))])
                      : _buildProductList(filteredProducts),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSelectAll() {
    setState(() {
      _allSelected = !_allSelected;
      for (var p in _products) {
        p['isChecked'] = _allSelected;
      }
    });
  }

  void _deleteSelectedProducts() {
    final selectedIds = _products.where((p) => p['isChecked'] == true).map((p) => p['id']).toList();
    if (selectedIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Removal'),
        content: Text('Are you sure you want to delete ${selectedIds.length} selected products for violations? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Supabase.instance.client.from('product').delete().filter('id', 'in', selectedIds);
                await _logAction('Bulk Delete Products', 'Removed ${selectedIds.length} violating products');

                setState(() {
                  _products.removeWhere((p) => selectedIds.contains(p['id']));
                  _isSelectionMode = false;
                });
                snackbar('Products removed successfully', Colors.green);
              } catch (e) {
                snackbar('Error removing products: $e', Colors.red);
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search by Product Name or Shop...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF1976D2)),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: BaseSkeleton(width: double.infinity, height: 100, borderRadius: 16),
      ),
    );
  }

  Widget _buildProductList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (_isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final product = items[index];
        final isChecked = product['isChecked'] ?? false;

        return GestureDetector(
          onLongPress: () {
            setState(() {
              _isSelectionMode = true;
              product['isChecked'] = true;
            });
          },
          onTap: _isSelectionMode ? () {
            setState(() {
              product['isChecked'] = !isChecked;
            });
          } : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: _isSelectionMode && isChecked ? Border.all(color: Colors.blue, width: 2) : null,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          onChanged: (val) => setState(() => product['isChecked'] = val),
                          activeColor: Colors.lightBlue,
                        ),
                        const Text('Select Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ListTile(
                  onTap: () => _showProductDetails(product),
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (product['image_url'] != null && product['image_url'].isNotEmpty)
                        ? Image.network(
                      product['image_url'].toString().split(',')[0],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    )
                        : const Icon(Icons.image, size: 50),
                  ),
                  title: Text(product['name'] ?? 'Untitled Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Shop: ${product['seller']?['shop_name'] ?? 'Unknown'}', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
                      Text('Price: RM ${(double.tryParse(product['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  trailing: _isSelectionMode ? null : IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => _deleteProduct(product),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
