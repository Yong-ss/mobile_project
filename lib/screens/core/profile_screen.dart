import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../order/order_history_screen.dart';
import '../shop/seller_central_screen.dart';
import '../auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import 'edit_profile.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _showName = 'Loading...';
  String _showEmail = 'Loading...';
  bool _isSeller = false;
  String _shopName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser != null) {
      setState(() {
        _showName = currentUser!['username'] ?? 'Load Username fail';
        _showEmail = currentUser!['email'] ?? 'Load Email fail';
        _isSeller = currentUser!['is_seller'] ?? false;
        _shopName = currentUser!['shop_name'] ?? 'Load Shop Name fail';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // Controllers for dialogs
  final _shopNameController = TextEditingController();

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  void _navigateToEditProfile() async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );

    if (result == true) {
      _loadUserData();
    }
  }

  void _showBecomeSellerDialog() {
    _shopNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register as Seller'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your shop name to start selling.'),
            const SizedBox(height: 16),
            TextField(
              controller: _shopNameController,
              decoration: const InputDecoration(
                labelText: 'Shop Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_shopNameController.text.isNotEmpty) {
                final shopNameInput = _shopNameController.text.trim();
                try {
                  final supabase = Supabase.instance.client;

                  await supabase
                      .from('user')
                      .update({
                    'is_seller': true,
                    'shop_name': shopNameInput,
                    'shop_created_at': DateTime.now().toIso8601String(),
                  })
                      .eq('id', currentUser!['id']);

                  setState(() {
                    currentUser!['is_seller'] = true;
                    currentUser!['shop_name'] = shopNameInput;
                    _isSeller = true;
                    _shopName = shopNameInput;
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    snackbar(
                      'Congratulations! "$shopNameInput" is now registered.',
                      Colors.green,
                    );
                  }
                } catch (e) {
                  snackbar('Error: $e', Colors.red);
                }
              }
            },
            child: const Text('Complete Registration'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: ProfileSkeleton());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEditProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Avatar area (Buyer Info)
            Container(
              width: double.infinity,
              color: Colors.lightBlue.shade50,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: currentUser!['user_pic'] != null
                        ? NetworkImage(currentUser!['user_pic'])
                        : null,
                    child: currentUser!['user_pic'] == null
                        ? const Icon(
                      Icons.person,
                      size: 48,
                      color: Colors.lightBlue,
                    )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _showName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(_showEmail, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Common Buyer Menu ──
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('My Orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderHistoryScreen(),
                  ),
                );
              },
            ),
            const Divider(),

            // ── Seller Mode Toggle / Entry ──
            if (!_isSeller)
              ListTile(
                leading: const Icon(Icons.store, color: Colors.lightBlue),
                title: const Text(
                  'Become a Seller',
                  style: TextStyle(color: Colors.lightBlue),
                ),
                subtitle: const Text('Start listing products to sell'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showBecomeSellerDialog,
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.dashboard_customize,
                  color: Colors.green,
                ),
                title: const Text(
                  'Seller Central',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('Manage "$_shopName"'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SellerCentralScreen(shopName: _shopName),
                    ),
                  );
                },
              ),
            const Divider(),

            // ── Logout ──
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                // Clear state
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                currentUser = null;

                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                        (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}