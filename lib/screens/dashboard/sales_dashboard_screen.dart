import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
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
  Map<int, double> _monthlySales = {};
  double _maxMonthlySales = 100.0;

  double _totalSales = 0.0;
  int _orderCount = 0;
  int _productCount = 0;
  int _customerCount = 0;
  List<Map<String, dynamic>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    double tempTotalSales = 0.0;
    int tempOrderCount = 0;
    int tempProductCount = 0;
    int tempCustomerCount = 0;

    final List<dynamic> confirmedItems = await _supabase
        .from('order_item')
        .select('unit_price, quantity, orders!inner(status)')
        .eq('seller_id', myID)
        .inFilter('orders.status', ['Pending', 'Completed', 'Paid', 'Delivered']);

    for (var item in confirmedItems) {
      tempTotalSales +=
          ((item['unit_price'] as num) * (item['quantity'] as num)).toDouble();
    }

    final List<dynamic> orderList = await _supabase
        .from('orders')
        .select('id, buyer_id')
        .eq('seller_id', myID)
        .inFilter('status', ['Pending', 'Completed', 'Paid', 'Delivered']);

    tempOrderCount = orderList.length;
    tempCustomerCount = orderList
        .map((item) => item['buyer_id'])
        .toSet()
        .length;

    final List<dynamic> productCount = await _supabase
        .from('product')
        .select('id')
        .eq('seller_id', myID);

    tempProductCount = productCount.length;

    final List<dynamic> itemsForRank = await _supabase
        .from('order_item')
        .select(
      'product_id, quantity, unit_price, created_at, product!inner(name), orders!inner(status)',
    )
        .eq('seller_id', myID)
        .inFilter('orders.status', ['Pending', 'Completed', 'Paid', 'Delivered']);

    Map<int, Map<String, dynamic>> rankMap = {};

    for (var item in itemsForRank) {
      int pid = item['product_id'];
      String name = item['product']['name'] ?? 'Unknown Product';
      double priceAtThatTime = (item['unit_price'] as num).toDouble();
      int quantitySold = item['quantity'] as int;
      double revenueOfItem = priceAtThatTime * quantitySold;

      if (rankMap.containsKey(pid)) {
        rankMap[pid]!['sold_count'] += quantitySold;
        rankMap[pid]!['revenue'] = (rankMap[pid]!['revenue'] as double) + revenueOfItem;
      } else {
        rankMap[pid] = {
          'name': name,
          'sold_count': quantitySold,
          'revenue': revenueOfItem,
        };
      }
    }

    List<Map<String, dynamic>> sortedResults = rankMap.values.toList();
    sortedResults.sort(
          (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double),
    );

    Map<int, double> tempMonthlyTotal = {for (int i = 1; i <= 12; i++) i: 0.0};

    for (var item in itemsForRank) {
      double revenueOfLine = ((item['unit_price'] as num) * (item['quantity'] as num)).toDouble();
      DateTime date = DateTime.parse(item['created_at']);
      int m = date.month;
      tempMonthlyTotal[m] = tempMonthlyTotal[m]! + revenueOfLine;
    }

    double maxM = 100.0;
    tempMonthlyTotal.forEach((k, v) {
      if (v > maxM) maxM = v;
    });

    if (mounted) {
      setState(() {
        _totalSales = tempTotalSales;
        _orderCount = tempOrderCount;
        _productCount = tempProductCount;
        _customerCount = tempCustomerCount;
        _monthlySales = tempMonthlyTotal;
        _maxMonthlySales = maxM;
        _topProducts = sortedResults.take(5).map((e) {
          return {
            'name': e['name'],
            'sold_count': e['sold_count'],
            'revenue': (e['revenue'] as double).toStringAsFixed(2),
          };
        }).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Dashboard')),
      body: SafeArea(
        child: _isLoading
            ? _buildShimmerLoading()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatCard(
                    label: 'Total Sales',
                    value: 'RM ${_totalSales.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'Orders',
                    value: '$_orderCount',
                    icon: Icons.receipt,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatCard(
                    label: 'Products',
                    value: '$_productCount Listed',
                    icon: Icons.inventory_2,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'Total Customers',
                    value: '$_customerCount',
                    icon: Icons.people,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                'Monthly Sales Chart',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Premium Line Chart Container
              Container(
                width: double.infinity,
                height: 250,
                padding: const EdgeInsets.only(right: 20, left: 10, top: 32, bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 500,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                            int index = value.toInt() - 1;
                            if (index >= 0 && index < 12) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 18.0),
                                child: Text(months[index], style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 500,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              'RM ${value.toInt()}',
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                              textAlign: TextAlign.left,
                            );
                          },
                          reservedSize: 45,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 1,
                    maxX: 12,
                    minY: 0,
                    maxY: 2000,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => Colors.blue.shade800,
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final flSpot = barSpot;
                            return LineTooltipItem(
                              'RM ${flSpot.y.toStringAsFixed(2)}',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(12, (index) {
                          int m = index + 1;
                          return FlSpot(m.toDouble(), _monthlySales[m] ?? 0.0);
                        }),
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.blue],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent.withValues(alpha: 0.4),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Top Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _topProducts.isEmpty
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No sales records yet'),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topProducts.length,
                itemBuilder: (context, index) {
                  final product = _topProducts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(product['name'] ?? 'Product'),
                    subtitle: Text('${product['sold_count']} sold'),
                    trailing: Text(
                      'RM ${product['revenue']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _shimmerCard()),
                const SizedBox(width: 8),
                Expanded(child: _shimmerCard()),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _shimmerCard()),
                const SizedBox(width: 8),
                Expanded(child: _shimmerCard()),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _shimmerCard() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}