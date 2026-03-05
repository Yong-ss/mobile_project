import 'package:flutter/material.dart';

// Member 3: SellerOrdersScreen — seller view of all incoming orders
// Seller can manually update order status from here.
// Pickup orders display a "Show Pickup QR" option for the buyer to scan.
class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  // Dummy incoming orders
  final List<Map<String, String>> _orders = const [
    {
      'id': '#ORD-010',
      'buyer': 'Ahmad Razif',
      'item': 'Bluetooth Speaker',
      'type': 'Delivery',
      'status': 'Order Placed',
    },
    {
      'id': '#ORD-011',
      'buyer': 'Siti Nurul',
      'item': 'Denim Jacket x2',
      'type': 'Self Pickup',
      'status': 'Ready for Pickup',
    },
    {
      'id': '#ORD-012',
      'buyer': 'Tan Wei Ming',
      'item': 'USB Hub',
      'type': 'Delivery',
      'status': 'Out for Delivery',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Orders')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final isPickup = order['type'] == 'Self Pickup';
          final status = order['status']!;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(order['id']!,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Chip(
                        label: Text(
                          order['type']!,
                          style: const TextStyle(fontSize: 11),
                        ),
                        avatar: Icon(
                          isPickup ? Icons.storefront : Icons.local_shipping,
                          size: 14,
                        ),
                        backgroundColor: isPickup
                            ? Colors.lightBlue.shade50
                            : Colors.blue.shade50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Buyer: ${order['buyer']}',
                      style: const TextStyle(color: Colors.grey)),
                  Text('Item: ${order['item']}'),
                  const SizedBox(height: 8),

                  // Status chip
                  Row(
                    children: [
                      const Text('Status: ',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Chip(
                        label: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            color: _statusColor(status),
                          ),
                        ),
                        backgroundColor:
                            _statusColor(status).withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Action buttons — manual status updates
                  Wrap(
                    spacing: 8,
                    children: [
                      if (status == 'Order Placed')
                        ElevatedButton(
                          onPressed: () {}, // update status logic later
                          child: const Text('Mark Preparing'),
                        ),
                      if (status == 'Preparing' && !isPickup)
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Mark Out for Delivery'),
                        ),
                      if (status == 'Preparing' && isPickup)
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Mark Ready for Pickup'),
                        ),
                      if (status == 'Out for Delivery')
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Mark Delivered'),
                        ),

                      // Pickup QR — seller shows this for buyer to scan
                      if (isPickup && status == 'Ready for Pickup')
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Pickup QR Code'),
                                content: const SizedBox(
                                  width: 180,
                                  height: 180,
                                  child: Placeholder(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code),
                          label: const Text('Show Pickup QR'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Order Placed':
        return Colors.blue;
      case 'Preparing':
        return Colors.orange;
      case 'Ready for Pickup':
      case 'Out for Delivery':
        return Colors.lightBlue;
      case 'Delivered':
      case 'Picked Up':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
