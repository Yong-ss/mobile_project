import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/globals.dart';

class SystemLogService {
  static final SystemLogService _instance = SystemLogService._internal();
  factory SystemLogService() => _instance;
  SystemLogService._internal();

  final _supabase = Supabase.instance.client;

  /// Logs an administrative action to the system_logs table.
  /// [action] is the type of action (e.g., 'Delete User', 'Verify Seller').
  /// [details] contains additional context (e.g., 'Deleted user ID: 123').
  Future<void> logAction(String action, String details) async {
    try {
      await _supabase.from('system_logs').insert({
        'admin_id': currentUser?['email'] ?? 'Unknown Admin',
        'action': action,
        'details': details,
      });
      debugPrint('System Log Created: $action - $details');
    } catch (e) {
      debugPrint('Error logging action to database: $e');
    }
  }
}

// Global instance for convenience
final systemLogService = SystemLogService();
