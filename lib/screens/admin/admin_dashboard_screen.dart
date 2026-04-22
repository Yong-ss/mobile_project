import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'user_management_screen.dart';
import 'announcement_management_screen.dart';
import 'seller_verification_screen.dart';
import 'admin_order_management_screen.dart';
import 'moderation_queue_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_settings_screen.dart';
import '../core/notification_screen.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../../utils/globals.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  int _totalUsers = 0;
  int _totalSellers = 0;
  int _totalOrders = 0;
  int _activeAnnouncements = 0;

  // Dynamic Chart Data
  final List<double> _userGrowthSpots = [];
  final List<double> _orderVolumeSpots = [];

  String _userChartPeriod = 'Day';
  String _orderChartPeriod = 'Day';
  final List<String> _periods = ['Day', 'Month', 'Year'];

  List<dynamic> _rawUsers = [];
  List<dynamic> _rawOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      // Fetch users with created_at for growth chart
      final usersRes = await _supabase.from('user').select('id, is_seller, created_at');
      _totalUsers = usersRes.length;
      _totalSellers = usersRes.where((u) => u['is_seller'] == true).length;

      // Fetch orders with created_at for volume chart
      final ordersRes = await _supabase.from('orders').select('id, created_at');
      _totalOrders = ordersRes.length;

      // Fetch announcements
      final annRes = await _supabase.from('announcements').select('id');
      _activeAnnouncements = annRes.length;

      _rawUsers = usersRes;
      _rawOrders = ordersRes;

      _processUserChartData();
      _processOrderChartData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.lightBlue.withValues(alpha: 0.2),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.lightBlue, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              offset: const Offset(0, 25),
              position: PopupMenuPosition.under,
              onSelected: (value) async {
                if (value == 'logout') {
                  final authService = AuthService();
                  await authService.signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                } else if (value == 'settings') {
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminSettingsScreen()),
                  ).then((_) => setState(() {})); // Refresh icon when returning
                } else if (value == 'notifications') {
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationScreen(isSystemOnly: true)),
                  );
                }
              },
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.lightBlue.withValues(alpha: 0.1),
                backgroundImage: (currentUser?['user_pic'] != null && currentUser!['user_pic'].toString().isNotEmpty)
                    ? NetworkImage(currentUser!['user_pic'].toString().split(',')[0])
                    : null,
                child: (currentUser?['user_pic'] == null || currentUser!['user_pic'].toString().isEmpty)
                    ? const Icon(Icons.person, color: Colors.lightBlue, size: 20)
                    : null,
              ),
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'notifications',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_none_rounded, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Notifications'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? _buildDashboardSkeleton()
              : RefreshIndicator(
            onRefresh: _fetchDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 36, color: Colors.lightBlue),
                      SizedBox(width: 12),
                      Text(
                        'System Overview',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Grid Stats ──
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Users', '$_totalUsers', Icons.people, Colors.lightBlue)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Total Sellers', '$_totalSellers', Icons.store, Colors.lightBlue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Orders', _totalOrders.toString(), Icons.shopping_bag, Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Announcements', _activeAnnouncements.toString(), Icons.campaign, Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Performance Charts ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('User Registrations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.lightBlue)),
                      DropdownButton<String>(
                        value: _userChartPeriod,
                        isDense: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.lightBlue),
                        items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _userChartPeriod = val;
                              _processUserChartData();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildGrowthChart(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Volume', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.lightBlue)),
                      DropdownButton<String>(
                        value: _orderChartPeriod,
                        isDense: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.lightBlue),
                        items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _orderChartPeriod = val;
                              _processOrderChartData();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildOrderVolumeChart(),
                  const SizedBox(height: 32),

                  // ── Management Modules (Grid Layout) ──
                  const Text('Administrative Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                  const SizedBox(height: 16),
                  _buildModuleGrid(),
                  const SizedBox(height: 40),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSkeleton() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: List.generate(
            3,
                (index) => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: BaseSkeleton(width: double.infinity, height: 120, borderRadius: 16),
            ),
          ),
        ),
      ),
    );
  }

  void _processUserChartData() {
    final now = DateTime.now();
    _userGrowthSpots.clear();

    if (_userChartPeriod == 'Day') {
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final count = _rawUsers.where((u) {
          final createdAt = DateTime.tryParse(u['created_at'] ?? '');
          return createdAt != null && createdAt.isAfter(dayStart) && createdAt.isBefore(dayEnd);
        }).length;
        _userGrowthSpots.add(count.toDouble());
      }
    } else if (_userChartPeriod == 'Month') {
      for (int i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthStart = DateTime(date.year, date.month, 1);
        final monthEnd = DateTime(date.year, date.month + 1, 1);
        final count = _rawUsers.where((u) {
          final createdAt = DateTime.tryParse(u['created_at'] ?? '');
          return createdAt != null && createdAt.isAfter(monthStart) && createdAt.isBefore(monthEnd);
        }).length;
        _userGrowthSpots.add(count.toDouble());
      }
    } else { // Year
      for (int i = 4; i >= 0; i--) {
        final year = now.year - i;
        final yearStart = DateTime(year, 1, 1);
        final yearEnd = DateTime(year + 1, 1, 1);
        final count = _rawUsers.where((u) {
          final createdAt = DateTime.tryParse(u['created_at'] ?? '');
          return createdAt != null && createdAt.isAfter(yearStart) && createdAt.isBefore(yearEnd);
        }).length;
        _userGrowthSpots.add(count.toDouble());
      }
    }
  }

  void _processOrderChartData() {
    final now = DateTime.now();
    _orderVolumeSpots.clear();

    if (_orderChartPeriod == 'Day') {
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final count = _rawOrders.where((o) {
          final createdAt = DateTime.tryParse(o['created_at'] ?? '');
          return createdAt != null && createdAt.isAfter(dayStart) && createdAt.isBefore(dayEnd);
        }).length;
        _orderVolumeSpots.add(count.toDouble());
      }
    } else if (_orderChartPeriod == 'Month') {
      for (int i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthStart = DateTime(date.year, date.month, 1);
        final monthEnd = DateTime(date.year, date.month + 1, 1);
        final count = _rawOrders.where((o) {
          final createdAt = DateTime.tryParse(o['created_at'] ?? '');
          return createdAt != null && createdAt.isAfter(monthStart) && createdAt.isBefore(monthEnd);
        }).length;
        _orderVolumeSpots.add(count.toDouble());
      }
    } else { // Year
      for (int i = 4; i >= 0; i--) {
        final year = now.year - i;
        final yearStart = DateTime(year, 1, 1);
        final yearEnd = DateTime(year + 1, 1, 1);
        final count = _rawOrders.where((o) {
          final createdAt = DateTime.tryParse(o['created_at'] ?? '');
          return createdAt != null && createdAt.isAfter(yearStart) && createdAt.isBefore(yearEnd);
        }).length;
        _orderVolumeSpots.add(count.toDouble());
      }
    }
  }

  // --- Helpers ---

  Widget _buildGrowthChart() {
    double maxY = 5.0;
    for (var spot in _userGrowthSpots) {
      if (spot > maxY) maxY = spot + 1;
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(20, 24, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          minY: 0,
          maxY: maxY,
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final int index = value.toInt();
                  if (index < 0 || index >= _userGrowthSpots.length) return const SizedBox.shrink();

                  final now = DateTime.now();
                  String label = "";
                  if (_userChartPeriod == 'Day') {
                    final date = now.subtract(Duration(days: 6 - index));
                    label = DateFormat('E').format(date);
                  } else if (_userChartPeriod == 'Month') {
                    final date = DateTime(now.year, now.month - (5 - index), 1);
                    label = DateFormat('MMM').format(date);
                  } else {
                    label = (now.year - (4 - index)).toString();
                  }

                  return SideTitleWidget(
                    meta: meta,
                    space: 16,
                    child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxY / 5).ceilToDouble() > 0 ? (maxY / 5).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(_userGrowthSpots.length, (i) => FlSpot(i.toDouble(), _userGrowthSpots[i])),
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.lightBlue,
              barWidth: 3,
              belowBarData: BarAreaData(show: true, color: Colors.lightBlue.withValues(alpha: 0.1)),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderVolumeChart() {
    double maxY = 5.0;
    for (var spot in _orderVolumeSpots) {
      if (spot > maxY) maxY = spot + 1;
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(20, 24, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          minY: 0,
          maxY: maxY,
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
                  final int index = value.toInt();
                  if (index < 0 || index >= _orderVolumeSpots.length) return const SizedBox.shrink();

                  final now = DateTime.now();
                  String label = "";
                  if (_orderChartPeriod == 'Day') {
                    final date = now.subtract(Duration(days: 6 - index));
                    label = DateFormat('E').format(date)[0];
                  } else if (_orderChartPeriod == 'Month') {
                    final date = DateTime(now.year, now.month - (5 - index), 1);
                    label = DateFormat('MMM').format(date);
                  } else {
                    label = (now.year - (4 - index)).toString();
                  }

                  return SideTitleWidget(
                    meta: meta,
                    space: 16,
                    child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (maxY / 5).ceilToDouble() > 0 ? (maxY / 5).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(_orderVolumeSpots.length, (i) =>
              BarChartGroupData(x: i, barRods: [BarChartRodData(toY: _orderVolumeSpots[i], color: Colors.lightBlue, width: 14)])
          ),
        ),
      ),
    );
  }

  Widget _buildModuleGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildModuleTile('Users', Icons.people, Colors.lightBlue, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen())).then((_) => _fetchDashboardData());
        }),
        _buildModuleTile('Verification', Icons.verified_user, Colors.green, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerVerificationScreen())).then((_) => _fetchDashboardData());
        }),
        _buildModuleTile('Announcements', Icons.campaign, Colors.lightBlue, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AnnouncementManagementScreen())).then((_) => _fetchDashboardData());
        }),
        _buildModuleTile('Order Master', Icons.shopping_cart, Colors.purple, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminOrderManagementScreen())).then((_) => _fetchDashboardData());
        }),
        _buildModuleTile('Moderation', Icons.gavel, Colors.red, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ModerationQueueScreen())).then((_) => _fetchDashboardData());
        }),
        _buildModuleTile('System Logs', Icons.description, Colors.blueGrey, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAuditLogsScreen())).then((_) => _fetchDashboardData());
        }),
      ],
    );
  }

  Widget _buildModuleTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF263238))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF757575)),
          ),
        ],
      ),
    );
  }
}