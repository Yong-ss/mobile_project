import 'package:flutter/material.dart';

/// 全局 ScaffoldMessengerKey，用于在没有 Context 的情况下显示 SnackBar
final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();

/// 全局 SnackBar 方法
void snackbar(String message, Color color, {IconData? icon}) {
  snackbarKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        duration: const Duration(seconds: 3),
      ),
    );
}
