import 'package:flutter/material.dart';
import '../order/seller_orders_screen.dart';
import '../product/my_listings_screen.dart';
import '../dashboard/sales_dashboard_screen.dart';
import '../../utils/globals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class SellerCentralScreen extends StatefulWidget {
  final String shopName;

  const SellerCentralScreen({super.key, required this.shopName});

  @override
  State<SellerCentralScreen> createState() => _SellerCentralScreenState();
}

class _SellerCentralScreenState extends State<SellerCentralScreen> {
  late String _currentShopName;
  final TextEditingController _shopNameController = TextEditingController();
  String _shopCreatedAt = '';

  @override
  void initState() {
    super.initState();
    _currentShopName = currentUser!['shop_name'] ?? '';
    _shopCreatedAt = currentUser!['shop_created_at']?.toString() ?? 'Unknown';
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  String? _newShopPicUrl;
  bool _isUploadingLogo = false;

  void _showEditShopDialog() {
    _shopNameController.text = _currentShopName;
    _newShopPicUrl = null; // 重置预览链接

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Shop Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage:
                          (_newShopPicUrl != null && _newShopPicUrl!.isNotEmpty)
                          ? NetworkImage(_newShopPicUrl!)
                          : (currentUser!['shop_pic'] != null &&
                                    currentUser!['shop_pic']
                                        .toString()
                                        .isNotEmpty
                                ? NetworkImage(currentUser!['shop_pic'])
                                : null),
                      child:
                          ((_newShopPicUrl == null ||
                                  _newShopPicUrl!.isEmpty) &&
                              (currentUser!['shop_pic'] == null ||
                                  currentUser!['shop_pic'].toString().isEmpty))
                          ? const Icon(Icons.store, size: 40)
                          : null,
                    ),
                    if (_isUploadingLogo)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
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
                          onPressed: () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image == null) return;

                            setDialogState(() => _isUploadingLogo = true);

                            try {
                              final supabase = Supabase.instance.client;
                              final path =
                                  'avatars/${currentUser!['id']}/shop_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              final bytes = await image.readAsBytes();

                              await supabase.storage
                                  .from('avatars')
                                  .uploadBinary(path, bytes);

                              final imageUrl = supabase.storage
                                  .from('avatars')
                                  .getPublicUrl(path);

                              // 同步外部和弹窗内部状态
                              setState(() => _newShopPicUrl = imageUrl);
                              setDialogState(() {
                                _isUploadingLogo = false;
                              });
                            } catch (e) {
                              setDialogState(() => _isUploadingLogo = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Upload failed: $e')),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
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
                onPressed: () {
                  _newShopPicUrl = null;
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isUploadingLogo
                    ? null
                    : () async {
                        final newShopName = _shopNameController.text.trim();
                        if (newShopName.isEmpty) return;

                        try {
                          final supabase = Supabase.instance.client;
                          Map<String, dynamic> updateData = {
                            'shop_name': newShopName,
                          };
                          if (_newShopPicUrl != null) {
                            updateData['shop_pic'] = _newShopPicUrl;
                          }

                          await supabase
                              .from('user')
                              .update(updateData)
                              .eq('id', currentUser!['id']);

                          setState(() {
                            _currentShopName = newShopName;
                            currentUser!.addAll(updateData);
                            _newShopPicUrl = null;
                          });

                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Save failed: $e')),
                          );
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Central'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditShopDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Shop Banner
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage:
                        (currentUser!['shop_pic'] != null &&
                            currentUser!['shop_pic'].toString().isNotEmpty)
                        ? NetworkImage(currentUser!['shop_pic'])
                        : null,
                    child:
                        (currentUser!['shop_pic'] == null ||
                            currentUser!['shop_pic'].toString().isEmpty)
                        ? const Icon(Icons.store, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentShopName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Created at: ${_shopCreatedAt.split('T')[0]}', 
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.blue),
              title: const Text('My Listings'),
              subtitle: const Text('View and manage your products'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyListingsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inbox, color: Colors.blue),
              title: const Text('Seller Orders'),
              subtitle: const Text('Manage incoming customer orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SellerOrdersScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.blue),
              title: const Text('Sales Dashboard'),
              subtitle: const Text('Track your earnings and performance'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalesDashboardScreen(),
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
