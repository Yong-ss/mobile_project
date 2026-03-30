import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  final myID = currentUser!['id'];

  // 待会儿我们要从数据库填充这些变量
  double _totalSales = 0.0;
  int _orderCount = 0;
  int _productCount = 0;
  List<Map<String, dynamic>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
double tempTotalSales = 0.0;
  int _orderCount = 0;
  int _productCount = 0;

final List<dynamic> confirmedItems = await _supabase
    .from('order_item')
    .select('unit_price, quantity, orders!inner(status)') 
    .eq('seller_id', myID)
    .eq('orders.status', 'completed'); 


    for (var item in confirmedItems) {
      tempTotalSales += (item['unit_price'] as num) * (item['quantity'] as num);
    }

    final List<dynamic> orderCount = await _supabase
    .from('order')
    .select('id') 
    .eq('seller_id', myID)
    .eq('status', 'completed'); 
    _orderCount = orderCount.length;


    
    setState(() {
      _totalSales = tempTotalSales;
      _isLoading = false; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Dashboard')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // overall data card
                  Row(
                    children: [
                      _StatCard(label: 'Total Sales', value: 'RM ${_totalSales.toStringAsFixed(2)}', icon: Icons.attach_money),
                      const SizedBox(width: 8),



                      _StatCard(label: 'Orders', value: '$_orderCount', icon: Icons.receipt),
                    ],
                  ),
                  const SizedBox(height: 8),


                  Row(
                    children: [
                      _StatCard(label: 'Products', value: '$_productCount Listed', icon: Icons.inventory_2),
                      const SizedBox(width: 8),



                      _StatCard(label: 'Total Customers', value: '0', icon: Icons.people),
                    ],
                  ),
                  const SizedBox(height: 24),









 /////////////////////////////////////////////////////////////// Chart
                  const Text(
                    'Monthly Sales Chart',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                 
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Chart will be generated after data fetch', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Top Products',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),











                  // Top products
                  _topProducts.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No sales records yet')))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _topProducts.length,
                          itemBuilder: (context, index) {
                            final product = _topProducts[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Text(product['name'] ?? 'Product'),
                              subtitle: Text('${product['sold_count']} sold'),
                              trailing: Text(
                                'RM ${product['revenue']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
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


class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}