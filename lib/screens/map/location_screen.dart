import 'package:flutter/material.dart';

// Member 2: Location Screen — shows seller pickup location on map
// Used when buyer taps "View on Map" from checkout pickup section.
// Placeholder used for the map area (Ch 3.1: Placeholder for unfinished features)
class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Location')),
      body: Column(
        children: [
          // Map Placeholder — shows seller's location (read-only view)
          const Expanded(
            child: Placeholder(),
          ),

          // Seller info panel below map
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller location info card (read-only)
                const Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.store, color: Colors.lightBlue),
                        title: Text('Ahmad Store'),
                        subtitle:
                            Text('No. 12, Jalan Bukit Bintang, KL'),
                      ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.access_time),
                        title: Text('Pickup Hours'),
                        subtitle: Text('Mon–Fri  10:00 AM – 6:00 PM'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Navigate / Get Directions button (GPS added later)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {}, // GPS navigation logic added later
                    icon: const Icon(Icons.navigation),
                    label: const Text('Get Directions'),
                  ),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
