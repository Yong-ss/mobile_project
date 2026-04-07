import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
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
  bool _isLoading = false;
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
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
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
      if (mounted) setState(() => _isLoading = false);
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
                          // Finalize immediately WITHOUT a password
                          setState(() => _isLoading = true);
                          try {
                            await _authService.finalizeGoogleRegistration(googleMetadata: metadata);
                            if (mounted) {
                              snackbar('Registration Successful!', Colors.green);
                              Navigator.pushReplacement(
                                context, // Use RegisterScreen's context for the main navigation
                                MaterialPageRoute(builder: (context) => const HomeScreen()),
                              );
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

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading || _isLoading) {
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
              // Google Sign-In (HCI: Social proof at the top)
              AbsorbPointer(
                absorbing: _isLoading,
                child: Opacity(
                  opacity: _isLoading ? 0.6 : 1.0,
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: SignInButton(
                      Buttons.google,
                      text: "Continue with Google",
                      onPressed: () => _handleGoogleSignIn(),
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

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerUser,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                      _isCompletingGoogleAuth ? 'Complete Registration' : 'Register',
                      style: const TextStyle(fontSize: 16)
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