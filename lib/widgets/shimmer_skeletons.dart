import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A foundational skeleton widget that provides the shimmer effect.
class BaseSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Widget? child;

  const BaseSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

/// A pre-made Banner Skeleton (e.g. for announcements).
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: BaseSkeleton(
        width: double.infinity,
        height: 180,
        borderRadius: 12,
      ),
    );
  }
}

/// A single Product Card Skeleton.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseSkeleton(
      width: double.infinity,
      height: double.infinity,
      borderRadius: 12,
    );
  }
}

/// A 2-column Grid of Product Skeletons.
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const ProductGridSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}

/// A Horizontal row of Circular Skeletons (e.g. for Categories).
class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 6,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                BaseSkeleton(width: 56, height: 56, borderRadius: 28),
                SizedBox(height: 8),
                BaseSkeleton(width: 48, height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A unified, full-screen Home Screen skeleton.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Area Shimmer
          Shimmer.fromColors(
            baseColor: Colors.lightBlue.shade100.withValues(alpha: 0.5),
            highlightColor: Colors.lightBlue.shade50,
            child: Container(
              width: double.infinity,
              height: 100,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Banner Shimmer
          const BannerSkeleton(),
          const SizedBox(height: 24),
          // Category Header & List
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: BaseSkeleton(width: 100, height: 20),
          ),
          const SizedBox(height: 12),
          const CategorySkeleton(),
          const SizedBox(height: 16),
          // Product Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BaseSkeleton(width: 120, height: 20),
                BaseSkeleton(width: 60, height: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Product Grid
          const ProductGridSkeleton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// A search bar skeleton.
class SearchBarSkeleton extends StatelessWidget {
  const SearchBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: BaseSkeleton(
        width: double.infinity,
        height: 54,
        borderRadius: 16,
      ),
    );
  }
}

/// A horizontal row of chip skeletons.
class ChipRowSkeleton extends StatelessWidget {
  const ChipRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(right: 12),
            child: BaseSkeleton(width: 80, height: 36, borderRadius: 20),
          );
        },
      ),
    );
  }
}

/// A unified, full-screen Shop Screen skeleton.
class ShopSkeleton extends StatelessWidget {
  const ShopSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SearchBarSkeleton(),
        ChipRowSkeleton(),
        SizedBox(height: 12),
        Expanded(child: ProductGridSkeleton()),
      ],
    );
  }
}

