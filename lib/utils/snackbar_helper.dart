import 'package:flutter/material.dart';

/// 全局 ScaffoldMessengerKey，用于在没有 Context 的情况下显示 SnackBar
final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();

/// 全局 SnackBar 方法
void snackbar(String message, Color color) {
  snackbarKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
