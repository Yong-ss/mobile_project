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

/// 如果你喜欢用 context.showSnackbar('...') 这种方式，也可以定义一个扩展
extension SnackbarExtension on BuildContext {
  void showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(this)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
