import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/translations.dart';
import '../../widgets/shimmer_skeletons.dart';

class SellerSettingsScreen extends StatefulWidget {
  const SellerSettingsScreen({super.key});

  @override
  State<SellerSettingsScreen> createState() => _SellerSettingsScreenState();
}

class _SellerSettingsScreenState extends State<SellerSettingsScreen> {
  final _shopNameController = TextEditingController();
  String? _newShopPicUrl;
  bool _isUploadingLogo = false;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _shopNameController.text = currentUser?['shop_name'] ?? '';

    // Premium Reveal Strategy: 800ms Shimmer
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploadingLogo = true);

    try {
      final supabase = Supabase.instance.client;
      final path = 'avatars/${currentUser!['id']}/shop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      await supabase.storage.from('avatars').uploadBinary(path, bytes);
      final imageUrl = supabase.storage.from('avatars').getPublicUrl(path);

      setState(() {
        _newShopPicUrl = imageUrl;
        _isUploadingLogo = false;
      });
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      snackbar('${t('error')}: $e', Colors.red);
    }
  }

  Future<void> _saveShopInfo() async {
    final newShopName = _shopNameController.text.trim();
    if (newShopName.isEmpty) return;

    setState(() => _isSaving = true);

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
        currentUser!.addAll(updateData);
        _isSaving = false;
      });

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate update
        snackbar('Shop information updated successfully!', Colors.green);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) snackbar('Save failed: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const SellerSettingsSkeleton()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Shop Profile'),
            const SizedBox(height: 12),
            _buildShopInfoCard(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveShopInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildShopInfoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildLogoPicker(),
          const SizedBox(height: 24),
          TextField(
            controller: _shopNameController,
            decoration: InputDecoration(
              labelText: t('shop_name'),
              prefixIcon: const Icon(Icons.store_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPicker() {
    final currentPic = _newShopPicUrl ?? currentUser?['shop_pic'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: isDark ? Colors.white10 : Colors.blue.shade50,
          backgroundImage: (currentPic != null && currentPic.toString().isNotEmpty)
              ? NetworkImage(currentPic)
              : null,
          child: (currentPic == null || currentPic.toString().isEmpty)
              ? Icon(Icons.store, size: 50, color: isDark ? Colors.white38 : Colors.blue)
              : null,
        ),
        if (_isUploadingLogo)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _pickAndUploadLogo,
            child: const CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 18,
              child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
