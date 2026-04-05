import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../order/order_history_screen.dart';
import '../../widgets/shimmer_skeletons.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final double amount;
  final String transactionId;
  final String userName;
  final String paymentMethod;
  final DateTime date;
  final String merchantName;

  const PaymentDetailsScreen({
    super.key,
    required this.amount,
    required this.transactionId,
    required this.userName,
    required this.paymentMethod,
    required this.date,
    required this.merchantName,
  });

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Artificial delay to show the beautiful shimmer and "process" the success
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: PaymentDetailsSkeleton()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 50),
                ),
              ),
              const SizedBox(height: 24),

              // Title Strings
              const Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your payment has been processed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.blueGrey, height: 1.5),
              ),
              const SizedBox(height: 40),

              // Details Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Amount', 'RM ${widget.amount.toStringAsFixed(2)}', isHighlight: true),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _buildDetailRow('Transaction ID', (widget.transactionId.length > 8 ? '${widget.transactionId.substring(0, 8)}...' : widget.transactionId).toUpperCase(), isPill: true),
                    const SizedBox(height: 16),
                    _buildDetailRow('User Name', widget.userName),
                    const SizedBox(height: 16),
                    _buildDetailRow('Payment Method', widget.paymentMethod),
                    const SizedBox(height: 16),
                    _buildDetailRow('Date', DateFormat('MMM dd, yyyy - hh:mm a').format(widget.date)),
                    const SizedBox(height: 16),
                    _buildDetailRow('Merchant', widget.merchantName),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading receipt... (Mock)')));
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF03A9F4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('View My Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueGrey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Need help? Contact our support team at support@priscon.com',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isPill = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 16)),
        if (isPill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
          )
        else
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                fontSize: isHighlight ? 22 : 16,
                color: Colors.black87,
              ),
            ),
          ),
      ],
    );
  }
}
