import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'package:intl/intl.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  final ScrollController _scrollController = ScrollController();
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreLogs();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      _page = 0;
      _hasMore = true;

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('system_logs')
          .select('*')
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _hasMore = response.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreLogs() async {
    if (_isLoadingMore || !_hasMore) return;

    if (mounted) setState(() => _isLoadingMore = true);
    try {
      _page++;
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('system_logs')
          .select('*')
          .order('created_at', ascending: false)
          .range(from, to);

      if (mounted) {
        setState(() {
          _logs.addAll(List<Map<String, dynamic>>.from(response));
          _hasMore = response.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more audit logs: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('System Audit Logs', style: TextStyle(fontWeight: FontWeight.bold)),
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
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.blueGrey),
                    const SizedBox(width: 12),
                    const Text(
                      'Recent Critical Actions',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _fetchLogs,
                      icon: const Icon(Icons.refresh, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? _buildSkeleton()
                    : _logs.isEmpty
                    ? const Center(child: Text('No logs found.'))
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _logs.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _logs.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return _buildLogTile(_logs[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: BaseSkeleton(width: double.infinity, height: 80, borderRadius: 12),
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final createdAt = DateTime.tryParse(log['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('MM/dd HH:mm').format(createdAt);

    // Choose icon based on action type
    IconData actionIcon = Icons.info_outline;
    Color iconColor = Colors.blueGrey;

    final action = (log['action'] ?? '').toString().toLowerCase();
    if (action.contains('delete')) {
      actionIcon = Icons.delete_forever;
      iconColor = Colors.red;
    } else if (action.contains('approve')) {
      actionIcon = Icons.verified;
      iconColor = Colors.green;
    } else if (action.contains('reject')) {
      actionIcon = Icons.block;
      iconColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showLogDetails(log),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(actionIcon, color: iconColor, size: 20),
        ),
        title: Text(log['action'] ?? 'Unspecified Action', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log['details'] ?? 'No details provided',
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 10, color: Colors.grey),
                const SizedBox(width: 4),
                Text(log['admin_id'] ?? 'Unknown Admin', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        trailing: Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ),
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      log['action'] ?? 'Action Detail',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.black54)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text('DETAILS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              Text(
                  log['details'] ?? 'No details',
                  style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildInfoChip(Icons.person, log['admin_id'] ?? 'Unknown'),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.access_time, DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(log['created_at']))),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
