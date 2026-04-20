import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/translations.dart';

class ReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const ReceiptScreen({super.key, required this.order});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _isLoading = true;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    // Simulate a premium loading experience
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        body: const SafeArea(child: ReceiptSkeleton()),
      );
    }

    final String orderId = widget.order['id'] ?? 'Unknown';
    final String displayOrderId = '#${orderId.substring(0, 8).toUpperCase()}';
    final DateTime createdAt = DateTime.tryParse(widget.order['created_at'] ?? '') ?? DateTime.now();
    final String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);

    final seller = widget.order['seller'] as Map<String, dynamic>?;
    final String shopName = seller?['shop_name'] ?? 'Unknown Merchant';
    final String merchantEmail = seller?['email'] ?? 'Contact person not specified';
    final String shopPic = seller?['shop_pic'] ?? '';

    final List<dynamic> orderItems = widget.order['order_items'] as List<dynamic>? ?? [];
    final double totalAmount = double.tryParse(widget.order['total_amount']?.toString() ?? '0') ?? 0.0;
    final String paymentMethod = widget.order['payment_method'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('receipt'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, size: 22),
            onPressed: () => _showShareOptions(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Screenshot(
            controller: _screenshotController,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor, // UI matches theme
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header: Merchant Info ---
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: shopPic.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(35),
                            child: Image.network(
                              shopPic,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.store, color: Colors.lightBlue, size: 35),
                            ),
                          )
                              : const Icon(Icons.store, color: Colors.lightBlue, size: 35),
                        ),
                        const SizedBox(height: 16),
                        Text(shopName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(merchantEmail, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey.shade600, fontSize: 13)),
                        const SizedBox(height: 12),
                        const Divider(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Order Info Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('order_id'), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(displayOrderId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(t('date'), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- Items List ---
                  Text(t('items_ordered'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: Colors.blueGrey)),
                  const SizedBox(height: 16),
                  ...orderItems.map((item) {
                    final product = item['product'] as Map<String, dynamic>?;
                    final price = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0;
                    final quantity = item['quantity'] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product?['name'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('Qty: $quantity x RM ${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('RM ${(price * quantity).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Divider(thickness: 1.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.blueGrey.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),

                  // --- Payment Summary ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t('subtotal'), style: const TextStyle(fontSize: 15)),
                      Text('RM ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.grey.shade100
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('total_paid'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          'RM ${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.lightBlue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Payment Method ---
                  Text('PAYMENT METHOD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.blueGrey)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        paymentMethod.contains('Stripe') || paymentMethod.contains('Card')
                            ? Icons.credit_card
                            : paymentMethod.contains('NFC')
                            ? Icons.contactless
                            : Icons.account_balance_wallet,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 60),

                  // --- Footer ---
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 40),
                        const SizedBox(height: 12),
                        Text(t('receipt_footer'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(t('keep_receipt'), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(height: 40),
                      ],
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

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              _buildShareItem(
                icon: Icons.share_rounded,
                title: 'Share Receipt',
                subtitle: 'Send via WhatsApp, Email, etc.',
                onTap: () {
                  Navigator.pop(context);
                  _handleAction(ActionType.share);
                },
              ),
              const SizedBox(height: 16),
              _buildShareItem(
                icon: Icons.photo_library_rounded,
                title: 'Save to Gallery',
                subtitle: 'Save image to your Photos app',
                onTap: () {
                  Navigator.pop(context);
                  _handleAction(ActionType.saveGallery);
                },
              ),
              const SizedBox(height: 16),
              _buildShareItem(
                icon: Icons.file_download_rounded,
                title: 'Download Document',
                subtitle: 'Save to your device downloads folder',
                onTap: () {
                  Navigator.pop(context);
                  _handleAction(ActionType.saveFile);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.shade100
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.lightBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle
              ),
              child: Icon(icon, color: Colors.lightBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(ActionType type) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final image = await _screenshotController.capture(pixelRatio: 2.0);
      if (image == null) throw Exception('Failed to capture receipt');

      final directory = await getTemporaryDirectory();
      final String fileName = 'Receipt_${widget.order['id'].substring(0, 8)}.png';
      final file = await File('${directory.path}/$fileName').create();
      await file.writeAsBytes(image);

      if (type == ActionType.share) {
        await Share.shareXFiles([XFile(file.path)], text: 'My receipt from ${((widget.order['seller'] as Map?)?['shop_name'] ?? 'Merchant')}');
      } else if (type == ActionType.saveGallery) {
        final success = await GallerySaver.saveImage(file.path, albumName: 'Receipts');
        if (success == true) {
          _showToast('Saved to Gallery!');
        } else {
          throw Exception('Failed to save to gallery');
        }
      } else if (type == ActionType.saveFile) {
        // Specifically for "Downloads" would typically use path_provider but restricted on some OS.
        // For simplicity across platforms, we'll save to App Documents and notify.
        final appDocDir = await getApplicationDocumentsDirectory();
        final finalFile = await File('${appDocDir.path}/$fileName').create();
        await finalFile.writeAsBytes(image);
        _showToast('Saved to Documents: $fileName');
      }
    } catch (e) {
      _showToast('Error: $e');
    } finally {
      if (mounted) Navigator.pop(context); // Dismiss loading
    }
  }

  void _showToast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

enum ActionType { share, saveGallery, saveFile }