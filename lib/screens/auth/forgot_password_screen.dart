import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';

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
      // If it doesn't have a standard dot (like try@) or you want to skip for manual testing
      bool isLegacy = !email.contains('.') || email.endsWith('@');

      if (isLegacy) {
        if (mounted) {
          snackbar('Legacy test account detected. Bypassing OTP...', Colors.lightBlue);
          _showResetPasswordDialog(context); // Straight to the dialog!
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
      body: SingleChildScrollView(
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
    );
  }

  void _showOTPDialog(BuildContext context) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter 6-Digit OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the code sent to your email.'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '00000000',
                counterText: '',
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
              final otp = otpController.text.trim();
              if (otp.length < 6) {
                snackbar('Please enter at least a 6-digit code', Colors.red);
                return;
              }
              try {
                // Verify the OTP (Works for 6 or 8 digits)
                await _authService.verifyPasswordResetOTP(_emailController.text.trim(), otp);

                if (context.mounted) {
                  Navigator.pop(context); // Close OTP dialog
                  // Show the ACTUAL reset password dialog right here!
                  _showResetPasswordDialog(context);
                }
              } catch (e) {
                snackbar('Invalid or expired OTP: $e', Colors.red);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController(); // Added confirm controller
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
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to login
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
                await _authService.signOut(); // Clean up session
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  snackbar('Password updated! Redirecting to login.', Colors.green);
                  Navigator.pop(context); // FINALLY go back to login
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