import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/translations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialLoading = true; // For shimmer reveal
  String? _newImageUrl; // 存刚才传好的 URL，用来做预览
  bool _isUploading = false; // 上传时的转圈圈标志

  @override
  void initState() {
    super.initState();

    if (currentUser != null) {
      _nameController.text = currentUser!['username'] ?? '';
      _emailController.text = currentUser!['email'] ?? '';
    }

    // Premium reveal strategy
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isInitialLoading = false);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    // 只从相册选
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = currentUser!['id'];

      // Use userId to name the folder, ensuring each user has only one folder
      final path =
          'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      // Upload image to Storage
      await supabase.storage.from('avatars').uploadBinary(path, bytes);

      //Fetch URL
      final String imageUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(path);

      // only update local variables, not database
      setState(() {
        _newImageUrl = imageUrl;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      snackbar('Upload error: $e', Colors.red);
    }
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();

    if (newName.isEmpty || newEmail.isEmpty) {
      snackbar(t('fill_all_fields'), Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      Map<String, dynamic> updateData = {
        'username': newName,
        'email': newEmail,
      };

      if (_newImageUrl != null) {
        updateData['user_pic'] = _newImageUrl;
      }

      await supabase
          .from('user')
          .update(updateData)
          .eq('id', currentUser!['id']);

      if (currentUser != null) {
        currentUser!['username'] = newName;
        currentUser!['email'] = newEmail;
      }

      if (_newImageUrl != null) {
        currentUser!['user_pic'] = _newImageUrl;
      }

      if (mounted) {
        Navigator.pop(context, true);
        snackbar(t('profile_updated'), Colors.green);
      }
    } catch (e) {
      if (mounted) {
        snackbar('Error: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordChange() async {
    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      snackbar(t('Please fill in all field'), Colors.red);
      return;
    }
    if (newPass != confirmPass) {
      snackbar(t('new set of password not match'), Colors.red);
      return;
    }
    if (newPass == oldPass) {
      snackbar(t('New password same as old password'), Colors.red);
      return;
    }
    if (newPass.length < 6 || confirmPass.length < 6) {
      snackbar(
        t('New password and confirm password must be at least 6 characters'),
        Colors.red,
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Check if user set their own password yet
      final bool isPasswordCustom = currentUser!['password_custom'] ?? false;

      if (isPasswordCustom) {
        final userData = await supabase
            .from('user')
            .select('password')
            .eq('id', currentUser!['id'])
            .single();

        if (userData['password'] != oldPass) {
          snackbar(t('incorrect_old_password'), Colors.red);
          return;
        }
      }

      // 1. Update Supabase Auth (official encrypted password)
      try {
        await supabase.auth.updateUser(
          UserAttributes(password: newPass),
        );
      } catch (e) {
        // Legacy users (like admin) don't have an auth.users record, skip silently
        debugPrint('Auth password update skipped: $e');
      }

      // 2. Update public.user (for Legacy fallback login)
      await supabase
          .from('user')
          .update({'password': newPass, 'password_custom': true})
          .eq('id', currentUser!['id']);

      // Update local state
      currentUser!['password_custom'] = true;

      if (mounted) {
        Navigator.pop(context);
        snackbar(t('Password changed successfully'), Colors.green);
      }
    } catch (e) {
      if (mounted) {
        snackbar('Error: $e', Colors.red);
      }
    }
  }

  void _showChangePasswordDialog() {
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('change_password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentUser!['password_custom'] ?? false)
              TextField(
                controller: _oldPasswordController,
                decoration: InputDecoration(labelText: t('old_password')),
                obscureText: true,
              ),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(labelText: t('new_password')),
              obscureText: true,
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(labelText: t('confirm_password')),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          ElevatedButton(
            onPressed: _handlePasswordChange, // 处理函数
            child: Text(t('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('edit_profile'))),
      body: _isInitialLoading
          ? const EditProfileSkeleton()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // 自定义头像预览
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.blue.shade50,
                          backgroundImage: _newImageUrl != null
                              ? NetworkImage(_newImageUrl!)
                              : (currentUser!['user_pic'] != null &&
                                        currentUser!['user_pic']
                                            .toString()
                                            .isNotEmpty
                                    ? NetworkImage(currentUser!['user_pic'])
                                    : null),
                          child:
                              (_newImageUrl == null &&
                                  currentUser!['user_pic'] == null)
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.lightBlue,
                                )
                              : null,
                        ),

                        if (_isUploading)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            backgroundColor: Colors.lightBlue,
                            radius: 20,
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: _pickAndUploadImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 表单字段
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: t('username'),
                      labelStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black54,
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.grey.shade300,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade50,
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: t('email_address'),
                      labelStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black54,
                      ),
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.grey.shade300,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.lock_reset,
                        color: Colors.lightBlue,
                      ),
                      title: Text(
                        t('password_settings'),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        t('tap_to_change_password'),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white38
                              : Colors.grey,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showChangePasswordDialog,
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _handleSave,
                      child: Text(
                        t('save_changes'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
