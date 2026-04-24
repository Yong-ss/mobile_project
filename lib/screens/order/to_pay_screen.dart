import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import '../cart/payment_details_screen.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/translations.dart';

class ToPayScreen extends StatefulWidget {
  const ToPayScreen({super.key});

  @override
  State<ToPayScreen> createState() => _ToPayScreenState();
}

class _ToPayScreenState extends State<ToPayScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingOrders = [];
  Timer? _countdownTimer;

  bool _isHandlingExpiration = false;

  @override
  void initState() {
    super.initState();
    _loadPendingPayments();
    // Refresh timer every second to update countdowns and check for expirations
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _checkExpirations();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingPayments() async {
    try {
      // 1. Fetch Orders that are currently "Awaiting Payment"
      // This is the source of truth for what the user needs to pay for.
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2)).toUtc().toIso8601String();

      final ordersResponse = await _supabase
          .from('orders')
          .select('*, seller:seller_id(shop_name, username)')
          .eq('buyer_id', currentUser!['id'])
          .eq('status', 'Awaiting Payment')
          .gt('created_at', cutoff)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(ordersResponse);

      if (orders.isEmpty) {
        if (mounted) {
          setState(() {
            _pendingOrders = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch associated Payments to get the Stripe/NFC details
      final paymentsResponse = await _supabase
          .from('payments')
          .select('*')
          .eq('user_id', currentUser!['id']);

      final List<Map<String, dynamic>> payments = List<Map<String, dynamic>>.from(paymentsResponse);

      final List<Map<String, dynamic>> combined = [];

      for (var order in orders) {
        final String paymentMethodRaw = order['payment_method']?.toString() ?? '';
        final String piid = _extractId(paymentMethodRaw);

        // Find matching payment record
        final matchingPayment = payments.firstWhere(
              (p) => p['payment_intent_id'] == piid,
          orElse: () => {},
        );

        final createdAt = matchingPayment['created_at'] ?? order['created_at'];

        // We only show it if the payment is NOT already successful and NOT expired
        if (matchingPayment['status'] != 'Success' && matchingPayment['status'] != 'succeeded') {
          if (!_isExpired(createdAt)) {
            combined.add({
              ...matchingPayment, // Payment details (id, status, created_at, amount)
              'id': matchingPayment['id'] ?? -1, // Use payment ID if it exists, else -1
              'order_id': order['id'], // Keep track of order ID
              'orders': order,    // Order details for UI
              'created_at': createdAt, // Use payment time for timer
              'amount': order['total_amount'] ?? 0.0,
              'payment_intent_id': piid,
            });
          } else {
            // It's expired already, handle it silently in the background
            _handleExpirationSilently({
              'order_id': order['id'],
              'id': matchingPayment['id'] ?? -1,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _pendingOrders = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) snackbar('Error loading orders: $e', Colors.red);
      if (mounted) setState(() => _isLoading = false);
    }
  }



  String _extractId(String raw) {
    if (!raw.contains(' [ID: ')) return '';
    return raw.split(' [ID: ').last.split(']').first;
  }

  String _extractSecret(String raw) {
    if (!raw.contains('[SECRET: ')) return '';
    return raw.split('[SECRET: ').last.split(']').first;
  }

  void _checkExpirations() {
    if (_isHandlingExpiration || _isLoading) return;

    for (var item in _pendingOrders) {
      if (_isExpired(item['created_at'])) {
        _handleExpiration(item);
        return; // Handle one, list refresh will catch others
      }
    }
  }

  String _getRemainingTime(String createdAt) {
    final createdTime = DateTime.parse(createdAt).toLocal();
    final now = DateTime.now();
    // PENDING DURATION: 2 Minutes (Increased for better UX)
    final expiryTime = createdTime.add(const Duration(minutes: 2));
    final difference = expiryTime.difference(now);

    if (difference.isNegative) {
      return "00:00";
    }

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(difference.inMinutes.remainder(60));
    final seconds = twoDigits(difference.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  bool _isExpired(String createdAt) {
    final createdTime = DateTime.parse(createdAt).toLocal();
    final now = DateTime.now();
    final expiryTime = createdTime.add(const Duration(minutes: 2));
    return now.isAfter(expiryTime);
  }

  Future<void> _handleExpiration(Map<String, dynamic> item) async {
    if (_isHandlingExpiration) return;
    if (mounted) setState(() => _isHandlingExpiration = true);

    try {
      // 1. Update order status to Failed
      await _supabase
          .from('orders')
          .update({'status': 'Failed'})
          .eq('id', item['order_id']);

      // 2. Update payment status to Failed if record exists
      if (item['id'] != -1) {
        await _supabase
            .from('payments')
            .update({'status': 'Failed'})
            .eq('id', item['id']);
      }

      await _loadPendingPayments(); // Refresh list to remove it from UI
    } catch (e) {
      debugPrint('Auto-fail error: $e');
    } finally {
      if (mounted) setState(() => _isHandlingExpiration = false);
    }
  }

  // A variant of handleExpiration that doesn't trigger a full UI refresh
  Future<void> _handleExpirationSilently(Map<String, dynamic> item) async {
    try {
      await _supabase.from('orders').update({'status': 'Failed'}).eq('id', item['order_id']);
      if (item['id'] != -1) {
        await _supabase.from('payments').update({'status': 'Failed'}).eq('id', item['id']);
      }
    } catch (e) {
      debugPrint('Silent auto-fail error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('to_pay'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const ToPaySkeleton()
          : _pendingOrders.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadPendingPayments,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _pendingOrders.length,
          itemBuilder: (context, index) {
            final item = _pendingOrders[index];
            return _buildPaymentCard(item);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            t('no_pending_payments'),
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            t('all_orders_paid'),
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> item) {
    final order = item['orders'];
    final seller = order?['seller'];
    final shopName = seller?['shop_name'] ?? seller?['username'] ?? 'Unknown Shop';
    final amount = double.tryParse(item['amount'].toString()) ?? 0.0;
    final remainingTime = _getRemainingTime(item['created_at']);
    final displayId = item['payment_intent_id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: remainingTime == "00:00" ? Colors.red.shade100 : Colors.orange.shade100,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header with Shop Name and Timer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.store, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (displayId.isNotEmpty)
                        Text(
                          'ID: ${displayId.length > 12 ? displayId.substring(0, 12) : displayId}...',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        remainingTime,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${t('total_payment')}:', style: const TextStyle(color: Colors.grey)),
                    Text(
                      'RM ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.lightBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleExpiration(item), // Allow manual cancel
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          foregroundColor: Colors.red,
                        ),
                        child: Text(t('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _payNow(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(t('pay_now'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payNow(Map<String, dynamic> item) async {
    _showPaymentMethodSelector(item);
  }

  void _showPaymentMethodSelector(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('choose_payment_method'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildSelectionOption(
                icon: Icons.credit_card,
                title: 'Credit/Debit Card (Stripe)',
                subtitle: 'Visa, Mastercard, etc.',
                onTap: () {
                  Navigator.pop(context);
                  _processStripePayNow(item);
                },
              ),
              const SizedBox(height: 12),
              _buildSelectionOption(
                icon: Icons.nfc,
                title: 'NFC Scan',
                subtitle: 'Pay with NFC card or tag',
                onTap: () {
                  Navigator.pop(context);
                  _processNFCPayNow(item);
                },
              ),
              const SizedBox(height: 12),
              _buildSelectionOption(
                icon: Icons.payments,
                title: 'Cash on Delivery',
                subtitle: 'Pay when you receive it',
                onTap: () {
                  Navigator.pop(context);
                  _processCashPayNow(item);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.lightBlue, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _processStripePayNow(Map<String, dynamic> item) async {
    final amount = double.tryParse(item['amount'].toString()) ?? 0.0;
    String clientSecret = _extractSecret(item['payment_method'] ?? '');
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // If missing secret or switching method, get a NEW Stripe Session
      if (clientSecret.isEmpty) {
        final amountInCents = (amount * 100).toInt();
        final response = await _supabase.functions.invoke(
          'stripe-api',
          body: {
            'amount': amountInCents,
            'user_id': currentUser!['id'],
          },
        );

        if (response.data == null) throw 'Failed to fetch Stripe session';
        final data = response.data as Map<String, dynamic>;
        clientSecret = data['paymentIntent'] as String;

        // Update payment ID and secret in our records
        final newPiid = clientSecret.split('_secret_').first;
        if (item['id'] != -1) {
          await _supabase.from('payments').update({
            'payment_intent_id': newPiid,
            'payment_method': 'Stripe [ID: $newPiid] [SECRET: $clientSecret]',
          }).eq('id', item['id']);
        } else {
          await _supabase.from('payments').insert({
            'user_id': currentUser!['id'],
            'payment_intent_id': newPiid,
            'amount': amount,
            'payment_method': 'Stripe [ID: $newPiid] [SECRET: $clientSecret]',
            'status': 'pending',
          });
        }

        // Always link the order
        await _supabase.from('orders').update({
          'payment_method': 'Credit/Debit (Stripe) [ID: $newPiid]',
        }).eq('id', item['order_id']);
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Priscon Shop',
          style: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        ),
      );

      if (mounted) Navigator.pop(context); // Close loading

      await Stripe.instance.presentPaymentSheet();
      await _finalizeSuccess(item, 'Stripe');
    } on StripeException catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (e.error.code == FailureCode.Canceled) {
        if (mounted) snackbar('Payment Not Completed', Colors.orange);
      } else {
        if (mounted) snackbar('Payment Failed: ${e.error.localizedMessage}', Colors.red);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) snackbar('Stripe Error: $e', Colors.red);
    }
  }

  Future<void> _processNFCPayNow(Map<String, dynamic> item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ready to Scan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const SizedBox(
                height: 200,
                child: Center(child: AnimatedPulseIcon()),
              ),
              const SizedBox(height: 20),
              const Text('Hold your phone near the NFC card or Tag.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  NfcManager.instance.stopSession();
                  Navigator.pop(context);
                  _finalizeSuccess(item, 'NFC Scan');
                },
                child: const Text('Simulate Success (For Emulator)', style: TextStyle(color: Colors.lightBlue)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    NfcManager.instance.stopSession();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                    foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      onDiscovered: (NfcTag tag) async {
        NfcManager.instance.stopSession();
        if (mounted) {
          Navigator.pop(context);
          await _finalizeSuccess(item, 'NFC Scan');
        }
      },
    );
  }

  Future<void> _processCashPayNow(Map<String, dynamic> item) async {
    await _finalizeSuccess(item, 'Cash on Delivery');
  }

  Future<void> _finalizeSuccess(Map<String, dynamic> item, String method) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final piid = item['payment_intent_id'] ?? 'RE-PAY';

      // 1. Update/Insert Payment status to Success
      if (item['id'] != -1) {
        await _supabase
            .from('payments')
            .update({
          'status': 'Success',
          'payment_method': method.contains('Stripe') ? item['payment_method'] : method,
        })
            .eq('id', item['id']);
      } else {
        await _supabase.from('payments').insert({
          'user_id': currentUser!['id'],
          'payment_intent_id': piid,
          'amount': item['amount'],
          'payment_method': method,
          'status': 'Success',
        });
      }

      // 2. Update Order status to Pending
      await _supabase
          .from('orders')
          .update({
        'status': 'Pending',
        'payment_at': DateTime.now().toIso8601String(),
        'payment_method': method.contains('Stripe') ? 'Credit/Debit (Stripe) [ID: $piid]' : '$method [ID: $piid]',
      })
          .eq('id', item['order_id']);

      if (mounted) Navigator.pop(context); // Close loading

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailsScreen(
              amount: double.tryParse(item['amount'].toString()) ?? 0.0,
              transactionId: piid,
              userName: currentUser!['username'] ?? 'Customer',
              paymentMethod: method,
              date: DateTime.now(),
              merchantName: (item['orders']?['seller']?['shop_name']) ?? 'Merchant',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) snackbar('Finalization failed: $e', Colors.red);
    }
  }
}

class AnimatedPulseIcon extends StatefulWidget {
  const AnimatedPulseIcon({super.key});

  @override
  State<AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<AnimatedPulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140 * _controller.value,
              height: 140 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.lightBlue.withValues(alpha: 1.0 - _controller.value), width: 2),
              ),
            ),
            Container(
              width: 180 * _controller.value,
              height: 180 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.lightBlue.withValues(alpha: (1.0 - _controller.value) * 0.5), width: 1),
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.phone_android, size: 50, color: Colors.lightBlue),
            ),
          ],
        );
      },
    );
  }
}
