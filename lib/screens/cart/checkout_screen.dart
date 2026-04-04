import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import '../order/order_history_screen.dart';
import '../map/location_screen.dart';

// Member 3: CheckoutScreen
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isSelfPickup = false;
  String _paymentMethod = 'Credit/Debit Card';

  bool _isLoading = true;
  String _username = '';
  List<Map<String, dynamic>> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _fetchCheckoutData();
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
          .select('*, product:product_id(*)')
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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

            // Custom UI replacing standard ListTiles
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
                  // Total Row
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('RM ${_totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.lightBlue)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                  RadioListTile<String>(
                    title: const Text('Credit/Debit Card'),
                    secondary: const Icon(Icons.credit_card, color: Colors.blueGrey),
                    value: 'Credit/Debit Card',
                    groupValue: _paymentMethod,
                    onChanged: (val) => setState(() => _paymentMethod = val!),
                    activeColor: Colors.lightBlue,
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('Online Banking'),
                    secondary: const Icon(Icons.account_balance, color: Colors.blueGrey),
                    value: 'Online Banking',
                    groupValue: _paymentMethod,
                    onChanged: (val) => setState(() => _paymentMethod = val!),
                    activeColor: Colors.lightBlue,
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('Cash on Delivery'),
                    secondary: const Icon(Icons.money, color: Colors.blueGrey),
                    value: 'Cash on Delivery',
                    groupValue: _paymentMethod,
                    onChanged: (val) => setState(() => _paymentMethod = val!),
                    activeColor: Colors.lightBlue,
                  ),
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
              const TextField(
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter your delivery address...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LocationScreen()),
                  );
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
                    const ListTile(
                      leading: Icon(Icons.store, color: Colors.lightBlue),
                      title: Text('Ahmad Store'),
                      subtitle: Text('No. 12, Jalan Bukit Bintang, KL'),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.access_time),
                      title: Text('Pickup Hours'),
                      subtitle: Text('Mon–Fri  10:00 AM – 6:00 PM'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: const Text('View on Map'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LocationScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ── Place Order ──
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // Show fake payment success dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 72),
                          const SizedBox(height: 20),
                          const Text(
                            'Payment Successful!',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your order has been placed.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Order ID: #ORD-013',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.lightBlue),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                // Close dialog then go to Order History
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                      const OrderHistoryScreen()),
                                );
                              },
                              child: const Text('View My Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
}