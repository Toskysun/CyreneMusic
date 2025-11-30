import 'package:flutter/foundation.dart';

/// 全局返回键处理服务
/// 用于管理 Android 返回键的行为，支持多个页面注册返回处理器
class GlobalBackHandlerService extends ChangeNotifier {
  static final GlobalBackHandlerService _instance =
      GlobalBackHandlerService._internal();

  factory GlobalBackHandlerService() => _instance;

  GlobalBackHandlerService._internal();

  /// 返回处理器栈，后注册的优先处理
  final List<_BackHandlerEntry> _handlers = [];

  /// 是否有可处理的返回操作
  bool get canPop => _handlers.isNotEmpty;

  /// 注册返回处理器
  /// [key] 用于标识处理器，避免重复注册
  /// [handler] 返回处理函数，返回 true 表示已处理，false 表示未处理
  void register(String key, bool Function() handler) {
    // 移除已存在的同 key 处理器
    _handlers.removeWhere((e) => e.key == key);
    _handlers.add(_BackHandlerEntry(key: key, handler: handler));
    notifyListeners();
  }

  /// 注销返回处理器
  void unregister(String key) {
    final lengthBefore = _handlers.length;
    _handlers.removeWhere((e) => e.key == key);
    if (_handlers.length != lengthBefore) {
      notifyListeners();
    }
  }

  /// 处理返回操作
  /// 返回 true 表示已处理（不应退出应用），false 表示未处理（可以退出应用）
  bool handleBack() {
    // 从后往前遍历，后注册的优先处理
    for (int i = _handlers.length - 1; i >= 0; i--) {
      if (_handlers[i].handler()) {
        return true;
      }
    }
    return false;
  }

  /// 清除所有处理器
  void clear() {
    _handlers.clear();
    notifyListeners();
  }
}

class _BackHandlerEntry {
  final String key;
  final bool Function() handler;

  _BackHandlerEntry({required this.key, required this.handler});
}
