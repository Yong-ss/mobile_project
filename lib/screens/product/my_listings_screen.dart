import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import 'upload_product_screen.dart';
import '../../utils/snackbar_helper.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _myProducts = [];

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
        snackbar('Error loading products: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMyProducts,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToUpload(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myProducts.isEmpty
              ? _buildEmptyState()
              : _buildProductList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToUpload(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No products listed yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _myProducts.length,
      itemBuilder: (context, index) {
        final product = _myProducts[index];
        final bool isForSale = product['for_sale'] ?? false;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: (product['image_url'] != null && product['image_url'].toString().isNotEmpty)
                    ? Image.network(
                        product['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                            Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)),
                      )
                    : Container(color: Colors.grey.shade200, child: const Icon(Icons.inventory_2)),
              ),
            ),
            title: Text(
              product['name'] ?? 'Unnamed Product',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'RM ${product['price']}',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Stock: ${product['quantity']} • ${isForSale ? "Active" : "Hidden"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isForSale ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // 你朋友以后可以在这里写详情或编辑逻辑
            },
          ),
        );
      },
    );
  }

  void _navigateToUpload(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UploadProductScreen()),
    ).then((_) => _fetchMyProducts()); // 传完回来自动刷新
  }
}
