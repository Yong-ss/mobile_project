import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:nfc_manager/nfc_manager.dart';
import '../../utils/globals.dart';
import '../map/location_screen.dart';
import 'payment_details_screen.dart';
import '../order/to_pay_screen.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/translations.dart';

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
  bool _isProcessing = false;
  String _username = '';
  List<Map<String, dynamic>> _cartItems = [];

  final TextEditingController _deliveryAddressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();
  Map<String, dynamic>? _selectedLocationData;
  Map<String, dynamic>? _selectedPickupData;

  List<Map<String, dynamic>> _addressSuggestions = [];
  Timer? _debounce;
  bool _isSearchingAddress = false;

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
      if (!_addressFocusNode.hasFocus) {
        // Auto-select first suggestion if user didn't pick one
        _autoSelectFirstSuggestion();
      }
      setState(() {});
    });
  }

  void _autoSelectFirstSuggestion() {
    if (_addressSuggestions.isNotEmpty && _selectedLocationData == null) {
      final s = _addressSuggestions.first;
      // ALWAYS replace the text controller with the suggestion's title
      _deliveryAddressController.text = s['title'];

      if (s['isLocal']) {
        setState(() {
          _selectedLocationData = {
            'name': s['title'],
            'latitude': s['lat'],
            'longitude': s['lng'],
          };
          _addressSuggestions = [];
        });
      } else {
        // For search results, we must resolve to get coordinates
        _resolveAddress();
        setState(() => _addressSuggestions = []);
      }
    }
  }

  Future<void> _resolveAddress() async {
    final address = _deliveryAddressController.text.trim();
    if (address.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() {
          _selectedLocationData = {
            'name': address,
            'latitude': loc.latitude,
            'longitude': loc.longitude,
          };
          _addressSuggestions = []; // Close dropdown
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location resolved: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  void _onAddressChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final query = value.trim().toLowerCase();
      if (query.isEmpty) {
        setState(() => _addressSuggestions = []);
        return;
      }

      List<Map<String, dynamic>> suggestions = [];

      // 1. Geocoding search for dynamic addresses
      setState(() => _isSearchingAddress = true);
      try {
        List<Placemark> placemarks = await GeocodingPlatform.instance!.placemarkFromAddress(value);
        for (var p in placemarks) {
          final addr = "${p.name}, ${p.subLocality}, ${p.locality}, ${p.administrativeArea}".replaceAll("null, ", "").replaceAll(", null", "");
          suggestions.add({
            'title': addr,
            'subtitle': 'Search Result',
            'lat': null, // Will resolve on selection
            'lng': null,
            'isLocal': false,
          });
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
      }

      if (mounted) {
        setState(() {
          _addressSuggestions = suggestions;
          _isSearchingAddress = false;
        });
      }
    });
  }

  DateTime _getRandomTime() {
    final random = Random();
    final now = DateTime.now();
    // Range 8am (8) to 11pm (23)
    final hour = 8 + random.nextInt(15);
    final minute = random.nextInt(60);
    // Random day in the last 7 days for realism
    final dayOffset = random.nextInt(7);
    return DateTime(now.year, now.month, now.day - dayOffset, hour, minute);
  }

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    _addressFocusNode.dispose();
    _debounce?.cancel();
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
        appBar: AppBar(
          title: Text(t('checkout'), style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Order Summary ──
                Text(t('order_summary'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.03),
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
                        label: Text(t('delivery')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: !_isSelfPickup
                              ? Colors.lightBlue
                              : Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                          foregroundColor:
                          !_isSelfPickup ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
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
                        label: Text(t('self_pickup')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor:
                          _isSelfPickup ? Colors.lightBlue : Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                          foregroundColor:
                          _isSelfPickup ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
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
                  Text(t('delivery_address'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: _addressFocusNode.hasFocus ? const EdgeInsets.all(6) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: _addressFocusNode.hasFocus ? Theme.of(context).cardColor : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade100),
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
                      decoration: InputDecoration(
                        hintText: t('enter_address'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                        suffixIcon: _deliveryAddressController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                          onPressed: _resolveAddress,
                          tooltip: 'Verify Location',
                        )
                            : null,
                      ),
                      onChanged: _onAddressChanged,
                      onEditingComplete: () {
                        _autoSelectFirstSuggestion();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  if (_addressSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isSearchingAddress
                          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                          : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _addressSuggestions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final s = _addressSuggestions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                            title: Text(s['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text(s['subtitle'], style: const TextStyle(fontSize: 11)),
                            onTap: () async {
                              _deliveryAddressController.text = s['title'];
                              if (s['isLocal']) {
                                setState(() {
                                  _selectedLocationData = {
                                    'name': s['title'],
                                    'latitude': s['lat'],
                                    'longitude': s['lng'],
                                  };
                                  _addressSuggestions = [];
                                });
                              } else {
                                await _resolveAddress();
                                setState(() => _addressSuggestions = []);
                              }
                            },
                          );
                        },
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
                    label: Text(t('pick_from_map')),
                  ),
                ],

                // ── Self Pickup Section ──
                if (_isSelfPickup) ...[
                  Text(t('seller_pickup_point'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    color: Theme.of(context).cardColor,
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
                Text(t('payment_method'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200),
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
                          decoration: BoxDecoration(color: Colors.lightBlue.withValues(alpha: 0.1)),
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
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _paymentSubMethod == 'Stripe' ? Colors.lightBlue : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200)),
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
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _paymentSubMethod == 'NFC' ? Colors.lightBlue : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200)),
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
                              Expanded(child: Text(t('cash_on_delivery'), style: const TextStyle(fontSize: 16))),
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
                          decoration: BoxDecoration(color: Colors.lightBlue.withValues(alpha: 0.1)),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, color: Colors.grey, size: 20),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
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
                Text(t('payment_details'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${t('total_payment')}:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    onPressed: _isProcessing ? null : _handleCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isProcessing ? Colors.grey : Colors.lightBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(t('place_order'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              color: Theme.of(context).brightness == Brightness.dark ? Colors.lightBlue.withValues(alpha: 0.1) : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
              image: imageUrl != null
                  ? DecorationImage(
                image: NetworkImage(imageUrl.toString().split(',')[0]),
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
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout() async {
    if (_isProcessing) return;

    if (_cartItems.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    setState(() => _isProcessing = true);

    // 1. Fulfillment Validation First
    if (_isSelfPickup) {
      if (_selectedPickupData == null) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a pickup point on the map'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
    } else {
      final address = _deliveryAddressController.text.trim();
      if (address.isEmpty) {
        setState(() {
          _isProcessing = false;
          _selectedLocationData = null; // Clear any 'ghost' coordinates if text is empty
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a delivery address'), backgroundColor: Colors.orange),
        );
        return;
      }

      // Auto-resolve if not already done or if address changed
      if (_selectedLocationData == null || _selectedLocationData!['name'] != address) {
        await _resolveAddress();
      }
    }

    // 2. Payment Method Validation
    if (_paymentMethod.isEmpty) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a payment method'), backgroundColor: Colors.orange),
        );
      }
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
      // For COD, simulate success and record in payments table
      final transactionId = 'COD_${DateTime.now().millisecondsSinceEpoch}';

      try {
        await Supabase.instance.client.from('payments').insert({
          'user_id': currentUser!['id'],
          'payment_intent_id': transactionId,
          'amount': _totalAmount,
          'payment_method': 'Cash on Delivery',
          'status': 'Success',
        });

        await _placeOrder(transactionId);
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to initialize payment: $e')));
      }
    }
  }

  Future<void> _processNFCPayment() async {
    final transactionId = 'NFC_${DateTime.now().millisecondsSinceEpoch}';
    bool paymentFinished = false;

    // 1. Create PENDING record (like Stripe) so user can resume if they cancel
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await Supabase.instance.client.from('payments').insert({
        'user_id': currentUser!['id'],
        'payment_intent_id': transactionId,
        'amount': _totalAmount,
        'payment_method': 'NFC [ID: $transactionId]',
        'status': 'pending',
      });

      // Place order in AWAITING PAYMENT status and clean cart
      await _placeOrder(transactionId, status: 'Awaiting Payment', showSuccessPage: false);

      if (mounted) Navigator.pop(context); // Close loading
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to initialize NFC payment: $e')));
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ready to Scan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.headlineSmall?.color)),
              const SizedBox(height: 20),
              const SizedBox(
                height: 200,
                child: Center(child: AnimatedPulseIcon()),
              ),
              const SizedBox(height: 20),
              Text('Hold your phone near the NFC card or Tag.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  NfcManager.instance.stopSession();
                  paymentFinished = true;
                  if (mounted) Navigator.pop(context);
                  await _onNFcSuccess(transactionId);
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
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                    foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      NfcManager.instance.stopSession();
      // If user closed the sheet without success, redirect to To Pay
      if (!paymentFinished && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ToPayScreen()),
        );
      }
    });

    // Start NFC Session
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
      onDiscovered: (NfcTag tag) async {
        NfcManager.instance.stopSession();
        if (mounted) {
          paymentFinished = true;
          Navigator.pop(context); // Close sheet
          await _onNFcSuccess(transactionId);
        }
      },
    );
  }

  Future<void> _onNFcSuccess(String transactionId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Update Payment status to succeeded
      await Supabase.instance.client.from('payments')
          .update({'status': 'succeeded'})
          .eq('payment_intent_id', transactionId);

      // 2. Update Orders status to Pending & set payment_at
      await Supabase.instance.client.from('orders')
          .update({
        'status': 'Pending',
        'payment_at': DateTime.now().toIso8601String(),
      })
          .ilike('payment_method', '%$transactionId%');

      if (mounted) Navigator.pop(context); // close loading dialog

      // Navigate to Success screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailsScreen(
              amount: _totalAmount,
              transactionId: transactionId,
              userName: _username,
              paymentMethod: 'Credit/Debit Card (NFC)',
              date: DateTime.now(),
              merchantName: 'NFC Merchant',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to finalize payment: $e')));
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

      // Extract the payment intent ID from the client secret (e.g., pi_12345_secret_67890 -> pi_12345)
      final clientSecret = data['paymentIntent'] as String;
      final paymentIntentId = clientSecret.contains('_secret_')
          ? clientSecret.split('_secret_').first
          : clientSecret;

      // Create PENDING payment record right away in the payments table (which exists)
      await Supabase.instance.client.from('payments').insert({
        'user_id': currentUser!['id'],
        'payment_intent_id': paymentIntentId,
        'amount': _totalAmount,
        // Store both ID and SECRET in the method string so we can resume later from To Pay screen
        'payment_method': 'Stripe [ID: $paymentIntentId] [SECRET: $clientSecret]',
        'status': 'pending',
      });

      // Place order in AWAITING PAYMENT status
      // We store the ID in the payment_method string to link them without needing a new DB column in orders
      await _placeOrder(paymentIntentId, status: 'Awaiting Payment', showSuccessPage: false);

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['paymentIntent'],
          merchantDisplayName: 'Priscon Shop',
          returnURL: 'flutterstripe://redirect',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // If we reach here, it's successful. Update records.
      await Supabase.instance.client.from('payments').update({
        'status': 'succeeded',
      }).eq('payment_intent_id', paymentIntentId);

      await Supabase.instance.client.from('orders').update({
        'status': 'Pending',
        'payment_at': DateTime.now().toIso8601String(),
      }).ilike('payment_method', '%$paymentIntentId%');

      if (mounted) {
        // Find merchant name for display
        String merchantName = 'Priscon Merchant';
        if (_cartItems.isNotEmpty) {
          final sellerNode = _cartItems.first['product']?['seller'];
          merchantName = sellerNode?['shop_name'] ?? sellerNode?['username'] ?? 'Priscon Merchant';
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailsScreen(
              amount: _totalAmount,
              transactionId: paymentIntentId,
              userName: _username,
              paymentMethod: 'Credit/Debit Card (Stripe)',
              date: DateTime.now(),
              merchantName: merchantName,
            ),
          ),
        );
      }
    } on StripeException {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment hidden: You can finish this later in "To Pay"'),
              backgroundColor: Colors.orange,
            )
        );
        // Automatic navigation requested by user
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ToPayScreen()),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _placeOrder(String transactionId, {String status = 'Pending', bool showSuccessPage = true}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (mounted && status == 'Pending') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment Successful!'), backgroundColor: Colors.green, duration: Duration(seconds: 2))
        );
      }
      final supabase = Supabase.instance.client;
      final user = currentUser;
      if (user == null) throw Exception("User not logged in");

      final randomTime = _getRandomTime();

      // 1. Save and Link Location
      String? locationId;
      try {
        final locData = _isSelfPickup ? {
          'user_id': user['id'],
          'title': _selectedPickupData!['name'],
          'latitude': _selectedPickupData!['latLng']?.latitude ?? 0.0,
          'longitude': _selectedPickupData!['latLng']?.longitude ?? 0.0,
          'location_type': 'Pick Up',
          'created_at': randomTime.toIso8601String(),
        } : {
          'user_id': user['id'],
          'title': _deliveryAddressController.text.trim(),
          'latitude': _selectedLocationData?['latitude'] ?? 0.0,
          'longitude': _selectedLocationData?['longitude'] ?? 0.0,
          'location_type': 'Delivery',
          'created_at': randomTime.toIso8601String(),
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
          'status': status,
          'location_id': locationId,
          'payment_method': '$_paymentMethod${_paymentMethod != 'Cash on Delivery' ? ' ($_paymentSubMethod)' : ''} [ID: $transactionId]',
          'payment_at': status == 'Pending' ? randomTime.toIso8601String() : null,
          'created_at': randomTime.toIso8601String(),
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

          // ── Update Inventory Stock ──
          try {
            final int currentStock = pOption['quantity'] ?? 0;
            final int purchasedQty = item['quantity'] ?? 0;
            final int remainingStock = (currentStock - purchasedQty).clamp(0, 999999);

            await supabase.from('product').update({
              'quantity': remainingStock,
              'stock_status': remainingStock > 0 ? 'In Stock' : 'Out of Stock',
            }).eq('id', pOption['id']);
          } catch (e) {
            debugPrint('Inventory update failed (ignoring if column missing): $e');
          }

          await supabase.from('cart_item').delete().eq('id', item['id']);
        }
      }

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (mounted && showSuccessPage) {
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