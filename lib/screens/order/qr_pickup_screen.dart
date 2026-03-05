import 'package:flutter/material.dart';

// Member 3: QR Pickup Screen
// Purpose: Buyer scans seller's QR code to confirm order pickup.
// Only reached from OrderDetailsScreen when order status = "Ready for Pickup".
class QrPickupScreen extends StatelessWidget {
  const QrPickupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Pickup QR')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Order #ORD-011',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text('Denim Jacket x2'),
              const SizedBox(height: 8),
              const Text(
                'Scan the QR code displayed by the seller to confirm your pickup.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),

              // Camera viewfinder placeholder (real QR scanner added later)
              const SizedBox(
                width: 240,
                height: 240,
                child: Placeholder(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Point your camera at seller\'s QR code',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 28),

              // Scan button stub (QR scanner logic added in Ch 6 phase)
              ElevatedButton.icon(
                onPressed: () {}, // QR scanner logic added later (Ch 6)
                icon: const Icon(Icons.qr_code_scanner),
                label: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Start Scanning', style: TextStyle(fontSize: 15)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Info card
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.lightBlue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ask the seller to show their QR code. Scanning it confirms your pickup and completes the order.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