/// A unified, full-screen Product Details Screen skeleton.
class ProductDetailsSkeleton extends StatelessWidget {
  const ProductDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Image
          const BaseSkeleton(width: double.infinity, height: 300, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Price
                const BaseSkeleton(width: 250, height: 28),
                const SizedBox(height: 12),
                const BaseSkeleton(width: 120, height: 24),
                const SizedBox(height: 24),
                // Description Section
                const BaseSkeleton(width: 100, height: 18),
                const SizedBox(height: 12),
                const BaseSkeleton(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                const BaseSkeleton(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                const BaseSkeleton(width: 200, height: 14),
                const SizedBox(height: 32),
                // Seller Card Placeholder
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      BaseSkeleton(width: 40, height: 40, borderRadius: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BaseSkeleton(width: 120, height: 16),
                            SizedBox(height: 6),
                            BaseSkeleton(width: 80, height: 12),
                          ],
                        ),
                      ),
                      BaseSkeleton(width: 80, height: 30, borderRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Bottom Button
                const BaseSkeleton(width: double.infinity, height: 50, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A unified, full-screen Profile Screen skeleton.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header Area Shimmer
          Shimmer.fromColors(
            baseColor: Colors.lightBlue.shade100.withValues(alpha: 0.5),
            highlightColor: Colors.lightBlue.shade50,
            child: Container(
              width: double.infinity,
              height: 200,
              color: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BaseSkeleton(width: 96, height: 96, borderRadius: 48),
                  SizedBox(height: 12),
                  BaseSkeleton(width: 150, height: 20),
                  SizedBox(height: 8),
                  BaseSkeleton(width: 180, height: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Menu Items Skeletons
          _buildMenuItemSkeleton(),
          const Divider(),
          _buildMenuItemSkeleton(),
          const Divider(),
          _buildMenuItemSkeleton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMenuItemSkeleton() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          BaseSkeleton(width: 24, height: 24, borderRadius: 4),
          SizedBox(width: 16),
          BaseSkeleton(width: 120, height: 16),
          Spacer(),
          BaseSkeleton(width: 16, height: 16, borderRadius: 8),
        ],
      ),
    );
  }
}

/// A unified, full-screen Cart Screen skeleton.
class CartSkeleton extends StatelessWidget {
  const CartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const BaseSkeleton(width: 90, height: 90, borderRadius: 20),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BaseSkeleton(width: 140, height: 18),
                          SizedBox(height: 8),
                          BaseSkeleton(width: 80, height: 14),
                          SizedBox(height: 16),
                          BaseSkeleton(width: 100, height: 28, borderRadius: 8),
                        ],
                      ),
                    ),
                    const BaseSkeleton(width: 60, height: 20),
                  ],
                ),
              );
            },
          ),
        ),
        // Total Bar Skeleton
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BaseSkeleton(width: 60, height: 20),
                  BaseSkeleton(width: 100, height: 24),
                ],
              ),
              SizedBox(height: 20),
              BaseSkeleton(width: double.infinity, height: 55, borderRadius: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// A unified, full-screen Checkout Screen skeleton.
class CheckoutSkeleton extends StatelessWidget {
  const CheckoutSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          const BaseSkeleton(width: 180, height: 24),
          const SizedBox(height: 24),
          // Order Summary
          const BaseSkeleton(width: 120, height: 20),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    BaseSkeleton(width: 60, height: 60, borderRadius: 12),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BaseSkeleton(width: 120, height: 16),
                        SizedBox(height: 6),
                        BaseSkeleton(width: 80, height: 12),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Fulfillment
          const BaseSkeleton(width: 140, height: 20),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: BaseSkeleton(width: double.infinity, height: 45, borderRadius: 12)),
              SizedBox(width: 8),
              Expanded(child: BaseSkeleton(width: double.infinity, height: 45, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 24),
          // Address Placeholder
          const BaseSkeleton(width: 130, height: 20),
          const SizedBox(height: 12),
          const BaseSkeleton(width: double.infinity, height: 80, borderRadius: 16),
          const SizedBox(height: 12),
          const BaseSkeleton(width: 150, height: 16),
          const SizedBox(height: 32),
          // Payment Method
          const BaseSkeleton(width: 140, height: 20),
          const SizedBox(height: 12),
          const BaseSkeleton(width: double.infinity, height: 120, borderRadius: 16),
          const SizedBox(height: 32),
          // Place Order Button
          const BaseSkeleton(width: double.infinity, height: 55, borderRadius: 16),
        ],
      ),
    );
  }
}

/// A unified, full-screen Payment Success skeleton.
class PaymentDetailsSkeleton extends StatelessWidget {
  const PaymentDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Success Halo
          const BaseSkeleton(width: 80, height: 80, borderRadius: 40),
          const SizedBox(height: 24),
          // Titles
          const Center(child: BaseSkeleton(width: 220, height: 28)),
          const SizedBox(height: 12),
          const Center(child: BaseSkeleton(width: 280, height: 16)),
          const SizedBox(height: 40),
          // Invoice Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BaseSkeleton(width: 80, height: 16),
                    BaseSkeleton(width: 100, height: 24),
                  ],
                ),
                SizedBox(height: 24),
                BaseSkeleton(width: double.infinity, height: 1),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BaseSkeleton(width: 100, height: 14),
                    BaseSkeleton(width: 120, height: 14),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BaseSkeleton(width: 80, height: 14),
                    BaseSkeleton(width: 140, height: 14),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Buttons
          const BaseSkeleton(width: double.infinity, height: 55, borderRadius: 12),
          const SizedBox(height: 16),
          const BaseSkeleton(width: double.infinity, height: 55, borderRadius: 12),
          const SizedBox(height: 16),
          const BaseSkeleton(width: 150, height: 16),
        ],
      ),
    );
  }
}

