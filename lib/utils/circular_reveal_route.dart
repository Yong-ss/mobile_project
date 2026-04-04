import 'dart:math';
import 'dart:ui'; //(import ui library to use ImageFilter)
import 'package:flutter/material.dart';

/// A custom page route that reveals the new page using a circular growth animation
/// starting from a specific [centerOffset].
class CircularRevealPageRoute extends PageRouteBuilder {
  final Widget page;
  final Offset centerOffset;

  /// (static jump method: just pass the Key to automatically calculate the coordinates and jump)
  static void push(BuildContext context, GlobalKey key, Widget page) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset center = renderBox.localToGlobal(
      renderBox.size.center(Offset.zero),
    );

    Navigator.push(
      context,
      CircularRevealPageRoute(page: page, centerOffset: center),
    );
  }

  CircularRevealPageRoute({required this.page, required this.centerOffset})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        opaque: false, // important: set to false to see the page below and blur
        barrierDismissible: true,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // (fast at the beginning, slow at the end) - Adjusted to Cubic for smoother start
          final Animation<double> curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return Stack(
            children: [
              // 1. blur
              AnimatedBuilder(
                animation: curvedAnimation,
                builder: (context, _) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: curvedAnimation.value * 5.0,
                      sigmaY: curvedAnimation.value * 5.0,
                    ),
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: curvedAnimation.value * 0.1,
                      ),
                    ),
                  );
                },
              ),
              // 2. circle reveal (no fade in, 100% opacity)
              AnimatedBuilder(
                animation: curvedAnimation,
                builder: (context, child) {
                  return ClipPath(
                    clipper: CircularRevealClipper(
                      fraction: curvedAnimation.value,
                      center: centerOffset,
                    ),
                    child: child,
                  );
                },
                child: child,
              ),
            ],
          );
        },
      );
}

class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;

  CircularRevealClipper({required this.fraction, required this.center});

  @override
  Path getClip(Size size) {
    // Calculate the maximum radius needed to cover the screen from the center point
    final double maxRadius = _calculateMaxRadius(size, center);
    final double radius = maxRadius * fraction;

    final Path path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  double _calculateMaxRadius(Size size, Offset center) {
    // Find the furthest corner from the center point
    final double dx = max(center.dx, size.width - center.dx);
    final double dy = max(center.dy, size.height - center.dy);
    return sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldReclip(CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction || oldClipper.center != center;
  }
}
