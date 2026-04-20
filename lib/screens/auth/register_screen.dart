import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import '../core/home_screen.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  // Google Registration State
  bool _isCompletingGoogleAuth = false;
  GoogleSignInAccount? _googleMetadata;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false; // Global loading to disable UI
  bool _isTraditionalLoading = false; // For register button morphing
  bool _isGoogleLoading = false; // For Google sign-in specific state
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    // Premium reveal: show shimmer for 800ms on first load
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isInitialLoading = false);
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    String username = _usernameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      snackbar('Please fill in all fields!', Colors.red);
      return;
    }

    if (password != confirmPassword) {
      snackbar('Passwords do not match!', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _isTraditionalLoading = true;
    });

    try {
      if (_isCompletingGoogleAuth && _googleMetadata != null) {
        // Finishing a Google registration with a password
        await _authService.finalizeGoogleRegistration(
          googleMetadata: _googleMetadata!,
          password: password,
        );
        if (mounted) {
          snackbar('Registration Successful!', Colors.green);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Traditional registration
        final supabase = Supabase.instance.client;
        await supabase.from('user').insert({
          'email': email,
          'password': password,
          'username': username,
          'password_custom': true,
          'appearance': 0, // 0: system, 1: light, 2: dark
        });

        if (mounted) {
          snackbar('Registration Successful!', Colors.green);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        snackbar('Error: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isTraditionalLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _isGoogleLoading = true;
    });
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) return;

      if (result.isNewUser && result.googleMetadata != null) {
        // Ask if they want a password
        if (mounted) {
          _showPasswordOptionDialog(result.googleMetadata!);
        }
      } else if (result.userData != null) {
        // Existing user - go Home
        if (mounted) {
          snackbar('Login Successful!', Colors.green);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) snackbar('Google Sign-In Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _showPasswordOptionDialog(GoogleSignInAccount metadata) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BackdropFilter(
        filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.1), BlendMode.darken),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fancy Icon Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded, size: 40, color: Colors.lightBlue),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Add a Password?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Would you like to add a password or you can skip it for later.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext); // Use dialogContext for the pop
                          setState(() => _isLoading = true);
                          try {
                            // Generate temporary password
                            final tempPassword = AuthService.generateSecurePassword();

                            await _authService.finalizeGoogleRegistration(
                              googleMetadata: metadata,
                              password: tempPassword,
                            );

                            if (mounted) {
                              _showPasswordRevealDialog(tempPassword);
                            }
                          } catch (e) {
                            if (mounted) snackbar('Error: $e', Colors.red);
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.grey.shade700,
                        ),
                        child: const Text('No, Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext); // Use dialogContext for the pop
                          // Switch UI to show password fields
                          setState(() {
                            _isCompletingGoogleAuth = true;
                            _googleMetadata = metadata;
                            _usernameController.text = metadata.displayName ?? metadata.email.split('@')[0];
                            _emailController.text = metadata.email;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Yes, Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordRevealDialog(String generatedPassword) {
    bool isVisible = false;
    final String obfuscatedDots = '●' * (Random().nextInt(5) + 4); // Random dots between 4-8
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.1), BlendMode.darken),
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Account Secured!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We\'ve generated a temporary password for your security. You can change this later in settings.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            isVisible ? generatedPassword : obfuscatedDots,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: isVisible ? 1.5 : 3,
                              fontFamily: isVisible ? 'Courier' : null,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey, size: 20),
                              onPressed: () => setDialogState(() => isVisible = !isVisible),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.content_copy, color: Colors.grey, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: generatedPassword));
                                snackbar('Password copied to clipboard!', Colors.blue);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // Close dialog
                        snackbar('Registration Successful!', Colors.green);
                        Navigator.pushReplacement(
                          context, // Use RegisterScreen's context for Home
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Start Exploring', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: const RegisterSkeleton(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCompletingGoogleAuth ? 'Set Password' : 'Create Account'),
        leading: _isCompletingGoogleAuth
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _isCompletingGoogleAuth = false),
        )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
                _isCompletingGoogleAuth ? Icons.lock_outline : Icons.person_add,
                size: 60,
                color: Colors.lightBlue
            ),
            const SizedBox(height: 16),
            Text(
              _isCompletingGoogleAuth ? 'Secure Your Account' : 'Register Account',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_isCompletingGoogleAuth
                ? 'Fill in your account with a password.'
                : 'Start selling and buying in seconds'
            ),
            const SizedBox(height: 32),

            if (!_isCompletingGoogleAuth) ...[
              // Custom Animated Google Sign-In Button
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isGoogleLoading ? 54 : MediaQuery.of(context).size.width - 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_isGoogleLoading ? 24 : 8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: _isLoading ? null : _handleGoogleSignIn,
                    borderRadius: BorderRadius.circular(_isGoogleLoading ? 24 : 8),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isGoogleLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.lightBlue,
                          ),
                        )
                            : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 16),
                              Image.network(
                                'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                                height: 20,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Continue with Google",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Divider
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // Username
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Password (Shown in both flows)
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password (Shown in both flows)
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Register button
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: _isTraditionalLoading ? 54 : MediaQuery.of(context).size.width - 48,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_isTraditionalLoading ? 27 : 12),
                    ),
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isTraditionalLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Text(
                        _isCompletingGoogleAuth ? 'Complete Registration' : 'Register',
                        key: ValueKey(_isCompletingGoogleAuth ? 'complete' : 'register'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
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