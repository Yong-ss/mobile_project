import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/snackbar_helper.dart';

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
  String? _newImageUrl; // 存刚才传好的 URL，用来做预览
  bool _isUploading = false; // 上传时的转圈圈标志

  @override
  void initState() {
    super.initState();

    if (currentUser != null) {
      _nameController.text = currentUser!['username'] ?? '';
      _emailController.text = currentUser!['email'] ?? '';
    }
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
      snackbar('Please fill all fields', Colors.red);
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
        snackbar('Profile updated successfully!', Colors.green);
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

    if (confirmPass != newPass || newPass != confirmPass) {
      snackbar('New Password and Confirm Password not match !', Colors.red);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final userData = await supabase
          .from('user')
          .select('password')
          .eq('id', currentUser!['id'])
          .single();

      if (userData['password'] != oldPass) {
        snackbar('Old password is incorrect!', Colors.red);
        return;
      }

      if (newPass == oldPass) {
        snackbar('New password is same as old password!', Colors.red);
        return;
      }

      await supabase
          .from('user')
          .update({'password': newPass})
          .eq('id', currentUser!['id']);

      if (mounted) {
        Navigator.pop(context);
        snackbar('Password changed!', Colors.green);
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
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPasswordController,
              decoration: const InputDecoration(labelText: 'Old Password'),
              obscureText: true,
            ),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _handlePasswordChange, // 处理函数
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 自定义头像预览
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: _newImageUrl != null
                        ? NetworkImage(_newImageUrl!)
                        : (currentUser!['user_pic'] != null &&
                                  currentUser!['user_pic'].toString().isNotEmpty
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
                labelText: 'Username',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListTile(
                leading: const Icon(Icons.lock_reset, color: Colors.lightBlue),
                title: const Text('Password Settings'),
                subtitle: const Text('Tap to change your password'),
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
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
