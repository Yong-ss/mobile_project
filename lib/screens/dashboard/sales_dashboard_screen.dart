import 'package:flutter/material.dart';

// Member 4: Sales Dashboard with Charts — Placeholder for chart area (Ch 3.1: Placeholder)
class SalesDashboardScreen extends StatelessWidget {
  const SalesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards row (Ch 3.1: Card, Row)
            Row(
              children: [
                _StatCard(label: 'Total Sales', value: 'RM 1,520', icon: Icons.attach_money),
                const SizedBox(width: 8),
                _StatCard(label: 'Orders', value: '24', icon: Icons.receipt),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCard(label: 'Products', value: '8 Listed', icon: Icons.inventory_2),
                const SizedBox(width: 8),
                _StatCard(label: 'This Month', value: 'RM 340', icon: Icons.trending_up),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Monthly Sales Chart',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Chart Placeholder (Ch 3.1: Placeholder for unfinished advanced feature area)
            const SizedBox(
              width: double.infinity,
              height: 220,
              child: Placeholder(),
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Chart visualization will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Top Products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Top products ListView
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                final List<Map<String, String>> topProducts = [
                  {'name': 'Bluetooth Speaker', 'sold': '12 sold', 'revenue': 'RM 720'},
                  {'name': 'Denim Jacket', 'sold': '7 sold', 'revenue': 'RM 595'},
                  {'name': 'USB Hub', 'sold': '5 sold', 'revenue': 'RM 175'},
                ];
                final product = topProducts[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(product['name']!),
                  subtitle: Text(product['sold']!),
                  trailing: Text(
                    product['revenue']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlue),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Small reusable stat card widget (private to this file)
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.lightBlue),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
