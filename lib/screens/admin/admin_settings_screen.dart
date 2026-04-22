import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialLoading = true;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController.text = currentUser?['username'] ?? '';
    _simulateLoading();
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isInitialLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      snackbar('Display name cannot be empty', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl = currentUser?['user_pic'];

      // 1. Upload Image if changed
      if (_imageFile != null) {
        final fileName = 'admin_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = 'avatars/$fileName';

        await _supabase.storage.from('avatars').upload(path, _imageFile!);
        imageUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      }

      // 2. Update DB
      await _supabase.from('user').update({
        'username': _nameController.text.trim(),
        'user_pic': imageUrl,
      }).eq('id', currentUser!['id']);

      // 3. Update local global
      currentUser!['username'] = _nameController.text.trim();
      currentUser!['user_pic'] = imageUrl;

      if (mounted) {
        snackbar('Profile updated successfully', Colors.green);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) snackbar('Failed to update profile: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    // 1. Validate Admin Role
    if (currentUser?['role'] != 'admin') {
      snackbar('Unauthorized: Only administrators can modify security settings here.', Colors.red);
      return;
    }

    final TextEditingController newPasswordController = TextEditingController();

    // 2. Show Direct Password Change Dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Admin Password'),
        content: TextField(
          controller: newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Password',
            hintText: 'Enter at least 6 characters',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text.trim().length < 6) {
                snackbar('Password must be at least 6 characters', Colors.orange);
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final newPass = newPasswordController.text.trim();

        // Update REAL Supabase Auth
        await _supabase.auth.updateUser(UserAttributes(password: newPass));

        // Update manual table for sync
        await _supabase.from('user').update({'password': newPass}).eq('id', currentUser!['id']);

        if (mounted) {
          snackbar('Password updated successfully', Colors.green);
        }
      } catch (e) {
        debugPrint('Password update error: $e');
        if (mounted) snackbar('Failed to update password: $e', Colors.red);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = currentUser?['user_pic'];

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Profile Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          foregroundColor: Colors.black87,
          elevation: 0,
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
          child: _isInitialLoading
              ? _buildProfileSkeleton()
              : SingleChildScrollView(
            child: Column(
              children: [
                // --- Header / Avatar ---
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.lightBlue, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.only(bottom: 40, top: 20),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white,
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? NetworkImage(avatarUrl) as ImageProvider
                                  : null,
                              child: (_imageFile == null && (avatarUrl == null || avatarUrl.isEmpty))
                                  ? const Icon(Icons.person, size: 60, color: Colors.blueGrey)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Color(0xFF1565C0), size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentUser?['username'] ?? 'Administrator',
                        style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        currentUser?['email'] ?? '',
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Personal Information'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Display Name',
                        controller: _nameController,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Email Address',
                        initialValue: currentUser?['email'],
                        icon: Icons.email_outlined,
                        enabled: false,
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader('Security & Account'),
                      const SizedBox(height: 16),
                      _buildActionTile(
                        title: 'Change Password',
                        subtitle: 'Update your login credentials',
                        icon: Icons.lock_outline,
                        onTap: _changePassword,
                      ),
                      const SizedBox(height: 40),

                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: const Text('Save Profile Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const BaseSkeleton(width: 120, height: 120, borderRadius: 60),
          const SizedBox(height: 24),
          const BaseSkeleton(width: 200, height: 20, borderRadius: 8),
          const SizedBox(height: 8),
          const BaseSkeleton(width: 150, height: 14, borderRadius: 8),
          const SizedBox(height: 48),
          ...List.generate(3, (index) => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: BaseSkeleton(width: double.infinity, height: 80, borderRadius: 16),
          )),
          const SizedBox(height: 32),
          const BaseSkeleton(width: double.infinity, height: 54, borderRadius: 12),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    required IconData icon,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.lightBlue.shade700),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildActionTile({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.lightBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.lightBlue.shade700, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
