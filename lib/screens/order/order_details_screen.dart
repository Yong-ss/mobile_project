import 'package:flutter/material.dart';
import 'qr_pickup_screen.dart';


// Buyer's order detail view — Member 3
// Shows full order info and status.
// QR scan button only appears when order status is "Ready for Pickup".
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy order data — replace with real model later
    const String orderId = '#ORD-002';
    const String fulfillment = 'Self Pickup'; // or 'Delivery'
    const String status = 'Ready for Pickup';

    final bool isPickup = fulfillment == 'Self Pickup';
    final bool isReadyForPickup = status == 'Ready for Pickup';

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Order ID + Status ──
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.lightBlue),
                title: Text(orderId,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Placed: 25 Feb 2025'),
                trailing: Chip(
                  label: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: _statusColor(status),
                    ),
                  ),
                  backgroundColor: _statusColor(status).withValues(alpha: 0.12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Items ──
            const Text('Items',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('Denim Jacket x2'),
                    trailing: Text('RM 170.00'),
                  ),
                  Divider(),
                  ListTile(
                    title: Text('Total'),
                    trailing: Text(
                      'RM 170.00',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Fulfillment Info ──
            const Text('Fulfillment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  isPickup ? Icons.storefront : Icons.local_shipping,
                  color: Colors.lightBlue,
                ),
                title: Text(fulfillment),
                subtitle: isPickup
                    ? const Text('Ahmad Store — No. 12, Jalan Bukit Bintang, KL')
                    : const Text('Delivered to your address'),
              ),
            ),
            const SizedBox(height: 24),

            // ── Status Timeline ──
            const Text('Status History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _buildStatusStep('Order Placed', true),
            _buildStatusStep('Preparing', true),
            _buildStatusStep('Ready for Pickup', isReadyForPickup),
            _buildStatusStep(
                isPickup ? 'Picked Up' : 'Delivered', false),
            const SizedBox(height: 24),

            // ── Scan QR button — only for Pickup + Ready for Pickup status ──
            if (isPickup && isReadyForPickup)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const QrPickupScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('Scan Seller QR to Confirm Pickup',
                        style: TextStyle(fontSize: 15)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
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

  Widget _buildStatusStep(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: done ? Colors.black : Colors.grey,
              fontWeight: done ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
