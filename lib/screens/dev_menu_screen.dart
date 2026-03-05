import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'core/home_screen.dart';
import 'core/profile_screen.dart';
import 'shop/shop_screen.dart';
import 'shop/product_details_screen.dart';
import 'shop/seller_page_screen.dart';
import 'product/upload_product_screen.dart';
import 'product/my_listings_screen.dart';
import 'cart/cart_screen.dart';
import 'cart/checkout_screen.dart';
import 'order/order_history_screen.dart';
import 'order/order_details_screen.dart';
import 'order/seller_orders_screen.dart';
import 'order/qr_pickup_screen.dart';
import 'map/location_screen.dart';
import 'dashboard/sales_dashboard_screen.dart';

/// Temporary developer screen — lists every screen for fast testing.
/// Delete this before final submission.
class DevMenuScreen extends StatelessWidget {
  const DevMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // All screens listed here for easy jump navigation
    final List<Map<String, dynamic>> screens = [
      {'label': 'Login', 'screen': const LoginScreen()},
      {'label': 'Register', 'screen': const RegisterScreen()},
      {'label': 'Home', 'screen': const HomeScreen()},
      {'label': 'Profile', 'screen': const ProfileScreen()},
      {'label': 'Shop', 'screen': const ShopScreen()},
      {'label': 'Product Details', 'screen': const ProductDetailsScreen()},
      {'label': 'Seller Page', 'screen': const SellerPageScreen()},
      {'label': 'My Listings (Member 4 - Seller)', 'screen': const MyListingsScreen()},
      {'label': 'Upload Product (Member 1 - Camera)', 'screen': const UploadProductScreen()},
      {'label': 'Cart', 'screen': const CartScreen()},
      {'label': 'Checkout', 'screen': const CheckoutScreen()},
      {'label': 'Order History', 'screen': const OrderHistoryScreen()},
      {'label': 'Order Details', 'screen': const OrderDetailsScreen()},
      {'label': 'Seller Orders (Member 3)', 'screen': const SellerOrdersScreen()},
      {'label': 'QR Pickup (Member 3 - QR)', 'screen': const QrPickupScreen()},
      {'label': 'Location / Map (Member 2 - GPS)', 'screen': const LocationScreen()},
      {'label': 'Sales Dashboard (Member 4 - Charts)', 'screen': const SalesDashboardScreen()},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('[DEV] Screen Navigator'),
        backgroundColor: Colors.amber,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: screens.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => screens[index]['screen'] as Widget,
                ),
              );
            },
            child: Text(screens[index]['label'] as String),
          );
        },
      ),
    );
  }
}
