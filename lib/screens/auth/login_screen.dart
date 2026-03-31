import 'package:flutter/material.dart';
import '../core/home_screen.dart';
import 'register_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/globals.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  Future<void> _login() async {
    try {
      final supabase = Supabase.instance.client;

      //find the speciic user with inserted email and password
      final foundedData = await supabase.from('user').select()
          .eq('email',_emailController.text.trim(),)
          .eq('password',_passwordController.text,)
          .maybeSingle();

      if (foundedData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password!'),
              backgroundColor: Colors.red,
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo
              Image.network(
                'https://xwglzdiyzjmuukgvdbgu.supabase.co/storage/v1/object/public/announcements/images/logostri.png',
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.store, size: 80, color: Colors.lightBlue),
              ),
              const SizedBox(height: 8),
              const Text(
                'Priscon',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text('Simple Marketplace for Small Sellers'),
              const SizedBox(height: 32),

              // Email field (Ch 3.1: TextField)
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),

              // Login button (Ch 3.1: ElevatedButton)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _login,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Register link
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text("Don't have an account? Register"),
              ),

              // Admin Dashboard link
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDashboardScreen(),
                    ),
                  );
                },
                child: const Text(
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