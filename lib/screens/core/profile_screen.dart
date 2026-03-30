import 'package:flutter/material.dart';
import '../order/order_history_screen.dart';
import '../shop/seller_central_screen.dart';
import '../auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Loading...';
  String _email = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserData(); // 加载数据
  }

  Future<void> _loadUserData() async {
    final supabase = Supabase.instance.client;
    final userdata = supabase.auth.currentUser;

    if (userdata != null) {
      setState(() {
        _name = userdata.userMetadata?['username'] ?? 'Default Username';
        _email = userdata.email ?? 'Default Email';
      });
    }
  }
  // Personal Info State

  // Seller State
  bool _isSeller = false;
  String _shopName = '';

  // Controllers for dialogs
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    _nameController.text = _name;
    _emailController.text = _email;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo upload simulation
              Stack(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person, size: 40),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 14,
                      child: IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
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
                await supabase.auth.updateUser(
                  UserAttributes(
                    data: {
                      'username': _nameController.text.trim(),
                      'email': _emailController.text.trim(),
                    },
                  ),
                );
                setState(() {
                  _name = _nameController.text.trim();
                  _email = _emailController.text.trim();
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
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
            onPressed: () {
              if (_shopNameController.text.isNotEmpty) {
                setState(() {
                  _isSeller = true;
                  _shopName = _shopNameController.text;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Congratulations! "$_shopName" is now registered.',
                    ),
                  ),
                );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditProfileDialog,
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
                  const CircleAvatar(
                    radius: 48,
                    child: Icon(Icons.person, size: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(_email, style: const TextStyle(color: Colors.grey)),
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
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) =>
                      false, // This condition (false) tells Flutter to remove EVERY previous screen
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
