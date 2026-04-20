import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../shop/seller_page_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/qr_service.dart';
import 'package:flutter/services.dart';
import 'receipt_screen.dart';
import '../../utils/translations.dart';
import '../chat/chat_screen.dart';

// Buyer's order detail view — Member 3
// Shows full order info and status.
// QR scan button only appears when order status is "Ready for Pickup".
class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _order;
  bool _isMapExpanded = false;
  Map<String, dynamic>? _verification;
  bool _isGeneratingQr = false;
  String? _qrErrorMessage;
  String _qrProgressMessage = 'Preparing...';
  int _qrRetryCount = 0; // Prevent infinite loops
  void Function(void Function())? _setModalState; // Track modal's state function
  bool _isInfoExpanded = false; // For Shopee-style order info toggle
  bool _isMapLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('orders')
          .select('*, location:location_id(*), seller:seller_id(*), order_items:order_item(*, product:product_id(*))')
          .eq('id', widget.orderId)
          .single();

      if (mounted) {
        setState(() {
          _order = response;
          _isLoading = false;
        });
        _fetchVerificationInfo();
      }
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchVerificationInfo() async {
    final info = await QrService.getVerificationStatus(widget.orderId);
    if (mounted) {
      setState(() {
        _verification = info;
      });
      _setModalState?.call(() {}); // Sync modal UI

      // Automatic Trigger: Generate if status is Ready for Pickup and doesn't exist
      // Don't auto-trigger if we already have an error message (prevent loop)
      final String status = _order?['status'] ?? 'Pending';
      if (status == 'Ready for Pickup' &&
          _verification?['qr_url'] == null &&
          _qrErrorMessage == null) {
        _ensureQrGenerated();
      }
    }
  }

  Future<void> _ensureQrGenerated({bool force = false}) async {
    if (_isGeneratingQr) return;
    setState(() {
      _isGeneratingQr = true;
      _qrErrorMessage = null;
      _qrProgressMessage = 'Initializing...';
    });

    final qrUrl = await QrService.generateAndUploadQr(
      widget.orderId,
      forceRecreate: force,
      onProgress: (p) {
        if (mounted) {
          setState(() => _qrProgressMessage = p);
          _setModalState?.call(() {}); // Refresh modal if open
        }
      },
    );

    if (mounted) {
      if (qrUrl != null) {
        // Success
        _qrRetryCount = 0;
      }
      setState(() {
        _isGeneratingQr = false;
        if (qrUrl == null) {
          _qrErrorMessage = 'Failed to generate QR. Please check your connection or permissions.';
        }
      });
      _setModalState?.call(() {}); // Final refresh
      // Refresh verification info
      _fetchVerificationInfo();
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
    final bool isReadyForPickup = status == 'Ready for Pickup';

    final seller = _order!['seller'] as Map<String, dynamic>?;
    final String shopName = seller?['shop_name'] ?? seller?['username'] ?? 'Unknown Shop';
    final String shopPic = seller?['shop_pic'] ?? '';

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
        title: Text(t('order_details'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Order Summary Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.0)),
                              const SizedBox(height: 4),
                              Text('${t('placed_on')} $formattedDate',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Seller Info ──
              Text(t('seller_information'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  if (seller?['id'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SellerPageScreen(sellerId: seller!['id']),
                      ),
                    );
                  }
                },
                child: Container(
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
                        backgroundImage: shopPic.isNotEmpty ? NetworkImage(shopPic) : null,
                        child: shopPic.isEmpty ? const Icon(Icons.store, color: Colors.grey) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(t('official_seller'), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (seller?['id'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  remoteUserId: seller!['id'],
                                  remoteUserName: shopName,
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
                      final quantity = item['quantity'] ?? 0;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product?['image_url'] ?? '',
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
                                  final hasCoords = location['latitude'] != null && location['longitude'] != null;
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
              _buildStatusStep('Order Placed', true, t('order_received_sub')),
              _buildStatusStep('Preparing', status != 'Order Placed', t('preparing_sub')),
              _buildStatusStep(
                  isPickup ? 'Ready for Pickup' : 'Out For Delivery',
                  ['Ready for Pickup', 'Out for Delivery', 'Delivered', 'Picked Up', 'Completed'].contains(status),
                  isPickup ? t('ready_for_pickup_sub') : t('out_for_delivery_sub')),
              _buildStatusStep(
                  isPickup ? 'Picked Up' : 'Delivered',
                  ['Delivered', 'Picked Up', 'Completed'].contains(status),
                  isPickup ? t('order_handover_complete') : t('package_delivered'),
                  isLast: true),

              const SizedBox(height: 32),

              // ── Actions: Order Received (Only after Seller marks as Delivered) ──
              if (!isPickup && status == 'Delivered')
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _markOrderCompleted(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        t('order_received'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),

              // ── Actions: Pickup Verification ──
              if (isPickup && status == 'Ready for Pickup')
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showPickupBottomSheet(context, widget.orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        t('pickup_verification'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPickupBottomSheet(BuildContext context, String orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          _setModalState = setModalState; // Capture the modal's state sync function
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 24),
                    Text(t('pickup_verification'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 8),
                    Text('Order ID: $orderId', style: TextStyle(color: Colors.grey.shade500)),
                    const SizedBox(height: 32),
                    // ── Dynamic QR Area ──
                    Container(
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white10
                                : Colors.grey.shade100
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 8)
                          ),
                        ],
                      ),
                      child: _verification?['claim'] == true
                          ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
                          SizedBox(height: 16),
                          Text('ALREADY CLAIMED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                          SizedBox(height: 4),
                          Text('This order has been picked up.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      )
                          : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isGeneratingQr)
                            SizedBox(
                              height: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(strokeWidth: 3),
                                  const SizedBox(height: 20),
                                  Text(_qrProgressMessage, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            )
                          else if (_verification?['qr_url'] == null)
                            SizedBox(
                              height: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    _qrErrorMessage ?? 'QR not available',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red, fontSize: 13),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await _ensureQrGenerated();
                                      setModalState(() {});
                                    },
                                    child: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            )
                          else
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                _verification!['qr_url'],
                                width: 220,
                                height: 220,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    width: 220,
                                    height: 220,
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  // Auto-fix: if the image fails to load, force recreate it once
                                  if (_qrRetryCount < 1 && !_isGeneratingQr) {
                                    _qrRetryCount++;
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _ensureQrGenerated(force: true);
                                    });
                                    return const SizedBox(
                                      width: 220,
                                      height: 220,
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  return const Column(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                                      SizedBox(height: 8),
                                      Text('Failed to load QR image',
                                          style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ],
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text('Instructions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildInstructionStep('1', 'Show this verification to the seller at the store.'),
                    _buildInstructionStep('2', 'The seller will scan your code to confirm your identity.'),
                    _buildInstructionStep('3', 'Once scanned, your order will be marked as Picked Up.'),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _setModalState = null; // Clean up when sheet is dismissed
    });
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : Colors.grey.shade600,
                  height: 1.4
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markOrderCompleted() async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('orders')
          .update({
        'status': 'Completed',
        'completed_at': DateTime.now().toIso8601String(),
      })
          .eq('id', widget.orderId);

      if (mounted) {
        // Refresh the page
        _fetchOrderDetails();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as Completed! Thank you!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking order as completed: $e');
    }
  }

  Color _statusColor(String status) {
    status = status.toLowerCase();
    switch (status) {
      case 'order placed':
      case 'pending':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'ready for pickup':
      case 'out for delivery':
        return Colors.lightBlue;
      case 'delivered':
      case 'picked up':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusStep(String label, bool done, String description, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? Colors.green : Colors.grey.shade300,
                size: 24,
              ),
              // Line between steps
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: done ? Colors.green : Colors.grey.shade200,
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: done
                        ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
                        : Colors.grey,
                    fontWeight: done ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: done
                        ? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade600)
                        : Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Colors.grey.shade600,
                      fontSize: 14
                  )
              ),
            ),
            Expanded(
              flex: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Skeleton for Order Details Screen
class OrderDetailsSkeletonUI extends StatelessWidget {
  const OrderDetailsSkeletonUI({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BaseSkeleton(width: double.infinity, height: 100, borderRadius: 20),
            const SizedBox(height: 24),
            const BaseSkeleton(width: 150, height: 20),
            const SizedBox(height: 12),
            const BaseSkeleton(width: double.infinity, height: 80, borderRadius: 20),
            const SizedBox(height: 24),
            const BaseSkeleton(width: 120, height: 20),
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
              child: Column(
                children: [
                  Row(
                    children: [
                      const BaseSkeleton(width: 50, height: 50, borderRadius: 8),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BaseSkeleton(width: 120, height: 16),
                            SizedBox(height: 8),
                            BaseSkeleton(width: 40, height: 12),
                          ],
                        ),
                      ),
                      const BaseSkeleton(width: 60, height: 16),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BaseSkeleton(width: 100, height: 20),
                      BaseSkeleton(width: 80, height: 24),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const BaseSkeleton(width: 140, height: 20),
            const SizedBox(height: 12),
            const BaseSkeleton(width: double.infinity, height: 80, borderRadius: 20),
            const SizedBox(height: 24),
            const BaseSkeleton(width: 120, height: 20),
            const SizedBox(height: 16),
            ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const BaseSkeleton(width: 24, height: 24, borderRadius: 12),
                      const SizedBox(height: 4),
                      const BaseSkeleton(width: 2, height: 30),
                    ],
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseSkeleton(width: 150, height: 16),
                      SizedBox(height: 6),
                      BaseSkeleton(width: 200, height: 12),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}