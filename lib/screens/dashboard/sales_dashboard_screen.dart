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
  Map<int, double> _monthlySales = {};
  double _maxMonthlySales = 100.0;

  // 待会儿我们要从数据库填充这些变量
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
        .eq('orders.status', 'completed');

    for (var item in confirmedItems) {
      tempTotalSales +=
          ((item['unit_price'] as num) * (item['quantity'] as num)).toDouble();
    }

    final List<dynamic> orderList = await _supabase
        .from('orders')
        .select('id, buyer_id')
        .eq('seller_id', myID)
        .eq('status', 'completed');

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

    // 修改你之前的那个查询：
    final List<dynamic> itemsForRank = await _supabase
        .from('order_item')
        // 关键：带上 product 表里的 name，这样我们才知道这是什么宝贝
        .select(
          'product_id, quantity, unit_price, created_at, product!inner(name), orders!inner(status)',
        )
        .eq('seller_id', myID)
        .eq('orders.status', 'completed');
    // --- 独立修正版排行逻辑开始 ---
    Map<int, Map<String, dynamic>> rankMap = {};

    for (var item in itemsForRank) {
      int pid = item['product_id'];

      // 容错处理：确保能拿到名字
      String name = item['product']['name'] ?? 'Unknown Product';

      // 核心：强制转换为 num 再转 double，保证万无一失
      double priceAtThatTime = (item['unit_price'] as num).toDouble();
      int quantitySold = item['quantity'] as int;
      double revenueOfItem = priceAtThatTime * quantitySold;

      if (rankMap.containsKey(pid)) {
        rankMap[pid]!['sold_count'] += quantitySold;
        // 累加时记得也要 toDouble()
        rankMap[pid]!['revenue'] =
            (rankMap[pid]!['revenue'] as double) + revenueOfItem;
      } else {
        rankMap[pid] = {
          'name': name,
          'sold_count': quantitySold,
          'revenue': revenueOfItem,
        };
      }
    }

    // 选出 Top 5
    List<Map<String, dynamic>> sortedResults = rankMap.values.toList();
    // 强制按 double 比较，防止报错
    sortedResults.sort(
      (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double),
    );
    // --- 柱状图统计开始 ---
    Map<int, double> tempMonthlyTotal = {for (int i = 1; i <= 12; i++) i: 0.0};

    // 我们用 itemsForRank 这个大清单来算更准，因为它有所有的数据
    for (var item in itemsForRank) {
      double revenueOfLine =
          ((item['unit_price'] as num) * (item['quantity'] as num)).toDouble();

      // 解析日期字段，并拿到月份
      DateTime date = DateTime.parse(item['created_at']);
      int m = date.month;

      tempMonthlyTotal[m] = tempMonthlyTotal[m]! + revenueOfLine;
    }

    // 算出所有月份里的最高销售额 (为了调整柱子高度)
    double maxM = 100.0;
    tempMonthlyTotal.forEach((k, v) {
      if (v > maxM) maxM = v;
    });
    // --- 柱状图统计结束 ---

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
                  const SizedBox(height: 24),

                  /////////////////////////////////////////////////////////////// Chart
                  const Text(
                    'Monthly Sales Chart',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // 柱状图容器
                  Container(
                    width: double.infinity,
                    height: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(12, (index) {
                        int monthIndex = index + 1;
                        double sales = _monthlySales[monthIndex] ?? 0.0;

                        // 计算柱子高度比例
                        double barHeight = (sales / _maxMonthlySales) * 120.0;

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 柱子上方的金额 (如果有钱才显示)
                            if (sales > 0)
                              Text(
                                'RM ${sales.toInt()}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            const SizedBox(height: 4),
                            // 月份柱子
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: 12,
                              height: barHeight + 5, // 至少给 5 个像素的高度，不然 0 元月太秃了
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade800,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 月份标签
                            Text(
                              [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ][index],
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),

                  ///////////////////////////////////////// Top products
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