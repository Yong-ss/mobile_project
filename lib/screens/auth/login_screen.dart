import 'package:flutter/material.dart';
import '../core/home_screen.dart';
import 'register_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/globals.dart';
import 'package:sign_in_button/sign_in_button.dart';
import '../../services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isPasswordVisible = false;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      snackbar('Please fill in all fields', Colors.red);
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final foundedData = await supabase
          .from('user')
          .select()
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();

      if (foundedData == null) {
        if (mounted) {
          snackbar('Invalid email or password!', Colors.red);
        }
      } else {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', foundedData['id']);
          await prefs.setString('user_email', foundedData['email']);
          await prefs.setString('user_name', foundedData['username']);

          currentUser = foundedData;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
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

      if (result.isNewUser) {
        // Redirection for new users to complete registration
        if (mounted) {
          snackbar('Account not found. Let\'s get you registered!', Colors.lightBlue);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        }
      } else if (result.userData != null) {
        if (mounted) {
          snackbar('Login Successful!', Colors.green);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) snackbar('Google Login Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading || _isLoading) {
      return const Scaffold(body: LoginSkeleton());
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo
              Image.network(
                'https://xwglzdiyzjmuukgvdbgu.supabase.co/storage/v1/object/public/announcements/images/logostri.png',
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.store, size: 80, color: Colors.lightBlue),
              ),
              SizedBox(height: 8),
              Text(
                'Priscon',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              Text('Simple Marketplace for Small Sellers'),
              const SizedBox(height: 32),

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
                      text: "Sign in with Google",
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

              // Email field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
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
              const SizedBox(height: 24),

              // Login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: _isLoading
                        ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Register link
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  );
                },
                child: Text("Don't have an account? Register"),
              ),

              // Admin Dashboard link
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminDashboardScreen(),
                    ),
                  );
                },
                child: Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.lightBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}