/// A unified, full-screen Login Screen skeleton.
class LoginSkeleton extends StatelessWidget {
  const LoginSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            const BaseSkeleton(width: 120, height: 120, borderRadius: 12),
            const SizedBox(height: 12),
            const BaseSkeleton(width: 150, height: 32),
            const SizedBox(height: 8),
            const BaseSkeleton(width: 250, height: 16),
            const SizedBox(height: 48),
            // Input Fields
            const BaseSkeleton(width: double.infinity, height: 56),
            const SizedBox(height: 20),
            const BaseSkeleton(width: double.infinity, height: 56),
            const SizedBox(height: 32),
            // Login Button
            const BaseSkeleton(width: double.infinity, height: 50, borderRadius: 8),
            const SizedBox(height: 24),
            // Links
            const BaseSkeleton(width: 200, height: 16),
            const SizedBox(height: 16),
            const BaseSkeleton(width: 120, height: 16),
          ],
        ),
      ),
    );
  }
}

/// A unified, full-screen Register Screen skeleton.
class RegisterSkeleton extends StatelessWidget {
  const RegisterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const BaseSkeleton(width: 80, height: 80, borderRadius: 40),
          const SizedBox(height: 40),
          // Username, Email, Pass, Confirm
          const BaseSkeleton(width: double.infinity, height: 56),
          const SizedBox(height: 16),
          const BaseSkeleton(width: double.infinity, height: 56),
          const SizedBox(height: 16),
          const BaseSkeleton(width: double.infinity, height: 56),
          const SizedBox(height: 16),
          const BaseSkeleton(width: double.infinity, height: 56),
          const SizedBox(height: 32),
          // Register Button
          const BaseSkeleton(width: double.infinity, height: 50, borderRadius: 8),
        ],
      ),
    );
  }
}

/// A unified, full-screen Location/Map screen skeleton.
class LocationSkeleton extends StatelessWidget {
  const LocationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Map Area Placeholder
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const BaseSkeleton(width: double.infinity, height: double.infinity, borderRadius: 16),
          ),
        ),
        // Info Panel Placeholder
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The "Card"
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.lightBlue.withValues(alpha: 0.3), width: 2),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        BaseSkeleton(width: 40, height: 40, borderRadius: 20),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BaseSkeleton(width: 150, height: 20),
                              SizedBox(height: 8),
                              BaseSkeleton(width: double.infinity, height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Buttons
              const BaseSkeleton(width: double.infinity, height: 50, borderRadius: 12),
              const SizedBox(height: 12),
              const Center(child: BaseSkeleton(width: 100, height: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A unified, full-screen Order History screen skeleton.
class OrderHistorySkeleton extends StatelessWidget {
  const OrderHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Chips Row
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              BaseSkeleton(width: 60, height: 32, borderRadius: 16),
              SizedBox(width: 12),
              BaseSkeleton(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 12),
              BaseSkeleton(width: 80, height: 32, borderRadius: 16),
            ],
          ),
        ),
        // Order Cards List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: const Row(
                  children: [
                    // Thumbnail
                    BaseSkeleton(width: 60, height: 60, borderRadius: 8),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BaseSkeleton(width: 100, height: 18),
                          SizedBox(height: 8),
                          BaseSkeleton(width: double.infinity, height: 14),
                          SizedBox(height: 8),
                          BaseSkeleton(width: 120, height: 14),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    BaseSkeleton(width: 80, height: 28, borderRadius: 14),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}