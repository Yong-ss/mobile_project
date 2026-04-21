import 'package:flutter/material.dart';
import '../chat/chat_list_screen.dart';
import '../order/order_history_screen.dart';
import '../shop/seller_central_screen.dart';
import '../auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../services/auth_service.dart';
import 'settings_screen.dart';
import '../order/to_pay_screen.dart';
import '../../utils/translations.dart';
import '../../widgets/chat_badge_icon.dart';


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
  String _applicationStatus = 'none';
  String _rejectionReason = '';
  bool _isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final response = await Supabase.instance.client
          .from('payments')
          .select('id')
          .eq('user_id', currentUser!['id'])
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _pendingCount = response.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending count: $e');
    }
  }

  Future<void> _loadUserData() async {
    if (currentUser != null) {
      setState(() {
        _showName = currentUser!['username'] ?? 'Load Username fail';
        _showEmail = currentUser!['email'] ?? 'Load Email fail';
        _isSeller = currentUser!['is_seller'] ?? false;
        _shopName = currentUser!['shop_name'] ?? 'Load Shop Name fail';

        // New fields for verification flow
        _applicationStatus = currentUser!['seller_application_status'] ?? 'none';
        _rejectionReason = currentUser!['rejection_reason'] ?? '';

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
        title: Text(t('register_seller')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('register_seller_sub')),
            const SizedBox(height: 16),
            TextField(
              controller: _shopNameController,
              decoration: InputDecoration(
                labelText: t('shop_name'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
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
                    'seller_application_status': 'pending',
                    'shop_name': shopNameInput,
                  })
                      .eq('id', currentUser!['id']);

                  // Update global and local state
                  setState(() {
                    _applicationStatus = 'pending';
                    currentUser!['seller_application_status'] = 'pending';
                    currentUser!['shop_name'] = shopNameInput;
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    snackbar(
                      'Application submitted! "$shopNameInput" is now awaiting admin approval.',
                      Colors.blue,
                    );
                  }
                } catch (e) {
                  snackbar('Error: $e', Colors.red);
                }
              }
            },
            child: Text(t('complete_registration')),
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
        title: Text(t('my_profile')),
        actions: [
          ChatBadgeIcon(
            isSellerMode: false,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              snackbar('Notifications coming soon!', Colors.blue);
            },
          ),
        ],
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
                                ? NetworkImage((currentUser!['user_pic'] ?? currentUser!['google_profile_image']).toString().split(',')[0])
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
              title: Text(t('my_orders')),
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
              if (_applicationStatus == 'pending')
                ListTile(
                  leading: const Icon(Icons.hourglass_empty, color: Colors.orange),
                  title: Text(
                    t('application_pending'), // You may need to add this to translations, or use hardcoded
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Your shop "$_shopName" is under review by admin.'),
                  trailing: const CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_applicationStatus == 'rejected')
                ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: Text(
                    'Application Rejected',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Reason: $_rejectionReason. Tap to re-apply.'),
                  trailing: const Icon(Icons.refresh, color: Colors.red),
                  onTap: _showBecomeSellerDialog,
                )
              else
                ListTile(
                  leading: const Icon(Icons.store, color: Colors.lightBlue),
                  title: Text(
                    t('become_seller'),
                    style: const TextStyle(color: Colors.lightBlue),
                  ),
                  subtitle: Text(t('start_listing_sub')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showBecomeSellerDialog,
                )
            else
              ListTile(
                leading: const Icon(
                  Icons.dashboard_customize,
                  color: Colors.green,
                ),
                title: Text(
                  t('seller_central'),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('${t('manage_shop')} "$_shopName"'),
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
              title: Text(t('to_pay')),
              subtitle: Text(t('awaiting_payment_sub')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ToPayScreen(),
                  ),
                );
                _loadPendingCount(); // Refresh count when coming back
              },
            ),
            const Divider(),

            // ── Demo Menu: Settings ──
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: Text(t('settings')),
              subtitle: Text(t('account_prefs')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _navigateToSettings,
            ),
            const Divider(),

            // ── Logout ──
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(t('logout'), style: const TextStyle(color: Colors.red)),
              onTap: () async {
                setState(() => _isLoading = true);
                try {
                  await AuthService().signOut();
                  if (context.mounted) {
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