import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/globals.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  String _filterRole = 'All'; // 'All', 'Customer', 'Seller'
  bool _allSelected = false;
  bool _isSelectionMode = false;
  RealtimeChannel? _realtimeChannel;
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final int _pageSize = 20;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _setupRealtime();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isFetchingMore && _hasMore) {
          _fetchUsers(loadMore: true);
        }
      }
    });
  }

  void _setupRealtime() {
    final supabase = Supabase.instance.client;
    _realtimeChannel = supabase.channel('public:user:admin_management')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user',
      callback: (payload) {
        debugPrint('User table changed via realtime. Refreshing...');
        _fetchUsers();
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }


  Future<void> _fetchUsers({bool loadMore = false}) async {
    if (loadMore) {
      if (mounted) {
        setState(() => _isFetchingMore = true);
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _offset = 0;
          _hasMore = true;
          _users.clear();
        });
      }
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user')
          .select('*')
          .order('username', ascending: true)
          .range(_offset, _offset + _pageSize - 1);

      final List<Map<String, dynamic>> newUsers = [];
      for (var row in response) {
        newUsers.add({
          'id': row['id']?.toString() ?? '',
          'customer_name': row['username'] ?? 'Unknown',
          'customer_email': row['email'] ?? 'No email',
          'customer_verified': row['customer_verified'] == true ? 'Verified' : 'Not Verified',
          'customer_joined_at': _formatDate(row['created_at']),
          'user_pic': row['user_pic'] ?? '',
          'google_pic': row['google_profile_image'] ?? '',
          'seller_name': row['shop_name'] ?? '',
          'seller_status': row['is_seller'] == true ? 'Registered' : 'Unregistered',
          'seller_joined_at': _formatDate(row['shop_created_at']),
          'shop_pic': row['shop_pic'] ?? '',
          'is_seller': row['is_seller'] ?? false,
          'isChecked': false,
        });
      }

      setState(() {
        if (loadMore) {
          _users.addAll(newUsers);
        } else {
          _users = newUsers;
        }
        _isLoading = false;
        _isFetchingMore = false;
        _hasMore = newUsers.length == _pageSize;
        _offset += newUsers.length;
      });
    } catch (e) {
      debugPrint('Error fetching users from Supabase: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
        snackbar('Failed to load users.', Colors.red);
      }
    }
  }

  String _formatDate(dynamic isoDate) {
    if (isoDate == null) return '';
    try {
      DateTime dt = DateTime.parse(isoDate.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate.toString();
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

  Future<void> _performForceDelete(List<String> userIds) async {
    final supabase = Supabase.instance.client;

    for (final userId in userIds) {
      // 1. Delete Cart items
      try { await supabase.from('cart').delete().eq('user_id', userId); } catch (_) {}

      // 2. Identify orders related to this user (buyer or seller)
      final ordersRes = await supabase
          .from('orders')
          .select('id')
          .or('buyer_id.eq.$userId,seller_id.eq.$userId');

      final List<String> orderIds = (ordersRes as List).map((o) => o['id'].toString()).toList();

      if (orderIds.isNotEmpty) {
        // 3. Delete Order Items (linked to these orders)
        try {
          await supabase.from('order_item').delete().filter('order_id', 'in', '(${orderIds.join(',')})');
        } catch (_) {}
        // 4. Delete Orders
        try {
          await supabase.from('orders').delete().filter('id', 'in', '(${orderIds.join(',')})');
        } catch (_) {}
      }

      // 5. Delete Products (where user is seller)
      try { await supabase.from('product').delete().eq('seller_id', userId); } catch (_) {}

      // 6. Finally delete the user record from 'user' table
      await supabase.from('user').delete().eq('id', userId);
    }
  }

  void _deleteUser(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to permanently delete ${_users[index]['customer_name']} and ALL their related data (products, orders, cart)? This action is irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final user = _users[index];
              try {
                await _performForceDelete([user['id'].toString()]);
                await _logAction('Delete User', 'Permanently deleted user ${user['customer_email']} and all related data.');

                if (mounted) {
                  setState(() {
                    _users.removeAt(index);
                  });
                  snackbar('User and related data deleted successfully', Colors.green);
                }
              } catch (e) {
                if (mounted) snackbar('Error deleting user: $e', Colors.red);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _batchDelete() {
    final selectedUsers = _users.where((u) => u['isChecked'] == true).toList();
    if (selectedUsers.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${selectedUsers.length} Users?'),
        content: const Text('This will permanently remove all selected accounts and ALL their related data (products, orders, etc). This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final List<String> ids = selectedUsers.map((u) => u['id'].toString()).toList();
                await _performForceDelete(ids);

                await _logAction('Batch Delete Users', 'Deleted ${selectedUsers.length} users and their data: ${selectedUsers.map((u) => u['customer_email']).join(', ')}');

                if (!mounted) return;
                setState(() {
                  _users.removeWhere((u) => u['isChecked'] == true);
                  _allSelected = false;
                  _isSelectionMode = false;
                });
                snackbar('Successfully deleted ${selectedUsers.length} users and their data', Colors.green);
              } catch (e) {
                if (mounted) snackbar('Batch delete error: $e', Colors.red);
              }
            },
            child: const Text('Delete All Selected'),
          ),
        ],
      ),
    );
  }

  Future<void> _editUser(int index) async {
    final user = _users[index];
    final TextEditingController nameController = TextEditingController(text: user['customer_name']);
    final TextEditingController emailController = TextEditingController(text: user['customer_email']);
    final TextEditingController sellerNameController = TextEditingController(text: user['seller_name']);


    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _EditUserDialog(
          user: user,
          onSave: (updatedData) {
            if (mounted) {
              setState(() {
                _users[index]['customer_name'] = updatedData['username'];
                _users[index]['customer_email'] = updatedData['email'];
                _users[index]['customer_verified'] = updatedData['customer_verified'] ? 'Verified' : 'Not Verified';
                _users[index]['seller_name'] = updatedData['is_seller'] ? updatedData['shop_name'] : '';
                _users[index]['is_seller'] = updatedData['is_seller'];
                _users[index]['seller_status'] = updatedData['is_seller'] ? 'Registered' : 'Unregistered';
              });
            }
          },
        );
      },
    );

    // Clean up
    nameController.dispose();
    emailController.dispose();
    sellerNameController.dispose();
  }


  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    snackbar('Copied to clipboard', Colors.green);
  }

  Widget _buildDetailRow(String label, Widget content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: content,
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    if (status.isEmpty) return const SizedBox.shrink();

    Color textColor;
    Color bgColor;
    Color dotColor;

    // Normalize status for comparison
    final String normalizedStatus = status.trim();

    if (normalizedStatus == 'Verified' || normalizedStatus == 'Registered' || normalizedStatus.toLowerCase().contains('success')) {
      textColor = const Color(0xFF1B5E20); // Dark green
      bgColor = Colors.white;
      dotColor = const Color(0xFF4CAF50); // Green
    } else if (normalizedStatus == 'Not Verified' || normalizedStatus == 'Unregistered' || normalizedStatus.toLowerCase().contains('fail')) {
      textColor = const Color(0xFFD32F2F); // Dark Red
      bgColor = Colors.white;
      dotColor = const Color(0xFFF44336); // Red
    } else if (normalizedStatus.toLowerCase().contains('pending')) {
      textColor = const Color(0xFFE65100); // Dark Orange/Yellow
      bgColor = Colors.white;
      dotColor = const Color(0xFFFFB300); // Amber/Yellow
    } else {
      // Default (e.g., empty or other)
      textColor = const Color(0xFF616161); // Grey
      bgColor = Colors.white;
      dotColor = const Color(0xFF9E9E9E); // Grey
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_users.where((u) => u['isChecked'] == true).length} Selected', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))
            : const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        foregroundColor: Colors.black87,
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _isSelectionMode = false;
              _allSelected = false;
              for (var u in _users) {
                u['isChecked'] = false;
              }
            });
          },
        )
            : null,
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
      floatingActionButton: _users.any((u) => u['isChecked'] == true)
          ? FloatingActionButton.extended(
        onPressed: _batchDelete,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.delete_sweep, color: Colors.white),
        label: Text(
          'Delete Selected (${_users.where((u) => u['isChecked'] == true).length})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchUsers,
          color: Colors.lightBlue,
          child: Column(
            children: [
              _buildSearchAndFilter(),
              Expanded(
                child: _isLoading
                    ? _buildUserSkeleton()
                    : _users.isEmpty
                    ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No users found.'))])
                    : _buildUserList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: BaseSkeleton(width: double.infinity, height: 160, borderRadius: 16, isDarkOverride: false),
        );
      },
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Name, Email, or UUID...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.lightBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.toLowerCase());
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Customer', 'Seller'].map((role) {
                      final isSelected = _filterRole == role;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(role),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _filterRole = role);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.lightBlue.shade50,
                          checkmarkColor: Colors.lightBlue,
                          labelStyle: TextStyle(
                              color: isSelected ? Colors.lightBlue : Colors.grey.shade700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? Colors.lightBlue : Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildUserList() {
    final filteredUsers = _users.where((u) {
      final matchesSearch = u['customer_name'].toString().toLowerCase().contains(_searchQuery) ||
          u['customer_email'].toString().toLowerCase().contains(_searchQuery) ||
          u['id'].toString().toLowerCase().contains(_searchQuery);

      final matchesRole = _filterRole == 'All' ||
          (_filterRole == 'Customer' && u['is_seller'] != true) ||
          (_filterRole == 'Seller' && u['is_seller'] == true);

      return matchesSearch && matchesRole;
    }).toList();

    final List<Map<String, dynamic>> customers = filteredUsers.where((u) => u['is_seller'] != true).toList();
    final List<Map<String, dynamic>> sellers = filteredUsers.where((u) => u['is_seller'] == true).toList();

    if (filteredUsers.isEmpty) return const Center(child: Text('No matches found.'));

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        if (_isSelectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _allSelected = !_allSelected;
                  for (var user in _users) {
                    final bool matchesRole = _filterRole == 'All' ||
                        (_filterRole == 'Customer' && user['is_seller'] != true) ||
                        (_filterRole == 'Seller' && user['is_seller'] == true);

                    if (matchesRole) {
                      user['isChecked'] = _allSelected;
                    }
                  }
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _allSelected,
                      activeColor: const Color(0xFF1976D2),
                      onChanged: (val) {
                        setState(() {
                          _allSelected = val ?? false;
                          for (var user in _users) {
                            final bool matchesRole = _filterRole == 'All' ||
                                (_filterRole == 'Customer' && user['is_seller'] != true) ||
                                (_filterRole == 'Seller' && user['is_seller'] == true);

                            if (matchesRole) {
                              user['isChecked'] = _allSelected;
                            }
                          }
                        });
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Select All Visible', style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        if (customers.isNotEmpty) ...[
          _buildCategoryHeader('Customer'),
          ...customers.map((user) => _buildUserCard(user, _users.indexOf(user))),
          const SizedBox(height: 24),
        ],
        if (sellers.isNotEmpty) ...[
          _buildCategoryHeader('Seller'),
          ...sellers.map((user) => _buildUserCard(user, _users.indexOf(user))),
          const SizedBox(height: 32),
        ],
        if (_isFetchingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 60,
            color: title == 'Seller' ? Colors.orange : Colors.blue,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final bool isSeller = user['is_seller'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            user['isChecked'] = true;
          });
        },
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              user['isChecked'] = !(user['isChecked'] ?? false);
              // If nothing selected, maybe exit mode?
              if (!_users.any((u) => u['isChecked'] == true)) {
                _isSelectionMode = false;
              }
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  if (_isSelectionMode) ...[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: user['isChecked'] ?? false,
                        activeColor: Colors.lightBlue,
                        onChanged: (bool? value) {
                          setState(() {
                            user['isChecked'] = value;
                            if (!_users.any((u) => u['isChecked'] == true)) {
                              _isSelectionMode = false;
                            }
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(color: Color(0xFFBDBDBD)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      user['id'].toString().length > 8
                          ? user['id'].toString().substring(0, 8).toUpperCase()
                          : user['id'].toString().toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF212121),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 20, color: Color(0xFF757575)),
                    onPressed: () => _copyToClipboard(user['id']),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF757575)),
                    onPressed: () => _deleteUser(index),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF757575)),
                    onPressed: () => _editUser(index),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // CUSTOMER SECTION
              const Text(
                'CUSTOMER INFO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),

              _buildDetailRow(
                'Customer',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['customer_name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF212121)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user['customer_email'],
                      style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
              ),

              _buildDetailRow(
                'Profile',
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE3F2FD),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (user['user_pic']?.toString() ?? '').isNotEmpty
                      ? Image.network(user['user_pic']!.toString().split(',')[0], fit: BoxFit.contain)
                      : (user['google_pic']?.toString() ?? '').isNotEmpty
                      ? Image.network(user['google_pic']!.toString().split(',')[0], fit: BoxFit.contain)
                      : const Icon(Icons.person, size: 18, color: Color(0xFF1E88E5)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
              ),

              _buildDetailRow(
                'Status',
                _buildStatusChip(user['customer_verified']),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
              ),

              _buildDetailRow(
                'Date & Time',
                Text(
                  user['customer_joined_at'],
                  style: const TextStyle(fontSize: 13, color: Color(0xFF424242)),
                ),
              ),

              if (isSeller) ...[
                const SizedBox(height: 24),
                // SELLER SECTION
                const Text(
                  'SELLER INFO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),

                _buildDetailRow(
                  'Seller',
                  Text(
                    user['seller_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF212121)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                ),

                _buildDetailRow(
                  'Status',
                  _buildStatusChip(user['seller_status']),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                ),

                _buildDetailRow(
                  'Profile',
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFF3E0),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (user['shop_pic']?.toString() ?? '').isNotEmpty
                        ? Image.network(user['shop_pic']!.toString().split(',')[0], fit: BoxFit.contain)
                        : const Icon(Icons.store, size: 18, color: Color(0xFFF57C00)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                ),

                _buildDetailRow(
                  'Date & Time',
                  Text(
                    user['seller_joined_at'],
                    style: const TextStyle(fontSize: 13, color: Color(0xFF424242)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onSave;

  const _EditUserDialog({required this.user, required this.onSave});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController sellerNameController;
  late String customerVerified;
  late String sellerStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user['customer_name']);
    emailController = TextEditingController(text: widget.user['customer_email']);
    sellerNameController = TextEditingController(text: widget.user['seller_name']);
    customerVerified = widget.user['customer_verified'] == 'Verified' ? 'Verified' : 'Not Verified';
    sellerStatus = widget.user['seller_status'] == 'Registered' ? 'Registered' : 'Unregistered';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    sellerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customer Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: customerVerified,
              decoration: InputDecoration(
                labelText: 'Account Verification',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: ['Verified', 'Not Verified'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (val) => setState(() => customerVerified = val!),
            ),
            const SizedBox(height: 24),
            const Text('Seller Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 12),
            TextField(
              controller: sellerNameController,
              decoration: InputDecoration(
                labelText: 'Shop Name',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: sellerStatus,
              decoration: InputDecoration(
                labelText: 'Seller Registration',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: ['Registered', 'Unregistered'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (val) => setState(() => sellerStatus = val!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Changes'),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final updateData = {
        'username': nameController.text.trim(),
        'email': emailController.text.trim(),
        'customer_verified': customerVerified == 'Verified',
        'shop_name': sellerStatus == 'Registered' ? sellerNameController.text.trim() : null,
        'is_seller': sellerStatus == 'Registered',
      };

      await supabase.from('user').update(updateData).eq('id', widget.user['id']);

      widget.onSave(updateData);

      if (mounted) {
        // Important: unfocus to avoid "dirty widget" error with keyboard animations
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
        snackbar('User updated successfully', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        snackbar('Error updating user: $e', Colors.red);
      }
    }
  }
}
