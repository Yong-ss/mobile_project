import 'package:flutter/material.dart';
import 'order_details_screen.dart';

// Member 3: Order History — buyer's list of past orders.
// Tapping an order navigates to OrderDetailsScreen for full detail + QR pickup action.
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  final List<Map<String, String>> _orders = const [
    {
      'id': '#ORD-001',
      'item': 'Bluetooth Speaker',
      'date': '01 Mar 2025',
      'status': 'Delivered',
      'type': 'Delivery'
    },
    {
      'id': '#ORD-002',
      'item': 'Denim Jacket x2',
      'date': '25 Feb 2025',
      'status': 'Ready for Pickup',
      'type': 'Self Pickup'
    },
    {
      'id': '#ORD-003',
      'item': 'Notebook Set',
      'date': '18 Feb 2025',
      'status': 'Delivered',
      'type': 'Delivery'
    },
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final status = order['status']!;
          final isPickup = order['type'] == 'Self Pickup';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                isPickup ? Icons.storefront : Icons.local_shipping,
                color: Colors.lightBlue,
              ),
              title: Text(order['item']!),
              subtitle: Text('${order['id']} • ${order['date']}'),
              trailing: Chip(
                label: Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                backgroundColor: _statusColor(status).withValues(alpha: 0.12),
              ),
              // Tap to view order details + QR action if applicable
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const OrderDetailsScreen()),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
