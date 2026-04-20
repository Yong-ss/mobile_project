import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      snackbar('Please enter your email address', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Check your manual 'user' table first
      final userData = await supabase
          .from('user')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (userData == null) {
        if (mounted) snackbar('No account found with this email address.', Colors.red);
        return;
      }

      // 2. Logic Check: Is this a 'Real' email or a 'Test/Legacy' one?
      bool isLegacy = !email.contains('.') || email.endsWith('@');

      if (isLegacy) {
        if (mounted) {
          snackbar('Legacy test account detected. Bypassing OTP...', Colors.lightBlue);
          _showResetPasswordDialog(context);
        }
      } else {
        // 3. Trigger the REAL Supabase Password Reset Email for real users
        await _authService.sendPasswordResetEmail(email);
        if (mounted) {
          snackbar('Reset link sent! Please check your email inbox.', Colors.green);
        }
      }
    } catch (e) {
      if (mounted) snackbar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const ForgotPasswordSkeleton()
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.email_outlined, size: 60, color: Colors.lightBlue),
              ),
              const SizedBox(height: 32),
              const Text(
                'Reset Password',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter your email address and we will verify your account to allow a password reset.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'example@gmail.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                    'Send Reset Link',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isLoading ? null : () => _showOTPDialog(context),
                child: const Text(
                  'Enter OTP for reset password',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to login page', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOTPDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OTPBoxDialog(
        email: _emailController.text.trim(),
        authService: _authService,
        onVerified: () => _showResetPasswordDialog(context),
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('New Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your identity is verified! Enter a new password.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPass = passwordController.text;
              final confirmPass = confirmController.text;

              if (newPass.length < 6) {
                snackbar('Password must be at least 6 characters', Colors.red);
                return;
              }

              if (newPass != confirmPass) {
                snackbar('Passwords do not match!', Colors.red);
                return;
              }

              try {
                await _authService.updatePassword(newPass);
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                  snackbar('Password updated! Redirecting to login.', Colors.green);
                  Navigator.pop(context);
                }
              } catch (e) {
                snackbar('Update failed: $e', Colors.red);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

class _OTPBoxDialog extends StatefulWidget {
  final String email;
  final AuthService authService;
  final VoidCallback onVerified;

  const _OTPBoxDialog({
    required this.email,
    required this.authService,
    required this.onVerified,
  });

  @override
  State<_OTPBoxDialog> createState() => _OTPBoxDialogState();
}

class _OTPBoxDialogState extends State<_OTPBoxDialog> {
  final List<TextEditingController> _controllers = List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(8, (_) => FocusNode());
  bool _isVerifying = false;

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Center(child: Text('Phone Number Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please enter OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(8, (index) => _buildBox(index)),
          ),
          const SizedBox(height: 16),
          const Text('Enter the code sent to your email.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              SizedBox(
                width: 140,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBox(int index) {
    return Container(
      width: 32,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _focusNodes[index].hasFocus ? Colors.lightBlue : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: _focusNodes[index].hasFocus ? [
          BoxShadow(color: Colors.lightBlue.withValues(alpha: 0.1), blurRadius: 4, spreadRadius: 1)
        ] : [],
      ),
      child: KeyboardListener(
        focusNode: FocusNode(), // Dummy focus node for listener
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].clear(); // Clear the previous number in the same click
            setState(() {}); // Update the UI to show the correct focus border
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          showCursor: false,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 7) {
              _focusNodes[index + 1].requestFocus();
            }
            setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _handleVerify() async {
    final otp = _otp;
    if (otp.length < 6) {
      if (mounted) snackbar('Please enter at least 6 digits', Colors.red);
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await widget.authService.verifyPasswordResetOTP(widget.email, otp);
      if (mounted) {
        Navigator.pop(context);
        widget.onVerified();
      }
    } catch (e) {
      if (mounted) snackbar('Verification failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }
}