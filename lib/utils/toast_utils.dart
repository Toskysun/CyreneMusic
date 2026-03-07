import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../main.dart';

class ToastUtils {
  static FToast? _fToast;

  static void _ensureInitialized() {
    if (_fToast != null) return;
    
    // 优先使用 GlobalContextHolder 提供的 context
    final context = GlobalContextHolder.context ?? MyApp.navigatorKey.currentContext;
    if (context != null) {
      _fToast = FToast();
      _fToast!.init(context);
      debugPrint('🔧 [ToastUtils] FToast 已使用 ${GlobalContextHolder.context != null ? "GlobalContext" : "navigatorKey"} 初始化');
    }
  }

  /// 显示普通消息
  static void show(String message) {
    _ensureInitialized();
    if (_fToast == null) {
      // 回退方案
      Fluttertoast.showToast(msg: message);
      return;
    }

    _fToast!.showToast(
      child: _ToastWidget(
        message: message,
        icon: Icons.info_outline,
        color: Colors.blueAccent,
      ),
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 2),
    );
  }

  /// 显示提示信息
  static void info(String message) {
    _ensureInitialized();
    if (_fToast == null) {
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.blueAccent,
      );
      return;
    }

    _fToast!.showToast(
      child: _ToastWidget(
        message: message,
        icon: Icons.info_outline,
        color: Colors.blueAccent,
      ),
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 2),
    );
  }

  /// 显示成功消息

  static void success(String message) {
    _ensureInitialized();
    if (_fToast == null) {
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.green,
      );
      return;
    }

    _fToast!.showToast(
      child: _ToastWidget(
        message: message,
        icon: Icons.check_circle_outline,
        color: Colors.greenAccent,
      ),
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 2),
    );
  }

  /// 显示错误消息
  static void error(String message, {String? details}) {
    _ensureInitialized();
    if (_fToast == null) {
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.red,
      );
      return;
    }

    _fToast!.showToast(
      child: _ToastWidget(
        message: message,
        details: details,
        icon: Icons.error_outline,
        color: Colors.redAccent,
        showBorder: false, // 失败时不显示边框
      ),
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 4),
    );
  }
}

class _ToastWidget extends StatelessWidget {
  final String message;
  final String? details;
  final IconData icon;
  final Color color;
  final bool showBorder;

  const _ToastWidget({
    required this.message,
    this.details,
    required this.icon,
    required this.color,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0), // 增加模糊强度
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              // 进一步调低 alpha 以显示更通透的模糊背景
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.55) 
                  : Colors.white.withValues(alpha: 0.45),
              border: showBorder ? Border.all(
                color: color.withValues(alpha: 0.1),
                width: 0.5,
              ) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10.0),
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (details != null && details!.isNotEmpty && details != message) ...[
                  const SizedBox(width: 8.0),
                  TextButton(
                    onPressed: () => _showDetailsDialog(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: color,
                    ),
                    child: const Text(
                      '更多',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    // 获取全局 Navigator context，因为 Toast 所在的 Overlay 可能不在 Navigator 树中
    final dialogContext = MyApp.navigatorKey.currentContext ?? context;
    
    showDialog(
      context: dialogContext,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('错误详情'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    details ?? '无详细信息',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: details ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
