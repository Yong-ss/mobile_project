import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/translations.dart';
import '../chat/chat_screen.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'receipt_screen.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const SellerOrderDetailScreen({super.key, required this.orderId});

  @override
  State<SellerOrderDetailScreen> createState() => _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _order;
  bool _isInfoExpanded = false;
  bool _isMapExpanded = false;
  bool _isMapLoading = false; // Add map loading state like buyer screen

  // Status Lifecycle for sequential locking
  static const List<String> deliveryFlow = ['Pending', 'Preparing', 'Out for Delivery', 'Delivered'];
  static const List<String> pickupFlow = ['Pending', 'Preparing', 'Ready for Pickup', 'Picked Up'];

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, buyer:buyer_id(id, username, email), location:location_id(*), order_items:order_item(*, product:product_id(*))')
          .eq('id', widget.orderId)
          .single();


      if (mounted) {
        setState(() {
          _order = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }



  String _getEffectiveStatus(String status, bool isPickup) {
    if (['Order Placed', 'Pending'].contains(status)) return 'Pending';
    if (status.toLowerCase() == 'completed') return isPickup ? 'Picked Up' : 'Delivered';
    final flow = isPickup ? pickupFlow : deliveryFlow;
    if (flow.contains(status)) return status;
    if (status == 'Cancelled') return 'Cancelled';
    return 'Pending';
  }

  bool _isStatusEnabled(String target, String current, bool isPickup) {
    if (current == 'Cancelled') return true;
    final flow = isPickup ? pickupFlow : deliveryFlow;
    final currentIndex = flow.indexOf(current == 'Order Placed' ? 'Pending' : current);
    final targetIndex = flow.indexOf(target);
    if (currentIndex == flow.length - 1) return true;
    return targetIndex <= currentIndex + 1;
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final Map<String, dynamic> updates = {'status': newStatus};
      final now = DateTime.now().toIso8601String();

      if (['Out for Delivery', 'Ready for Pickup'].contains(newStatus)) {
        updates['shipped_at'] = now;
      } else if (['Delivered', 'Picked Up'].contains(newStatus)) {
        updates['completed_at'] = now;
      }

      await _supabase.from('orders').update(updates).eq('id', widget.orderId);
      _fetchOrderDetails();
      if (mounted) snackbar('${t('status_updated')}: $newStatus', Colors.green);
    } catch (e) {
      if (mounted) snackbar('Error: $e', Colors.red);
    }
  }

  Future<void> _handleCancelOrder() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('cancel_order_confirm')),
        content: Text(t('cancel_order_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('no'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t('yes')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('orders').update({'status': 'Cancelled'}).eq('id', widget.orderId);

      final orderItems = _order?['order_items'] as List<dynamic>? ?? [];
      for (var item in orderItems) {
        final product = item['product'] as Map<String, dynamic>?;
        if (product == null) continue;
        final int currentQty = product['quantity'] ?? 0;
        final int orderQty = item['quantity'] ?? 0;
        final int newQty = currentQty + orderQty;
        await _supabase.from('product').update({
          'quantity': newQty,
          'stock_status': newQty > 0 ? 'In Stock' : 'Out of Stock',
        }).eq('id', product['id']);
      }

      _fetchOrderDetails();
      if (mounted) snackbar(t('inventory_restored'), Colors.green);
    } catch (e) {
      if (mounted) snackbar('Error: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(t('order_details'))),
        body: const OrderDetailsSkeletonUI(),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t('order_details'))),
        body: Center(child: Text(t('order_not_found'))),
      );
    }

    final String displayOrderId = '#${widget.orderId.substring(0, 8).toUpperCase()}';
    final location = _order!['location'] as Map<String, dynamic>?;
    final locationType = location?['location_type'] ?? 'Delivery';
    final bool isPickup = locationType == 'Pick Up';
    final String status = _order!['status'] ?? 'Pending';
    final statusLower = status.toLowerCase();
    final isFinalized = ['delivered', 'picked up', 'completed', 'cancelled'].contains(statusLower);

    final buyer = _order!['buyer'] as Map<String, dynamic>?;

    final List<dynamic> orderItems = _order!['order_items'] as List<dynamic>? ?? [];
    final double totalAmount = double.tryParse(_order!['total_amount']?.toString() ?? '0') ?? 0.0;

    final createdAt = DateTime.tryParse(_order!['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);

    // New Fields for Shopee Section
    final String fullOrderId = widget.orderId.toUpperCase();
    final String paymentMethod = _order!['payment_method'] ?? 'N/A';

    String formatTimestamp(dynamic ts) {
      if (ts == null) return 'N/A';
      final dt = DateTime.tryParse(ts.toString());
      if (dt == null) return 'N/A';
      return DateFormat('dd-MM-yyyy HH:mm').format(dt);
    }

    final String paymentTime = formatTimestamp(_order!['payment_at']);
    final String shipTime = formatTimestamp(_order!['shipped_at']);
    final String completedTime = formatTimestamp(_order!['completed_at']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Order Details', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Order Summary Card ──
              (() {
                final effectiveStatusForGradient = _getEffectiveStatus(status, isPickup);
                List<Color> gradientColors;
                Color shadowColor;

                if (effectiveStatusForGradient == 'Pending') {
                  gradientColors = [Colors.grey.shade700, Colors.grey.shade600, Colors.grey.shade500];
                  shadowColor = Colors.grey.withValues(alpha: 0.3);
                } else if (effectiveStatusForGradient == 'Preparing') {
                  gradientColors = [Colors.blueAccent.shade700, Colors.lightBlue.shade500];
                  shadowColor = Colors.blueAccent.withValues(alpha: 0.3);
                } else if (['Out for Delivery', 'Ready for Pickup'].contains(effectiveStatusForGradient)) {
                  gradientColors = [Colors.lime.shade900, Colors.lime.shade700, Colors.lime.shade600];
                  shadowColor = Colors.lime.withValues(alpha: 0.3);
                } else {
                  gradientColors = [const Color(0xFF1B5E20), const Color(0xFF2E7D32), const Color(0xFF388E3C)];
                  shadowColor = Colors.green.withValues(alpha: 0.3);
                }

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t('order_id')}: $displayOrderId',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.0)),
                                const SizedBox(height: 4),
                                Text('${t('placed_on')} $formattedDate',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              })(),
              const SizedBox(height: 24),

              // ── Status Management (SELLER SPECIFIC) ──
              if (!isFinalized) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.lightBlue.withValues(alpha: 0.3)
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Update Order Status', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('status_$fullOrderId'),
                        initialValue: _getEffectiveStatus(status, isPickup),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) {
                          if (val != null && val != status) _updateStatus(val);
                        },
                        items: (isPickup ? pickupFlow : deliveryFlow).map((s) {
                          final enabled = _isStatusEnabled(s, status, isPickup);
                          return DropdownMenuItem(
                              value: s,
                              enabled: enabled,
                              child: Text(s, style: TextStyle(color: enabled ? null : Colors.grey))
                          );
                        }).toList(),
                      ),
                      if (['Pending', 'Preparing'].contains(status)) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _handleCancelOrder,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade400,
                                  Colors.red.shade700,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel_outlined, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Cancel Order',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Buyer Info (SELLER SPECIFIC) ──
              Text(t('buyer_information'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade100
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                        radius: 25,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.grey.shade100,
                        child: const Icon(Icons.person, color: Colors.grey)
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(buyer?['username'] ?? 'Unknown Buyer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(buyer?['email'] ?? 'No email available', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (buyer?['id'] != null && buyer?['id'] != Supabase.instance.client.auth.currentUser?.id)
                      IconButton(
                        onPressed: () {
                          if (buyer?['id'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  remoteUserId: buyer!['id'],
                                  remoteUserName: buyer['username'] ?? 'Unknown Buyer',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.lightBlue),
                      ),

                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Items ──
              Text(t('items_ordered'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade100
                  ),
                ),
                child: Column(
                  children: [
                    ...orderItems.map((item) {
                      final product = item['product'] as Map<String, dynamic>?;
                      final price = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0;
                      final quantity = int.tryParse(item['quantity']?.toString() ?? '0') ?? 1;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            (product?['image_url']?.toString() ?? '').split(',')[0],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 50,
                              height: 50,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white10
                                  : Colors.grey.shade100,
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                        ),
                        title: Text(product?['name'] ?? 'Unknown Item',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                        subtitle: Text('${t('qty')}: $quantity', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        trailing: Text('RM ${(price * quantity).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      );
                    }),
                    const Divider(indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t('total_amount'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            'RM ${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.lightBlue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Fulfillment Info ──
              Text(t('fulfillment_details'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade100
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPickup ? Icons.storefront : Icons.local_shipping,
                              color: Colors.lightBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t('services')} : $locationType', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(
                                  location?['title'] ?? 'Address details not provided',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          if (location != null)
                            IconButton(
                              icon: Icon(
                                _isMapExpanded ? Icons.map : Icons.map_outlined,
                                color: Colors.lightBlue,
                              ),
                              onPressed: () {
                                if (!_isMapExpanded) {
                                  // Only show loading if we actually have coordinates
                                  final hasCoords = location['latitude'] != null && location['longitude'] != null && (double.tryParse(location['latitude'].toString()) ?? 0) != 0.0;
                                  setState(() {
                                    _isMapExpanded = true;
                                    _isMapLoading = hasCoords;
                                  });

                                  if (hasCoords) {
                                    Future.delayed(const Duration(milliseconds: 800), () {
                                      if (mounted) setState(() => _isMapLoading = false);
                                    });
                                  }
                                } else {
                                  setState(() => _isMapExpanded = false);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _isMapExpanded
                          ? ( (location?['latitude'] != null &&
                          location?['longitude'] != null &&
                          (double.tryParse(location?['latitude'].toString() ?? '0') != 0.0))
                          ? (_isMapLoading
                          ? const MapSkeleton()
                          : Container(
                        height: 240,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white10
                                  : Colors.grey.shade100
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                double.tryParse(location!['latitude'].toString()) ?? 0.0,
                                double.tryParse(location['longitude'].toString()) ?? 0.0,
                              ),
                              zoom: 15,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('fulfillment_loc'),
                                position: LatLng(
                                  double.tryParse(location['latitude'].toString()) ?? 0.0,
                                  double.tryParse(location['longitude'].toString()) ?? 0.0,
                                ),
                                infoWindow: InfoWindow(title: location['title']),
                              ),
                            },
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            zoomGesturesEnabled: false,
                            scrollGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            mapType: MapType.normal,
                          ),
                        ),
                      )
                      )
                          : Container(
                        height: 240,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(color: Color(0xFF8E8E8E), shape: BoxShape.circle),
                              child: const Icon(Icons.priority_high, color: Colors.white, size: 30),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Oops! No address found!',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : const Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'This page didn\'t load Google Maps correctly because the address details are missing or invalid.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white54
                                        : const Color(0xFF777777),
                                    fontSize: 12,
                                    height: 1.4
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Shopee-Style Order Information ──
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade100
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(t('order_id'), fullOrderId,
                      trailing: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: fullOrderId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order ID copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white24
                                    : Colors.grey.shade300
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _buildInfoRow(t('paid_by'), paymentMethod),
                    const Divider(height: 1),
                    _buildInfoRow(t('receipt'), t('view_receipt'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ReceiptScreen(order: _order!)),
                        );
                      },
                      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ),

                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _isInfoExpanded
                            ? Column(
                          children: [
                            const Divider(height: 1),
                            _buildInfoRow(t('order_time'), formattedDate),
                            _buildInfoRow(t('payment_time'), paymentTime),
                            _buildInfoRow(t('ship_time'), shipTime),
                            _buildInfoRow(t('completed_time'), completedTime),
                          ],
                        )
                            : const SizedBox.shrink(),
                      ),
                    ),

                    InkWell(
                      onTap: () => setState(() => _isInfoExpanded = !_isInfoExpanded),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_isInfoExpanded ? t('view_less') : t('view_more'),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            Icon(_isInfoExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 18, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Status Timeline ──
              Text(t('order_journey'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),

              (() {
                final effectiveStatusForJourney = _getEffectiveStatus(status, isPickup);
                final currentFlow = isPickup ? pickupFlow : deliveryFlow;
                final currentIndex = currentFlow.indexOf(effectiveStatusForJourney);

                return Column(
                  children: [
                    _buildStatusStep('Order Placed', currentIndex >= 0, t('order_received_sub')),
                    _buildStatusStep('Preparing', currentIndex >= 1, t('preparing_sub')),
                    _buildStatusStep(
                        isPickup ? 'Ready for Pickup' : 'Out For Delivery',
                        currentIndex >= 2,
                        isPickup ? t('ready_for_pickup_sub') : t('out_for_delivery_sub')),
                    _buildStatusStep(
                        isPickup ? 'Picked Up' : 'Delivered',
                        currentIndex >= 3,
                        isPickup ? t('order_handover_complete') : t('package_delivered'),
                        isLast: true),
                  ],
                );
              })(),

              const SizedBox(height: 100), // Safe spacing
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStep(String title, bool isActive, String subtitle, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? Colors.green : (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey.shade300),
                    boxShadow: isActive ? [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)] : [],
                  ),
                  child: isActive ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isActive ? Colors.green.withValues(alpha: 0.5) : (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isActive ? null : Colors.grey,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: isActive ? Colors.grey.shade600 : Colors.grey.shade400,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}