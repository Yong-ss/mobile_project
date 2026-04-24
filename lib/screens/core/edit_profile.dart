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

  // Password visibility states
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

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

    if (newPass.isEmpty || confirmPass.isEmpty) {
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
        await supabase.auth.updateUser(UserAttributes(password: newPass));
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

    // Reset visibility states when opening
    setState(() {
      _obscureOld = true;
      _obscureNew = true;
      _obscureConfirm = true;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool isDark = Theme.of(context).brightness == Brightness.dark;
          final bool hasOldPass = currentUser!['password_custom'] ?? false;

          Widget buildPasswordField({
            required TextEditingController controller,
            required String label,
            required bool isObscured,
            required VoidCallback onToggle,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextField(
                controller: controller,
                obscureText: isObscured,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                    onPressed: onToggle,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Row(
              children: [
                const Icon(Icons.security, color: Colors.lightBlue, size: 28),
                const SizedBox(width: 12),
                Text(
                  t('change_password'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  if (hasOldPass)
                    buildPasswordField(
                      controller: _oldPasswordController,
                      label: t('old_password'),
                      isObscured: _obscureOld,
                      onToggle: () => setDialogState(() => _obscureOld = !_obscureOld),
                    ),
                  buildPasswordField(
                    controller: _newPasswordController,
                    label: t('new_password'),
                    isObscured: _obscureNew,
                    onToggle: () => setDialogState(() => _obscureNew = !_obscureNew),
                  ),
                  buildPasswordField(
                    controller: _confirmPasswordController,
                    label: t('confirm_password'),
                    isObscured: _obscureConfirm,
                    onToggle: () => setDialogState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(t('cancel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handlePasswordChange,
                      child: Text(t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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
                        : (currentUser!['user_pic'] != null ||
                        currentUser!['google_profile_image'] !=
                            null)
                        ? NetworkImage(
                      (currentUser!['user_pic'] ??
                          currentUser!['google_profile_image'])
                          .toString()
                          .split(',')[0],
                    )
                        : null,
                    child: (_newImageUrl == null &&
                        currentUser!['user_pic'] == null &&
                        currentUser!['google_profile_image'] == null)
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
