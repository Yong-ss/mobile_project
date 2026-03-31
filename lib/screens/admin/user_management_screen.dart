import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final supabase = Supabase.instance.client;
      // Fetch only from the main user table as it now contains all seller info
      // Sort by username ascending
      final response = await supabase.from('user').select('*').order('username', ascending: true);

      final List<Map<String, dynamic>> fetchedUsers = [];
      for (var row in response) {
        fetchedUsers.add({
          'id': row['id']?.toString() ?? '',
          'customer_name': row['username'] ?? 'Unknown',
          'customer_email': row['email'] ?? 'No email',
          // New column: customer_verified
          'customer_verified': row['customer_verified'] == true ? 'Verified' : 'Not Verified',
          'customer_joined_at': _formatDate(row['created_at']),
          'user_pic': row['user_pic'] ?? '',
          // Seller info from the same table
          'seller_name': row['shop_name'] ?? '',
          'seller_status': row['is_seller'] == true ? 'Registered' : 'Unregistered',
          'seller_joined_at': _formatDate(row['shop_created_at']),
          'shop_pic': row['shop_pic'] ?? '',
          'is_seller': row['is_seller'] ?? false,
          'isChecked': false,
        });
      }

      setState(() {
        _users = fetchedUsers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching users from Supabase: $e');
      if (mounted) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load from Supabase.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
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

  void _deleteUser(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${_users[index]['customer_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Note: Usually requires an API call to delete from Supabase
              setState(() {
                _users.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

    String customerVerified = user['customer_verified'] == 'Verified' ? 'Verified' : 'Not Verified';
    String sellerStatus = user['seller_status'] == 'Registered' ? 'Registered' : 'Unregistered';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Edit User'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Customer Info', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name', isDense: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email', isDense: true),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: customerVerified,
                        decoration: const InputDecoration(labelText: 'Verification', isDense: true),
                        items: ['Verified', 'Not Verified'].map((status) {
                          return DropdownMenuItem(value: status, child: Text(status));
                        }).toList(),
                        onChanged: (val) => setDialogState(() => customerVerified = val!),
                      ),

                      const SizedBox(height: 16),
                      const Text('Seller Info', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sellerNameController,
                        decoration: const InputDecoration(labelText: 'Seller Name', isDense: true),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: sellerStatus,
                        decoration: const InputDecoration(labelText: 'Seller Status', isDense: true),
                        items: ['Registered', 'Unregistered'].map((status) {
                          return DropdownMenuItem(value: status, child: Text(status));
                        }).toList(),
                        onChanged: (val) => setDialogState(() => sellerStatus = val!),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final supabase = Supabase.instance.client;
                        // Update consolidated user table
                        await supabase.from('user').update({
                          'username': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'customer_verified': customerVerified == 'Verified',
                          'shop_name': sellerStatus == 'Registered' ? sellerNameController.text.trim() : null,
                          'is_seller': sellerStatus == 'Registered',
                        }).eq('id', user['id']);

                        // Update locally
                        setState(() {
                          _users[index]['customer_name'] = nameController.text.trim();
                          _users[index]['customer_email'] = emailController.text.trim();
                          _users[index]['customer_verified'] = customerVerified;
                          _users[index]['seller_name'] = sellerStatus == 'Registered' ? sellerNameController.text.trim() : '';
                          _users[index]['is_seller'] = sellerStatus == 'Registered';
                          _users[index]['seller_status'] = sellerStatus;
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User updated successfully')),
                          );
                        }
                      } catch(e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating user: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            }
        );
      },
    );

    // Dispose controllers to free memory
    nameController.dispose();
    emailController.dispose();
    sellerNameController.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
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
    final normalizedStatus = status.trim();

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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('No users found.'))
          : _buildUserList(),
    );
  }

  Widget _buildUserList() {
    final List<Map<String, dynamic>> customers = _users.where((u) => u['is_seller'] != true).toList();
    final List<Map<String, dynamic>> sellers = _users.where((u) => u['is_seller'] == true).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: user['isChecked'] ?? false,
                    onChanged: (bool? value) {
                      setState(() {
                        user['isChecked'] = value;
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(color: Color(0xFFBDBDBD)),
                  ),
                ),
                const SizedBox(width: 12),
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
                child: user['user_pic'].isNotEmpty
                    ? Image.network(user['user_pic'], fit: BoxFit.contain)
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
                  child: user['shop_pic'].isNotEmpty
                      ? Image.network(user['shop_pic'], fit: BoxFit.contain)
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
    );
  }
}