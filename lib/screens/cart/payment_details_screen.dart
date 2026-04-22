import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../order/order_history_screen.dart';
import '../../widgets/shimmer_skeletons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  String _getCleanMethod(String raw) {
    if (!raw.contains(' [ID: ')) return raw;
    return raw.split(' [ID: ').first;
  }

  Future<void> _downloadReceiptPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PRISCON INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                    pw.Text('Priscon Marketplace', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 20),

                // Transaction Status
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text('PAYMENT SUCCESSFUL', style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ),
                pw.SizedBox(height: 30),

                // Details Table
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoItem('Billed To', widget.userName),
                        _pdfInfoItem('Payment Method', _getCleanMethod(widget.paymentMethod)),
                        _pdfInfoItem('Date', DateFormat('MMM dd, yyyy - hh:mm a').format(widget.date)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _pdfInfoItem('Transaction ID', widget.transactionId.toUpperCase(), alignRight: true),
                        _pdfInfoItem('Merchant', widget.merchantName, alignRight: true),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 40),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 10),

                // Amount
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount Paid', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('RM ${widget.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),

                pw.Spacer(),
                // Footer
                pw.Center(
                  child: pw.Text('Thank you for shopping with Priscon!', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 12)),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text('This is a computer generated receipt and requires no signature.', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Provide the PDF data to the user
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _pdfInfoItem(String label, String value, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        crossAxisAlignment: alignRight ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
        body: const SafeArea(child: PaymentDetailsSkeleton()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
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
                  color: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.check_circle, color: isDark ? Colors.greenAccent : Colors.green.shade600, size: 50),
                ),
              ),
              const SizedBox(height: 24),

              // Title Strings
              Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : Colors.green),
              ),
              const SizedBox(height: 12),
              Text(
                'Your payment has been processed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.blueGrey, height: 1.5),
              ),
              const SizedBox(height: 40),

              // Details Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: isDark ? Border.all(color: Colors.white12) : null,
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Amount', 'RM ${widget.amount.toStringAsFixed(2)}', isHighlight: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                    ),
                    _buildDetailRow('Transaction ID', (widget.transactionId.length > 8 ? '${widget.transactionId.substring(0, 8)}...' : widget.transactionId).toUpperCase(), isPill: true),
                    const SizedBox(height: 16),
                    _buildDetailRow('User Name', widget.userName),
                    const SizedBox(height: 16),
                    _buildDetailRow('Payment Method', _getCleanMethod(widget.paymentMethod)),
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
                  onPressed: _downloadReceiptPDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Download PDF Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
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
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1.5),
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
                    foregroundColor: isDark ? Colors.lightBlueAccent : Colors.blueGrey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Need help? Contact our support team at support@priscon.com',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isPill = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.blueGrey, fontSize: 16)),
        if (isPill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
            ),
            child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
          )
        else
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                fontSize: isHighlight ? 22 : 16,
                color: isHighlight
                    ? (isDark ? Colors.greenAccent : Colors.black87)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
      ],
    );
  }
}