import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/globals.dart';

class SellerVerificationScreen extends StatefulWidget {
  const SellerVerificationScreen({super.key});

  @override
  State<SellerVerificationScreen> createState() => _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingUsers = [];
  final ScrollController _scrollController = ScrollController();
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingUsers();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMorePendingUsers();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingUsers() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      _page = 0;
      _hasMore = true;

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user')
          .select('*')
          .eq('seller_application_status', 'pending')
          .order('username', ascending: true)
          .range(0, _pageSize - 1);

      if (mounted) {
        setState(() {
          _pendingUsers = List<Map<String, dynamic>>.from(response);
          _hasMore = response.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMorePendingUsers() async {
    if (_isLoadingMore || !_hasMore) return;

    if (mounted) setState(() => _isLoadingMore = true);
    try {
      _page++;
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user')
          .select('*')
          .eq('seller_application_status', 'pending')
          .order('username', ascending: true)
          .range(from, to);

      if (mounted) {
        setState(() {
          _pendingUsers.addAll(List<Map<String, dynamic>>.from(response));
          _hasMore = response.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more pending users: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _logAction(String action, String details) async {
    try {
      await Supabase.instance.client.from('system_logs').insert({
        'admin_id': currentUser?['email'] ?? 'Unknown Admin',
        'action': action,
        'details': details,
      });
    } catch (e) {
      debugPrint('Error logging action: $e');
    }
  }

  Future<void> _approveSeller(Map<String, dynamic> user) async {
    try {
      await Supabase.instance.client.from('user').update({
        'is_seller': true,
        'seller_application_status': 'approved',
        'shop_created_at': DateTime.now().toIso8601String(),
      }).eq('id', user['id']);

      await _logAction('Approve Seller', 'Approved shop "${user['shop_name']}" for user ${user['email']}');

      setState(() {
        _pendingUsers.removeWhere((u) => u['id'] == user['id']);
      });

      if (mounted) snackbar('Seller "${user['shop_name']}" approved!', Colors.green);
    } catch (e) {
      if (mounted) snackbar('Error approving seller: $e', Colors.red);
    }
  }

  Future<void> _rejectSeller(Map<String, dynamic> user) async {
    final TextEditingController reasonController = TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g., Invalid shop name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) {
                snackbar('Please provide a reason', Colors.orange);
                return;
              }
              Navigator.pop(dialogContext, text);
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        await Supabase.instance.client.from('user').update({
          'seller_application_status': 'rejected',
          'rejection_reason': reason,
        }).eq('id', user['id']);

        await _logAction('Reject Seller', 'Rejected "${user['shop_name']}" (${user['email']}). Reason: $reason');

        if (!mounted) return;
        setState(() {
          _pendingUsers.removeWhere((u) => u['id'] == user['id']);
        });

        snackbar('Application rejected.', Colors.orange);
      } catch (e) {
        if (mounted) snackbar('Error rejecting application: $e', Colors.red);
      }
    }
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Seller Verification', style: TextStyle(fontWeight: FontWeight.bold)),
          foregroundColor: Colors.black87,
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
          child: RefreshIndicator(
            onRefresh: _fetchPendingUsers,
            color: Colors.lightBlue,
            child: _isLoading
                ? _buildSkeleton()
                : _pendingUsers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _pendingUsers.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _pendingUsers.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return _buildApplicantCard(_pendingUsers[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: BaseSkeleton(width: double.infinity, height: 120, borderRadius: 16),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('No pending seller applications.', style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE3F2FD),
                  backgroundImage: (user['user_pic'] != null || user['google_profile_image'] != null)
                      ? NetworkImage((user['user_pic'] ?? user['google_profile_image']).toString().split(',')[0])
                      : null,
                  child: (user['user_pic'] == null && user['google_profile_image'] == null)
                      ? const Icon(Icons.person, color: Color(0xFF1976D2))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['username'] ?? 'No Name',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        user['email'] ?? 'No Email',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Proposed Shop Name:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      user['shop_name'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.lightBlue),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _rejectSeller(user),
                      icon: const Icon(Icons.close_rounded, color: Colors.red),
                      style: IconButton.styleFrom(backgroundColor: Colors.red.shade50),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _approveSeller(user),
                      icon: const Icon(Icons.check_rounded, color: Colors.green),
                      style: IconButton.styleFrom(backgroundColor: Colors.green.shade50),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}