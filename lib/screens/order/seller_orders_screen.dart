import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/translations.dart';
import 'seller_order_detail_screen.dart';

// Member 2: SellerOrdersScreen (Refined)
// Features: Shop-style Category Chips, Sequential Status Dropdown, and high-fidelity QR Scanner.
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];

  final List<String> _categories = [t('all'), t('pending'), t('delivered'), t('picked_up'), t('completed'), t('cancelled')];
  String _selectedCategory = t('all');

  @override
  void initState() {
    super.initState();
    _fetchSellerOrders();
  }

  Future<void> _fetchSellerOrders() async {
    if (currentUser == null) return;

    try {
      final response = await _supabase
          .from('orders')
          .select('*, buyer:buyer_id(username, email), location:location_id(*), order_items:order_item(*, product:product_id(*))')
          .eq('seller_id', currentUser!['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching seller orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    List<Map<String, dynamic>> filtered = _allOrders;

    if (_selectedCategory != 'All') {
      filtered = _allOrders.where((order) {
        final status = (order['status'] ?? 'Pending').toString().toLowerCase();

        if (_selectedCategory == 'Pending') {
          return !['delivered', 'picked up', 'completed', 'cancelled'].contains(status);
        }
        if (_selectedCategory == 'Delivered') {
          return status == 'delivered';
        }
        if (_selectedCategory == 'Picked Up') {
          return status == 'picked up';
        }
        if (_selectedCategory == 'Completed') {
          return status == 'completed';
        }
        if (_selectedCategory == 'Cancelled') {
          return status == 'cancelled';
        }
        return true;
      }).toList();
    }

    // Smart Sorting for "All": Active first, Completed/Cancelled at the absolute bottom
    // Smart sorting for "All" and "Pending" categories: Prioritize action-required orders
    if (_selectedCategory == t('all') || _selectedCategory == t('pending')) {
      final List<Map<String, dynamic>> sorted = List.from(filtered);
      sorted.sort((a, b) {
        int getPriority(String status) {
          status = status.toLowerCase();
          if (status == 'ready for pickup') return 0; // Absolute Top
          if (['pending', 'preparing', 'out for delivery'].contains(status)) return 1; // Active Middle
          if (['delivered', 'picked up'].contains(status)) return 2; // Bottom-ish
          if (['completed', 'cancelled'].contains(status)) return 3; // Absolute Bottom
          return 1; // Default
        }

        final int priorityA = getPriority((a['status'] ?? 'Pending').toString());
        final int priorityB = getPriority((b['status'] ?? 'Pending').toString());

        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB);
        }

        // Tie-breaker: Latest orders first
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      return sorted;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('seller_orders'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchSellerOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const OrderHistorySkeleton()
            : Column(
          children: [
            // ── Horizontal Category Chips (Shop Screen UI) ──
            Container(
              height: 60,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                      selectedColor: Colors.lightBlue.withValues(alpha: 0.2),
                      checkmarkColor: Colors.lightBlue,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.lightBlueAccent : Colors.lightBlue)
                            : (isDark ? Colors.white70 : Colors.grey.shade700),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(
                          color: isSelected
                              ? Colors.lightBlue
                              : (isDark ? Colors.white10 : Colors.grey.shade200)
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Orders List ──
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchSellerOrders,
                child: _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _filteredOrders.length,
                  itemBuilder: (context, index) {
                    return _OrderCard(
                      order: _filteredOrders[index],
                      onUpdate: _fetchSellerOrders,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '${t('no_orders_found')} (${_selectedCategory.toLowerCase()})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onUpdate;

  const _OrderCard({required this.order, required this.onUpdate});

  // Status Lifecycle for sequential locking
  static const List<String> deliveryFlow = ['Pending', 'Preparing', 'Out for Delivery', 'Delivered'];
  static const List<String> pickupFlow = ['Pending', 'Preparing', 'Ready for Pickup', 'Picked Up'];

  Color _statusColor(String status) {
    status = status.toLowerCase();
    switch (status) {
      case 'pending':
      case 'order placed': return Colors.blue;
      case 'preparing': return Colors.orange;
      case 'ready for pickup':
      case 'out for delivery': return Colors.lightBlue;
      case 'delivered':
      case 'picked up':
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] ?? 'Pending').toString();
    final statusLower = status.toLowerCase();
    final isFinalized = ['delivered', 'picked up', 'completed', 'cancelled'].contains(statusLower);

    final buyer = order['buyer'] as Map<String, dynamic>?;
    final buyerName = buyer?['username'] ?? 'Unknown Buyer';
    final location = order['location'] as Map<String, dynamic>?;
    final isPickup = location?['location_type'] == 'Pick Up';

    final orderItems = order['order_items'] as List<dynamic>? ?? [];
    final firstItem = orderItems.isNotEmpty ? orderItems[0] : null;
    final firstProduct = firstItem != null ? firstItem['product'] as Map<String, dynamic>? : null;
    final productName = firstProduct?['name'] ?? 'Multiple Items';
    final productImg = firstProduct?['image_url'];

    final createdAt = DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM, hh:mm a').format(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05)
        ),
      ),
      child: Column(
        children: [
          // ── Top Row: ID & Status Badge ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order['id'].toString().substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'completed' ? 'Completed' : status,
                    style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // ── Main Content: Image & Details ──
          ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                image: productImg != null ? DecorationImage(image: NetworkImage(productImg.toString().split(',')[0]), fit: BoxFit.cover) : null,
              ),
              child: productImg == null ? const Icon(Icons.shopping_bag, color: Colors.grey) : null,
            ),
            title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buyer: $buyerName • $formattedDate', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                        isPickup ? Icons.storefront : Icons.local_shipping,
                        size: 14,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey
                    ),
                    const SizedBox(width: 4),
                    Text(
                        isPickup ? t('self_pickup') : t('delivery'),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey
                        )
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (val) {
                if (val == 'details') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SellerOrderDetailScreen(orderId: order['id'].toString()),
                    ),
                  ).then((_) => onUpdate());
                } else if (val == 'cancel') {
                  _handleCancelOrder(context);
                }
              },
              enabled: !isFinalized,
              itemBuilder: (context) => [
                PopupMenuItem(value: 'details', child: Text(t('view_details'))),
                if (['pending', 'preparing'].contains(statusLower))
                  PopupMenuItem(value: 'cancel', child: const Text('Cancel Order', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),

          // ── Bottom Action Area ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // 1. Status Dropdown (Sequential)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : (isFinalized ? Colors.grey.shade100 : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _getEffectiveStatus(status, isPickup),
                      icon: Icon(Icons.keyboard_arrow_down, color: isFinalized ? Colors.grey.shade400 : Colors.grey),
                      onChanged: isFinalized ? null : (newVal) {
                        if (newVal != null && newVal != status) {
                          _updateStatus(context, newVal);
                        }
                      },
                      items: (isPickup ? pickupFlow : deliveryFlow).map((String s) {
                        final bool isEnabled = _isStatusEnabled(s, status, isPickup);
                        return DropdownMenuItem<String>(
                          value: s,
                          enabled: isEnabled,
                          child: Text(
                            s,
                            style: TextStyle(
                              color: isFinalized
                                  ? Colors.grey.shade400
                                  : (isEnabled
                                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)
                                  : Colors.grey.shade400),
                              fontWeight: s == status ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList()..add(
                        const DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                      ),
                    ),
                  ),
                ),

                // 2. Scan QR Code Primary Action (CTA)
                if (isPickup && status == 'Ready for Pickup') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () => _openScanner(context),
                      label: Text(t('scan_qr_verify'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isStatusEnabled(String target, String current, bool isPickup) {
    if (current == 'Cancelled') return true; // Unlock all if cancelled

    final flow = isPickup ? pickupFlow : deliveryFlow;
    final currentIndex = flow.indexOf(current == 'Order Placed' ? 'Pending' : current);
    final targetIndex = flow.indexOf(target);

    // If order is finished (Delivered/Picked Up), allow selecting back to anything
    if (currentIndex == flow.length - 1) return true;

    // Otherwise, sequential locking: Can only select current or the immediate NEXT status
    return targetIndex <= currentIndex + 1;
  }

  String _getEffectiveStatus(String status, bool isPickup) {
    // 1. Standardize Pending
    if (['Order Placed', 'Pending'].contains(status)) return 'Pending';

    // 2. Handle legacy or different statuses (The cause of the crash)
    if (status.toLowerCase() == 'completed') {
      return isPickup ? 'Picked Up' : 'Delivered';
    }

    // 3. Ensure the result is in the flow, otherwise fallback to Pending or Cancelled
    final flow = isPickup ? pickupFlow : deliveryFlow;
    if (flow.contains(status)) return status;
    if (status == 'Cancelled') return 'Cancelled';

    return 'Pending';
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      final supabase = Supabase.instance.client;

      // If reverting back from a finalized state, reset the 'claim' status
      if (['Delivered', 'Picked Up'].contains(order['status'])) {
        await supabase.from('order_verifications').update({'claim': false}).eq('order_id', order['id']);
      }

      final Map<String, dynamic> updates = {'status': newStatus};
      final now = DateTime.now().toIso8601String();

      if (['Out for Delivery', 'Ready for Pickup'].contains(newStatus)) {
        updates['shipped_at'] = now;
      } else if (['Delivered', 'Picked Up'].contains(newStatus)) {
        updates['completed_at'] = now;
      }

      await supabase.from('orders').update(updates).eq('id', order['id']);
      onUpdate();
      if (context.mounted) snackbar('${t('status_updated')}: $newStatus', Colors.green);
    } catch (e) {
      if (context.mounted) snackbar('Error: $e', Colors.red);
    }
  }

  Future<void> _handleCancelOrder(BuildContext context) async {
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
      final supabase = Supabase.instance.client;

      // 1. Update Order Status
      await supabase.from('orders').update({'status': 'Cancelled'}).eq('id', order['id']);

      // 2. Restore Inventory
      final orderItems = order['order_items'] as List<dynamic>? ?? [];
      for (var item in orderItems) {
        final product = item['product'] as Map<String, dynamic>?;
        if (product == null) continue;

        final int currentQty = product['quantity'] ?? 0;
        final int orderQty = item['quantity'] ?? 0;
        final int newQty = currentQty + orderQty;

        await supabase.from('product').update({
          'quantity': newQty,
          'stock_status': newQty > 0 ? 'In Stock' : 'Out of Stock',
        }).eq('id', product['id']);
      }

      onUpdate();
      if (context.mounted) snackbar(t('inventory_restored'), Colors.green);
    } catch (e) {
      if (context.mounted) snackbar('Error: $e', Colors.red);
    }
  }

  void _openScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScannerBottomSheet(
        orderId: order['id'],
        onSuccess: onUpdate,
      ),
    );
  }
}

class _ScannerBottomSheet extends StatefulWidget {
  final String orderId;
  final VoidCallback onSuccess;

  const _ScannerBottomSheet({required this.orderId, required this.onSuccess});

  @override
  State<_ScannerBottomSheet> createState() => _ScannerBottomSheetState();
}

class _ScannerBottomSheetState extends State<_ScannerBottomSheet> {
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (code.contains(widget.orderId)) {
        final supabase = Supabase.instance.client;

        await supabase
            .from('order_verifications')
            .update({'claim': true})
            .eq('order_id', widget.orderId);

        await supabase
            .from('orders')
            .update({
          'status': 'Picked Up',
          'completed_at': DateTime.now().toIso8601String(),
        })
            .eq('id', widget.orderId);

        if (mounted) {
          widget.onSuccess();
          Navigator.pop(context);
          snackbar(t('verification_successful'), Colors.green);
        }
      } else {
        setState(() => _isProcessing = false);
        snackbar(t('invalid_qr_order'), Colors.red);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      snackbar('Scan error: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameSize = MediaQuery.of(context).size.width * 0.7;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  if (barcode.rawValue != null) {
                    _handleScan(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: Colors.lightBlue,
                  borderRadius: 20,
                  borderLength: 40,
                  borderWidth: 10,
                  cutOutSize: frameSize,
                ),
              ),
            ),
          ),

          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(t('verify_pickup'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(t('scan_buyer_qr'), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              ],
            ),
          ),

          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(icon: Icons.flash_on, onPressed: () => _controller.toggleTorch()),
                const SizedBox(width: 40),
                _buildIconButton(icon: Icons.flip_camera_ios, onPressed: () => _controller.switchCamera()),
                const SizedBox(width: 40),
                _buildIconButton(icon: Icons.close, onPressed: () => Navigator.pop(context), color: Colors.redAccent),
              ],
            ),
          ),

          if (_isProcessing)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.lightBlue))),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 1.0,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  ui.Path getInnerPath(ui.Rect rect, {ui.TextDirection? textDirection}) => ui.Path();

  @override
  ui.Path getOuterPath(ui.Rect rect, {ui.TextDirection? textDirection}) => ui.Path()..addRect(rect);

  @override
  void paint(ui.Canvas canvas, ui.Rect rect, {ui.TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final topOffset = (height - cutOutSize) / 2;
    final leftOffset = (width - cutOutSize) / 2;
    final backgroundPaint = ui.Paint()..color = Colors.black54..style = ui.PaintingStyle.fill;
    final cutOutRect = ui.Rect.fromLTWH(leftOffset, topOffset, cutOutSize, cutOutSize);

    canvas.drawPath(
      ui.Path.combine(ui.PathOperation.difference, ui.Path()..addRect(rect), ui.Path()..addRRect(ui.RRect.fromRectAndRadius(cutOutRect, ui.Radius.circular(borderRadius)))),
      backgroundPaint,
    );

    final paint = ui.Paint()..color = borderColor..style = ui.PaintingStyle.stroke..strokeWidth = borderWidth;
    final path = ui.Path()
      ..moveTo(leftOffset, topOffset + borderLength)..lineTo(leftOffset, topOffset + borderRadius)
      ..arcToPoint(ui.Offset(leftOffset + borderRadius, topOffset), radius: ui.Radius.circular(borderRadius))..lineTo(leftOffset + borderLength, topOffset)
      ..moveTo(leftOffset + cutOutSize - borderLength, topOffset)..lineTo(leftOffset + cutOutSize - borderRadius, topOffset)
      ..arcToPoint(ui.Offset(leftOffset + cutOutSize, topOffset + borderRadius), radius: ui.Radius.circular(borderRadius))..lineTo(leftOffset + cutOutSize, topOffset + borderLength)
      ..moveTo(leftOffset + cutOutSize, topOffset + cutOutSize - borderLength)..lineTo(leftOffset + cutOutSize, topOffset + cutOutSize - borderRadius)
      ..arcToPoint(ui.Offset(leftOffset + cutOutSize - borderRadius, topOffset + cutOutSize), radius: ui.Radius.circular(borderRadius))..lineTo(leftOffset + cutOutSize - borderLength, topOffset + cutOutSize)
      ..moveTo(leftOffset + borderLength, topOffset + cutOutSize)..lineTo(leftOffset + borderRadius, topOffset + cutOutSize)
      ..arcToPoint(ui.Offset(leftOffset, topOffset + cutOutSize - borderRadius), radius: ui.Radius.circular(borderRadius))..lineTo(leftOffset, topOffset + cutOutSize - borderLength);

    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => QrScannerOverlayShape(borderColor: borderColor, borderWidth: borderWidth, borderRadius: borderRadius, borderLength: borderLength, cutOutSize: cutOutSize);
}