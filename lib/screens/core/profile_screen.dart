import 'package:flutter/material.dart';
import '../order/order_history_screen.dart';
import '../shop/seller_central_screen.dart';
import '../auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../services/auth_service.dart';
import 'settings_screen.dart';

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

  void _navigateToSettings() async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
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

  bool _isProfileExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (_isLoading || currentUser == null) {
      return const Scaffold(body: ProfileSkeleton());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Full-Banner Morph Header ──
            GestureDetector(
              onTap: () => setState(() => _isProfileExpanded = !_isProfileExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOutCubic,
                width: double.infinity,
                height: _isProfileExpanded ? 240 : 180, // Morph the banner height
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF303030)
                    : Colors.lightBlue.shade50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Morphing Profile Image (Circle ↔ Full Banner)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeInOutCubic,
                      top: _isProfileExpanded ? 0 : 20, // Bump up when collapsed
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeInOutCubic,
                        width: _isProfileExpanded
                            ? MediaQuery.of(context).size.width
                            : 96,
                        height: _isProfileExpanded ? 240 : 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_isProfileExpanded ? 0 : 48),
                          image: DecorationImage(
                            image: (currentUser!['user_pic'] != null || currentUser!['google_profile_image'] != null)
                                ? NetworkImage(currentUser!['user_pic'] ?? currentUser!['google_profile_image'])
                                : const AssetImage('assets/images/placeholder_avatar.png') as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: (currentUser!['user_pic'] == null && currentUser!['google_profile_image'] == null)
                            ? AnimatedOpacity(
                          opacity: _isProfileExpanded ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(Icons.person, size: 48, color: Colors.lightBlue),
                        )
                            : null,
                      ),
                    ),

                    // Name & Email with Slide-Fade Animation
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      bottom: _isProfileExpanded ? 0 : 16, // Extra padding when collapsed
                      child: ClipRect(
                        child: AnimatedOpacity(
                          opacity: _isProfileExpanded ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          child: AnimatedSlide(
                            offset: _isProfileExpanded ? const Offset(-0.3, 0) : Offset.zero,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutQuart,
                            child: Column(
                              children: [
                                Text(
                                  _showName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  _showEmail,
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

            // ── Demo Menu: To Pay ──
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.orange),
              title: const Text('To Pay'),
              subtitle: const Text('View orders awaiting payment'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => snackbar('To Pay feature coming soon!', Colors.blue),
            ),
            const Divider(),

            // ── Demo Menu: Settings ──
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Settings'),
              subtitle: const Text('Account and app preferences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _navigateToSettings,
            ),
            const Divider(),

            // ── Logout ──
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                setState(() => _isLoading = true);
                try {
                  await AuthService().signOut();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                          (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) snackbar('Logout failed: $e', Colors.red);
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}