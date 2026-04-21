import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'package:intl/intl.dart';
import '../../services/system_log_service.dart';

class AdminOrderManagementScreen extends StatefulWidget {
  const AdminOrderManagementScreen({super.key});

  @override
  State<AdminOrderManagementScreen> createState() => _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState extends State<AdminOrderManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isSelectionMode = false;
  bool _allSelected = false;

  final List<String> _categories = ['All', 'Pending', 'Fail', 'Completed'];
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final int _pageSize = 20;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllOrders();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isFetchingMore && _hasMore) {
          _fetchAllOrders(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllOrders({bool loadMore = false}) async {
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
          _allOrders.clear();
        });
      }
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('orders')
          .select('*, seller:seller_id(shop_name, email), buyer:buyer_id(username, email)')
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      final List<Map<String, dynamic>> newOrders = List<Map<String, dynamic>>.from(response).map((o) => {...o, 'isChecked': false}).toList();

      setState(() {
        if (loadMore) {
          _allOrders.addAll(newOrders);
        } else {
          _allOrders = newOrders;
        }
        _isLoading = false;
        _isFetchingMore = false;
        _hasMore = newOrders.length == _pageSize;
        _offset += newOrders.length;
      });
    } catch (e) {
      debugPrint('Error fetching master orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }


  void _deleteOrder(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to permanently delete Order #${order['id'].toString().substring(0, 8).toUpperCase()}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final orderId = order['id'];
                await Supabase.instance.client.from('orders').delete().eq('id', orderId);

                await systemLogService.logAction('Delete Order', 'Permanently deleted Order #$orderId (Buyer: ${order['buyer']?['email']})');

                if (!mounted) return;
                setState(() {
                  _allOrders.removeWhere((o) => o['id'] == orderId);
                });
                snackbar('Order deleted successfully', Colors.green);
              } catch (e) {
                if (mounted) snackbar('Error deleting order: $e', Colors.red);
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: ThemeData.light(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Order Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                        _buildStatusChip(order['status'] ?? 'N/A'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow('Order ID', '#${order['id'].toString().toUpperCase()}'),
                    _buildDetailRow('Transaction Date', DateFormat('dd MMM yyyy, HH:mm').format(DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now())),
                    const Divider(height: 32, color: Colors.black12),
                    const Text('Parties Involved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    const SizedBox(height: 16),
                    _buildDetailRow('Seller / Shop', order['seller']?['shop_name'] ?? 'Unknown'),
                    _buildDetailRow('Buyer Name', order['buyer']?['username'] ?? 'Anonymous'),
                    _buildDetailRow('Shipping Address', order['address'] ?? 'No address provided'),
                    const Divider(height: 32, color: Colors.black12),
                    const Text('Financial Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    const SizedBox(height: 16),
                    _buildDetailRow('Payment Method', order['payment_method']?.toString().toUpperCase() ?? 'N/A'),
                    _buildDetailRow('Total Amount', 'RM ${(double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}', isTitle: true),
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
          Text(value, style: TextStyle(fontSize: isTitle ? 18 : 15, fontWeight: isTitle ? FontWeight.bold : FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _allOrders.where((o) {
      final status = o['status'] ?? 'Pending';
      final search = _searchQuery.toLowerCase();
      final id = o['id'].toString().toLowerCase();
      final shop = (o['seller']?['shop_name'] ?? '').toString().toLowerCase();
      final buyer = (o['buyer']?['username'] ?? '').toString().toLowerCase();

      // Search Filter
      final matchesSearch = id.contains(search) || shop.contains(search) || buyer.contains(search);

      // Category Filter
      bool matchesCategory = true;
      if (_selectedCategory == 'Pending') {
        matchesCategory = !['cancelled', 'failed', 'delivered', 'picked up', 'completed'].contains(status.toLowerCase());
      } else if (_selectedCategory == 'Fail') {
        matchesCategory = ['cancelled', 'failed'].contains(status.toLowerCase());
      } else if (_selectedCategory == 'Completed') {
        matchesCategory = ['delivered', 'picked up', 'completed'].contains(status.toLowerCase());
      }

      return matchesSearch && matchesCategory;
    }).toList();

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(_isSelectionMode ? '${_allOrders.where((o) => o['isChecked'] == true).length} Selected' : 'Order Master', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                onPressed: _deleteSelectedOrders,
                tooltip: 'Delete Selected',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  for (var o in _allOrders) {
                    o['isChecked'] = false;
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
            onRefresh: _fetchAllOrders,
            color: Colors.lightBlue,
            child: Column(
              children: [
                _buildSearchBar(),
                _buildCategoryFilter(),
                Expanded(
                  child: _isLoading
                      ? _buildSkeleton()
                      : filteredOrders.isEmpty
                      ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No orders found.'))])
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16, top: 16),
                    itemCount: filteredOrders.length + (_isFetchingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredOrders.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return _buildOrderCard(filteredOrders[index]);
                    },
                  ),
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
      for (var o in _allOrders) {
        o['isChecked'] = _allSelected;
      }
    });
  }

  void _deleteSelectedOrders() {
    final selectedIds = _allOrders.where((o) => o['isChecked'] == true).map((o) => o['id']).toList();
    if (selectedIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Deletion'),
        content: Text('Are you sure you want to delete ${selectedIds.length} selected orders? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Supabase.instance.client.from('orders').delete().filter('id', 'in', selectedIds);
                await systemLogService.logAction('Bulk Delete Orders', 'Permanently deleted ${selectedIds.length} orders: ${selectedIds.join(', ')}');

                setState(() {
                  _allOrders.removeWhere((o) => selectedIds.contains(o['id']));
                  _isSelectionMode = false;
                });
                snackbar('Orders deleted successfully', Colors.green);
              } catch (e) {
                snackbar('Error deleting orders: $e', Colors.red);
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedCategory = cat);
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.lightBlue.shade50,
              labelStyle: TextStyle(
                color: isSelected ? Colors.lightBlue : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? Colors.lightBlue : Colors.grey.shade300),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              showCheckmark: true,
              checkmarkColor: Colors.lightBlue,
            ),
          );
        },
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
          hintText: 'Search by Order ID, Shop, or Buyer...',
          prefixIcon: const Icon(Icons.search, color: Colors.lightBlue),
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
        child: BaseSkeleton(width: double.infinity, height: 140, borderRadius: 16),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'Pending';
    final createdAt = DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM, HH:mm').format(createdAt);

    final isChecked = order['isChecked'] ?? false;

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          order['isChecked'] = true;
        });
      },
      onTap: _isSelectionMode ? () {
        setState(() {
          order['isChecked'] = !isChecked;
        });
      } : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _isSelectionMode && isChecked ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 12),
                child: Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          order['isChecked'] = val;
                        });
                      },
                      activeColor: Colors.lightBlue,
                    ),
                    const Text('Select Order', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                  ],
                ),
              ),
            InkWell(
              onTap: () => _showOrderDetails(order),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#${order['id'].toString().substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0091CC)),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.storefront, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Shop: ${order['seller']?['shop_name'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Buyer: ${order['buyer']?['username'] ?? 'Anonymous'}', style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                          'RM ${(double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _deleteOrder(order),
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    label: const Text('Delete Record', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    final statusLower = status.toLowerCase();
    if (['delivered', 'picked up', 'completed'].contains(statusLower)) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
    } else if (['cancelled', 'failed'].contains(statusLower)) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
    } else {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
