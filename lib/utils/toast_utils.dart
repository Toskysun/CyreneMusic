import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastUtils {
  /// 显示普通消息
  static void show(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black.withValues(alpha: 0.7),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// 显示成功消息（可以有不同的背景色）
  static void success(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.green.withValues(alpha: 0.8),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// 显示错误消息
  static void error(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red.withValues(alpha: 0.8),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}
