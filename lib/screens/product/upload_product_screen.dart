import 'package:flutter/material.dart';

// Member 4: Upload Product screen — Placeholder for camera feature (Ch 3.1: Placeholder)

class UploadProductScreen extends StatelessWidget {
  const UploadProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera placeholder area (will be replaced with real camera in later phase)
            const Text('Product Photo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 200,
              // Placeholder widget recommended by Ch 3.1 for in-development areas
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Placeholder(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                      const SizedBox(height: 4),
                      const Text('Tap to take photo',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {}, // Camera logic added later
                        child: const Text('Open Camera'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Product Name
            const Text('Product Name',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                hintText: 'e.g. Bluetooth Speaker',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Price
            const Text('Price (RM)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 60.00',
                border: OutlineInputBorder(),
                prefixText: 'RM ',
              ),
            ),
            const SizedBox(height: 16),

            // Category
            const Text('Category',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                hintText: 'e.g. Electronics, Clothing...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            const Text('Description',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your product...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Submit Listing', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
