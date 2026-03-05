import 'package:flutter/material.dart';
import '../order/order_history_screen.dart';
import '../map/location_screen.dart';

// Member 3: CheckoutScreen
// StatefulWidget — tracks Delivery vs Pickup toggle (Ch 3.1: stateful)
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isSelfPickup = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Order Summary ──
            const Text('Order Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    title: Text('Bluetooth Speaker'),
                    trailing: Text('RM 60.00'),
                  ),
                  const Divider(),
                  const ListTile(
                    title: Text('Denim Jacket x2'),
                    trailing: Text('RM 170.00'),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Text('RM 230.00',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.lightBlue)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Fulfillment Toggle ──
            const Text('Fulfillment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isSelfPickup = false),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Delivery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isSelfPickup
                          ? Colors.lightBlue
                          : Colors.grey.shade200,
                      foregroundColor:
                          !_isSelfPickup ? Colors.white : Colors.black,
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
                      backgroundColor:
                          _isSelfPickup ? Colors.lightBlue : Colors.grey.shade200,
                      foregroundColor:
                          _isSelfPickup ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Delivery Section ──
            if (!_isSelfPickup) ...[
              const Text('Delivery Address',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const TextField(
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter your delivery address...',
                  border: OutlineInputBorder(),
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
            // Shows SELLER pickup point only — buyer does not enter their own address.
            // QR pickup screen is shown AFTER placing the order (as a pickup receipt).
            if (_isSelfPickup) ...[
              const Text('Seller Pickup Point',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.store, color: Colors.lightBlue),
                      title: Text('Ahmad Store'),
                      subtitle: Text('No. 12, Jalan Bukit Bintang, KL'),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.access_time),
                      title: Text('Pickup Hours'),
                      subtitle: Text('Mon–Fri  10:00 AM – 6:00 PM'),
                    ),
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
            const SizedBox(height: 24),

            // ── Place Order ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Both Delivery and Pickup go to Order History first.
                  // QR pickup is a later step from Order Details,
                  // only once seller marks order as "Ready for Pickup".
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const OrderHistoryScreen()),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Place Order', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
