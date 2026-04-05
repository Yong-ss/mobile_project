import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:nfc_manager/nfc_manager.dart';
import '../../utils/globals.dart';
import '../map/location_screen.dart';
import 'payment_details_screen.dart';
import '../../widgets/shimmer_skeletons.dart';

// Member 3: CheckoutScreen
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isSelfPickup = false;
  String _paymentMethod = '';
  String _paymentSubMethod = '';

  bool _isLoading = true;
  String _username = '';
  List<Map<String, dynamic>> _cartItems = [];

  final TextEditingController _deliveryAddressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  Map<String, dynamic>? _selectedLocationData;
  Map<String, dynamic>? _selectedPickupData;

  final List<Map<String, dynamic>> _pickupStores = [
    {
      'id': 'klcc',
      'name': 'KLCC Branch',
      'street': 'Petronas Twin Towers, Kuala Lumpur',
      'hours': 'Mon–Sun  10:00 AM – 10:00 PM',
      'latLng': const LatLng(3.1579, 101.7116),
    },
    {
      'id': 'putrajaya',
      'name': 'Putrajaya Branch',
      'street': 'Putra Mosque, Persiaran Persekutuan, Putrajaya',
      'hours': 'Mon–Sat  9:00 AM – 8:00 PM',
      'latLng': const LatLng(2.9360, 101.6911),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchCheckoutData();
    _addressFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchCheckoutData() async {
    final supabase = Supabase.instance.client;
    final user = currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch Username
      final userResponse = await supabase
          .from('user')
          .select('username')
          .eq('id', user['id'])
          .maybeSingle();

      if (userResponse != null && userResponse['username'] != null) {
        _username = userResponse['username'];
      } else {
        _username = "Customer";
      }

      // Fetch Cart Items
      final cartResponse = await supabase
          .from('cart_item')
          .select('*, product:product_id(*, seller:seller_id(username, shop_name))')
          .eq('user_id', user['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _cartItems = List<Map<String, dynamic>>.from(cartResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching checkout data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double get _totalAmount {
    return _cartItems.fold(0, (sum, item) {
      final product = item['product'];
      final price = double.tryParse(product['price'].toString()) ?? 0.0;
      return sum + (price * (item['quantity'] as int));
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: _isLoading
            ? const CheckoutSkeleton()
            : SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──
                if (_username.isNotEmpty) ...[
                  Text(
                    'Order for $_username',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Order Summary ──
                const Text('Order Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                  ),
                  child: Column(
                    children: [
                      if (_cartItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No items in cart.', style: TextStyle(color: Colors.grey)),
                        ),
                      for (int i = 0; i < _cartItems.length; i++) ...[
                        _buildCartItem(_cartItems[i]),
                        if (i < _cartItems.length - 1)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Fulfillment Toggle ──
                const Text('Fulfillment Method',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isSelfPickup = false),
                        icon: const Icon(Icons.local_shipping),
                        label: const Text('Delivery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: !_isSelfPickup
                              ? Colors.lightBlue
                              : Colors.grey.shade200,
                          foregroundColor:
                          !_isSelfPickup ? Colors.white : Colors.black,
                          elevation: !_isSelfPickup ? 2 : 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isSelfPickup = true),
                        icon: const Icon(Icons.storefront),
                        label: const Text('Self Pickup'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor:
                          _isSelfPickup ? Colors.lightBlue : Colors.grey.shade200,
                          foregroundColor:
                          _isSelfPickup ? Colors.white : Colors.black,
                          elevation: _isSelfPickup ? 2 : 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Delivery Section ──
                if (!_isSelfPickup) ...[
                  const Text('Delivery Address',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: _addressFocusNode.hasFocus ? const EdgeInsets.all(6) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: _addressFocusNode.hasFocus ? Colors.white : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _addressFocusNode.hasFocus ? Colors.lightBlue : Colors.transparent,
                        width: _addressFocusNode.hasFocus ? 2 : 1,
                      ),
                      boxShadow: _addressFocusNode.hasFocus
                          ? [
                        BoxShadow(
                          color: Colors.lightBlue.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 4,
                          offset: const Offset(0, 4),
                        )
                      ]
                          : [],
                    ),
                    child: TextField(
                      controller: _deliveryAddressController,
                      focusNode: _addressFocusNode,
                      maxLines: _addressFocusNode.hasFocus ? 3 : 2,
                      decoration: const InputDecoration(
                        hintText: 'Enter your delivery address...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final pickedLocation = await Navigator.push<Map<String, dynamic>?>(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LocationScreen()),
                      );
                      if (pickedLocation != null) {
                        setState(() {
                          _selectedLocationData = pickedLocation;
                          _deliveryAddressController.text = pickedLocation['name'] ?? 'Picked Location';
                          // Trigger focus for animation as requested
                          _addressFocusNode.requestFocus();
                        });
                      }
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Pick location on map'),
                  ),
                ],

                // ── Self Pickup Section ──
                if (_isSelfPickup) ...[
                  const Text('Seller Pickup Point',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                    child: Column(
                      children: [
                        if (_selectedPickupData != null) ...[
                          ListTile(
                            leading: const Icon(Icons.store, color: Colors.lightBlue),
                            title: Text(_selectedPickupData!['name'] ?? 'Pickup Point'),
                            subtitle: Text(_selectedPickupData!['street'] ?? 'No address'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.access_time),
                            title: const Text('Pickup Hours'),
                            subtitle: Text(_selectedPickupData!['hours'] ?? 'Mon–Fri  10:00 AM – 6:00 PM'),
                          ),
                          const Divider(height: 1),
                        ],
                        ListTile(
                          leading: const Icon(Icons.map_outlined),
                          title: const Text('View on Map'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final picked = await Navigator.push<Map<String, dynamic>?>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LocationScreen(
                                  stores: _pickupStores,
                                  initialLat: _selectedPickupData?['latLng']?.latitude,
                                  initialLng: _selectedPickupData?['latLng']?.longitude,
                                ),
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                // Find full store details from our list
                                final fullDetail = _pickupStores.firstWhere(
                                        (s) => s['name'] == picked['name'],
                                    orElse: () => picked);
                                _selectedPickupData = fullDetail;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Payment Method ──
                const Text('Payment Method',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // CREDIT / DEBIT CATEGORY
                      InkWell(
                        onTap: () {
                          setState(() {
                            _paymentMethod = 'Credit/Debit Card';
                            if (_paymentSubMethod != 'Stripe' && _paymentSubMethod != 'NFC') {
                              _paymentSubMethod = 'Stripe';
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(_paymentMethod == 'Credit/Debit Card' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _paymentMethod == 'Credit/Debit Card' ? Colors.lightBlue : Colors.grey),
                              const SizedBox(width: 16),
                              const Expanded(child: Text('Credit/Debit Card', style: TextStyle(fontSize: 16))),
                              const Icon(Icons.credit_card, color: Colors.blueGrey),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _paymentMethod == 'Credit/Debit Card' ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(color: Colors.blue.shade50.withValues(alpha: 0.3)),
                          child: Column(
                            children: [
                              // Stripe
                              InkWell(
                                onTap: () => setState(() => _paymentSubMethod = 'Stripe'),
                                child: Row(
                                  children: [
                                    const Icon(Icons.subdirectory_arrow_right, color: Colors.grey, size: 20),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _paymentSubMethod == 'Stripe' ? Colors.lightBlue : Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Stripe_Logo%2C_revised_2016.svg/512px-Stripe_Logo%2C_revised_2016.svg.png', height: 20, errorBuilder: (context, error, stackTrace) => const Text('Stripe', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
                                            const Spacer(),
                                            if (_paymentSubMethod == 'Stripe') const Icon(Icons.check_circle, color: Colors.lightBlue, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // NFC
                              InkWell(
                                onTap: () => setState(() => _paymentSubMethod = 'NFC'),
                                child: Row(
                                  children: [
                                    const Icon(Icons.subdirectory_arrow_right, color: Colors.grey, size: 20),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _paymentSubMethod == 'NFC' ? Colors.lightBlue : Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text('NFC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.contactless, color: Colors.blueAccent),
                                            const Spacer(),
                                            if (_paymentSubMethod == 'NFC') const Icon(Icons.check_circle, color: Colors.lightBlue, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ) : const SizedBox.shrink(),
                      ),
                      const Divider(height: 1),

                      // ONLINE BANKING CATEGORY
                      InkWell(
                        onTap: () {
                          setState(() {
                            _paymentMethod = 'Online Banking';
                            _paymentSubMethod = 'FPX';
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(_paymentMethod == 'Online Banking' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _paymentMethod == 'Online Banking' ? Colors.lightBlue : Colors.grey),
                              const SizedBox(width: 16),
                              const Expanded(child: Text('Online Banking', style: TextStyle(fontSize: 16))),
                              const Icon(Icons.account_balance, color: Colors.blueGrey),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _paymentMethod == 'Online Banking' ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(color: Colors.blue.shade50.withValues(alpha: 0.3)),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, color: Colors.grey, size: 20),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.lightBlue),
                                  ),
                                  child: Row(
                                    children: [
                                      Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/FPX_logo.svg/512px-FPX_logo.svg.png', height: 16, errorBuilder: (context, error, stackTrace) => const Text('FPX', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
                                      const Spacer(),
                                      const Icon(Icons.check_circle, color: Colors.lightBlue, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ) : const SizedBox.shrink(),
                      ),
                      const Divider(height: 1),

                      // CASH ON DELIVERY CATEGORY
                      InkWell(
                        onTap: () {
                          setState(() {
                            _paymentMethod = 'Cash on Delivery';
                            _paymentSubMethod = 'Cash';
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(_paymentMethod == 'Cash on Delivery' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _paymentMethod == 'Cash on Delivery' ? Colors.lightBlue : Colors.grey),
                              const SizedBox(width: 16),
                              const Expanded(child: Text('Cash on Delivery', style: TextStyle(fontSize: 16))),
                              const Icon(Icons.payments, color: Colors.blueGrey),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _paymentMethod == 'Cash on Delivery' ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(color: Colors.blue.shade50.withValues(alpha: 0.3)),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, color: Colors.grey, size: 20),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.lightBlue),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.money, color: Colors.green),
                                      const Spacer(),
                                      const Icon(Icons.check_circle, color: Colors.lightBlue, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ) : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Payment Details ──
                const Text('Payment Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Payment:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('RM ${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.lightBlue)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Place Order ──
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _handleCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Place Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final product = item['product'] as Map<String, dynamic>? ?? {};
    final name = product['name'] ?? 'Unknown Item';
    final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    final qty = item['quantity'] as int? ?? 1;
    final category = product['category'] ?? 'item';
    final imageUrl = product['image_url'];

    // Formatting category specifically based on reference image
    // "1 x set" or "1 x jar" (using category or fallback)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Reference Image Container: Light blue rounded square
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
              image: imageUrl != null
                  ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: imageUrl == null
                ? Icon(Icons.shopping_bag, color: Colors.blue.shade300)
                : null,
          ),
          const SizedBox(width: 16),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$qty × ${category.toLowerCase()}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          ),
          // Price
          Text(
            'RM ${(price * qty).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    // 1. Fulfillment Validation First
    if (_isSelfPickup) {
      if (_selectedPickupData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a pickup point on the map'), backgroundColor: Colors.orange),
        );
        return;
      }
    } else {
      final address = _deliveryAddressController.text.trim();
      if (address.isEmpty) {
        setState(() {
          _selectedLocationData = null; // Clear any 'ghost' coordinates if text is empty
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a delivery address'), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    // 2. Payment Method Validation
    if (_paymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 3. Process Payment or Place Order
    if (_paymentMethod == 'Credit/Debit Card') {
      if (_paymentSubMethod == 'Stripe') {
        await _processStripePayment();
      } else {
        await _processNFCPayment();
      }
    } else {
      // For COD and Online Banking, simulate success and record in payments table
      final isBanking = _paymentMethod == 'Online Banking';
      final transactionId = '${isBanking ? 'FPX' : 'COD'}_${DateTime.now().millisecondsSinceEpoch}';

      try {
        await Supabase.instance.client.from('payments').insert({
          'user_id': currentUser!['id'],
          'payment_intent_id': transactionId,
          'amount': _totalAmount,
          'payment_method': isBanking ? 'Online Banking' : 'Cash on Delivery',
          'status': 'succeeded',
        });

        await _placeOrder(transactionId);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to initialize payment: $e')));
      }
    }
  }

  Future<void> _processNFCPayment() async {
    try {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(left: 24, right: 24, top: 32, bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ready to Scan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 40),
              const AnimatedPulseIcon(),
              const SizedBox(height: 40),
              const Text('Hold your phone near the NFC card or Tag.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  NfcManager.instance.stopSession();
                  if (mounted) Navigator.pop(context);
                  await _onNFcSuccess();
                },
                child: const Text('Simulate Success (For Emulator)', style: TextStyle(color: Colors.lightBlue)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    NfcManager.instance.stopSession();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ).then((_) {
        NfcManager.instance.stopSession();
      });

      NfcManager.instance.startSession(
          pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
          onDiscovered: (NfcTag tag) async {
            NfcManager.instance.stopSession();
            if (mounted) {
              Navigator.pop(context); // Close dialog
              await _onNFcSuccess();
            }
          });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('NFC Error: $e')));
    }
  }

  Future<void> _onNFcSuccess() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final nfcId = 'nfc_${DateTime.now().millisecondsSinceEpoch}';
      // Insert payment record into Supabase
      await Supabase.instance.client.from('payments').insert({
        'user_id': currentUser!['id'],
        'payment_intent_id': nfcId,
        'amount': _totalAmount,
        'payment_method': 'NFC Card',
        'status': 'succeeded',
      });

      if (mounted) Navigator.pop(context); // close loading dialog
      await _placeOrder(nfcId);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save payment: $e')));
    }
  }
  Future<void> _processStripePayment() async {
    try {
      final amountInCents = (_totalAmount * 100).toInt();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await Supabase.instance.client.functions.invoke(
        'stripe-api',
        body: {
          'amount': amountInCents,
          'user_id': currentUser!['id'], // Pass to Edge Function
        },
      );

      if (mounted) Navigator.pop(context); // close loading

      final data = response.data;
      if (data == null || data['paymentIntent'] == null) {
        throw Exception("Failed to get payment intent from server");
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['paymentIntent'],
          merchantDisplayName: 'Priscon Shop',
          returnURL: 'flutterstripe://redirect',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Extract the payment intent ID from the client secret (e.g., pi_12345_secret_67890 -> pi_12345)
      final clientSecret = data['paymentIntent'] as String;
      final paymentIntentId = clientSecret.contains('_secret_')
          ? clientSecret.split('_secret_').first
          : clientSecret;

      // Update payment record in Supabase
      await Supabase.instance.client.from('payments').update({
        'status': 'succeeded',
      }).eq('payment_intent_id', paymentIntentId);

      // Payment successful, now process the order to the database
      await _placeOrder(paymentIntentId);
    } on StripeException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Error: ${e.error.localizedMessage}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
  Future<void> _placeOrder(String transactionId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment Successful!'), backgroundColor: Colors.green, duration: const Duration(seconds: 2))
        );
      }
      final supabase = Supabase.instance.client;
      final user = currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. Save and Link Location
      String? locationId;
      try {
        final locData = _isSelfPickup ? {
          'user_id': user['id'],
          'title': _selectedPickupData!['name'],
          'latitude': _selectedPickupData!['latLng']?.latitude ?? 0.0,
          'longitude': _selectedPickupData!['latLng']?.longitude ?? 0.0,
          'location_type': 'Pick Up',
        } : {
          'user_id': user['id'],
          'title': _deliveryAddressController.text.trim(),
          'latitude': _selectedLocationData?['latitude'] ?? 0.0,
          'longitude': _selectedLocationData?['longitude'] ?? 0.0,
          'location_type': 'Delivery',
        };

        final locResponse = await supabase.from('user_locations').insert(locData).select('id').single();
        locationId = locResponse['id'];
        debugPrint('SUCCESS: Location saved and linked: $locationId');
      } catch (e) {
        debugPrint('CRITICAL ERROR persisting location: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('History Error: $e'), backgroundColor: Colors.red.shade400, duration: const Duration(seconds: 2))
          );
        }
        // We continue with order placement even if location history save fails
      }

      Map<String, List<Map<String, dynamic>>> itemsBySeller = {};
      for (var item in _cartItems) {
        final product = item['product'] as Map<String, dynamic>;
        final sellerId = product['seller_id']?.toString() ?? '';
        if (!itemsBySeller.containsKey(sellerId)) {
          itemsBySeller[sellerId] = [];
        }
        itemsBySeller[sellerId]!.add(item);
      }

      for (var sellerId in itemsBySeller.keys) {
        final sellerItems = itemsBySeller[sellerId]!;
        final double sellerTotal = sellerItems.fold(0.0, (sum, item) {
          final pOption = item['product'];
          final price = double.tryParse(pOption['price'].toString()) ?? 0.0;
          return sum + (price * (item['quantity'] as int));
        });

        // Use the linked locationId here
        final orderResponse = await supabase.from('orders').insert({
          'buyer_id': user['id'],
          'seller_id': sellerId.isNotEmpty ? sellerId : null,
          'total_amount': sellerTotal,
          'status': 'Pending',
          'location_id': locationId,
        }).select().single();

        final orderId = orderResponse['id'];

        for (var item in sellerItems) {
          final pOption = item['product'];
          final price = double.tryParse(pOption['price'].toString()) ?? 0.0;
          await supabase.from('order_item').insert({
            'order_id': orderId,
            'product_id': pOption['id'],
            'seller_id': sellerId.isNotEmpty ? sellerId : null,
            'quantity': item['quantity'],
            'unit_price': price,
          });

          await supabase.from('cart_item').delete().eq('id', item['id']);
        }
      }

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (mounted) {
        String merchantName = 'Unknown Merchant';
        if (itemsBySeller.length > 1) {
          merchantName = 'Multiple Merchants';
        } else if (itemsBySeller.isNotEmpty) {
          final firstItem = itemsBySeller.values.first.first;
          final sellerNode = firstItem['product']?['seller'];
          if (sellerNode != null) {
            merchantName = sellerNode['shop_name'] ?? sellerNode['username'] ?? 'Unknown Merchant';
          }
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailsScreen(
              amount: _totalAmount,
              transactionId: transactionId,
              userName: _username,
              paymentMethod: '$_paymentMethod${_paymentMethod != 'Cash on Delivery' ? ' ($_paymentSubMethod)' : ''}',
              date: DateTime.now(),
              merchantName: merchantName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
    }
  }
}

// Custom Widget for the Wave/Pulse Animation
class AnimatedPulseIcon extends StatefulWidget {
  const AnimatedPulseIcon({super.key});

  @override
  State<AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<AnimatedPulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRing(double value) {
    return Opacity(
      opacity: (1.0 - value).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 1.0 + (value * 1.5),
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.lightBlue, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 180, // Extra space for the expanding rings
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildRing(_controller.value),
              _buildRing((_controller.value + 0.5) % 1.0),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.lightBlue, width: 2),
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Colors.lightBlue,
                  size: 45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
