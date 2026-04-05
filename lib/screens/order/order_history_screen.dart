import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/globals.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'order_details_screen.dart';

// Member 3: Order History — buyer's list of past orders.
// Integrated with live Supabase data, dynamic filtering, and premium shimmers.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = true;
  bool _isInitialLoading = true;
  List<Map<String, dynamic>> _liveOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // Premium reveal strategy
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isInitialLoading = false);
    });
  }

  Future<void> _fetchOrders() async {
    final supabase = Supabase.instance.client;
    final user = currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('orders')
          .select('*, location:location_id(*), seller:seller_id(username, shop_name), order_items:order_item(*, product:product_id(*))')
          .eq('buyer_id', user['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _liveOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'All') return _liveOrders;
    return _liveOrders.where((o) {
      final loc = o['location'] as Map<String, dynamic>?;
      final type = loc?['location_type'] ?? 'Delivery';
      return type == _selectedFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: (_isLoading || _isInitialLoading)
          ? const OrderHistorySkeleton()
          : Column(
        children: [
          // ── Category Filter Bar ──
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', 'Delivery', 'Pick Up'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedFilter = filter),
                      selectedColor: Colors.lightBlue.shade100,
                      checkmarkColor: Colors.lightBlue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.lightBlue.shade800 : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: isSelected ? Colors.lightBlue.withValues(alpha: 0.2) : Colors.transparent),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Orders List ──
          Expanded(
            child: _filteredOrders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                return _OrderCard(order: _filteredOrders[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent purchases will appear here.',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isExpanded = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'Order Placed': return Colors.blue;
      case 'Preparing': return Colors.orange;
      case 'Ready for Pickup':
      case 'Out for Delivery': return Colors.lightBlue;
      case 'Delivered':
      case 'Picked Up': return Colors.green;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order['status'] ?? 'Pending';
    final location = order['location'] as Map<String, dynamic>?;
    final locationType = location?['location_type'] ?? 'Delivery';
    final isPickup = locationType == 'Pick Up';

    final orderItems = order['order_items'] as List<dynamic>? ?? [];
    String itemName = 'Unknown Item';
    String imageUrl = '';
    final seller = order['seller'] as Map<String, dynamic>?;
    String shopName = seller?['shop_name'] ?? seller?['username'] ?? 'Unknown Shop';

    if (orderItems.isNotEmpty) {
      final firstItem = orderItems[0];
      final firstProduct = firstItem['product'] as Map<String, dynamic>?;

      itemName = firstProduct?['name'] ?? 'Unknown Item';
      imageUrl = firstProduct?['image_url'] ?? '';

      if (orderItems.length > 1) {
        itemName += ' and ${orderItems.length - 1} more';
      }
    }

    final createdAt = DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy').format(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OrderDetailsScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                        imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.shopping_bag, color: Colors.grey),
                        ),
                      )
                          : Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.shopping_bag, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ID & Item Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${order['id'].toString().substring(0, 8).toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            itemName,
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'by $shopName',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.normal),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // "Show More" expansion area
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem(
                          isPickup ? Icons.storefront : Icons.local_shipping,
                          isPickup ? 'Pick Up' : 'Delivery',
                          location?['title'] ?? 'N/A',
                        ),
                        Text(
                          'RM ${(double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.lightBlue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),

            // Expansion Toggle Button
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isExpanded ? Icons.remove_circle_outline : Icons.add_circle_outline,
                        size: 16, color: Colors.lightBlue),
                    const SizedBox(width: 8),
                    Text(
                      _isExpanded ? 'Show Less' : 'More Info',
                      style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            SizedBox(
              width: 140, // Limit width to prevent overflow
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}