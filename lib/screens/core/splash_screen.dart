import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../auth/login_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../utils/globals.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _blurAnimation = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // Navigate after animation
    Timer(const Duration(milliseconds: 3000), _navigateToNext);
  }

  void _navigateToNext() {
    if (!mounted) return;

    Widget nextScreen;
    if (currentUser == null) {
      nextScreen = const LoginScreen();
    } else if (currentUser!['role'] == 'admin') {
      nextScreen = const AdminDashboardScreen();
    } else {
      nextScreen = const HomeScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background pattern or subtle gradient (Optional)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The Animated Logo
                    Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _blurAnimation.value,
                            sigmaY: _blurAnimation.value,
                          ),
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.lightBlue.withValues(alpha: 0.2 * _fadeAnimation.value),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback icon if logo is missing during setup
                                return const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 100,
                                  color: Colors.lightBlue,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Optional: App Name or Loading Indicator
                    Opacity(
                      opacity: (_controller.value > 0.7 ? (_controller.value - 0.7) / 0.3 : 0.0).clamp(0.0, 1.0),
                      child: Column(
                        children: [
                          const Text(
                            'PRISCON',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Color(0xFF0091CC),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Simple Marketplace for Small Sellers',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withValues(alpha: 0.7),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
