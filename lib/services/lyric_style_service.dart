import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 歌词样式类型
enum LyricStyle {
  /// 默认样式 (卡拉OK样式)
  defaultStyle,
  
  /// 流体云样式
  fluidCloud,
}

/// 歌词样式服务
/// 管理歌词样式偏好设置
class LyricStyleService extends ChangeNotifier {
  static final LyricStyleService _instance = LyricStyleService._internal();
  factory LyricStyleService() => _instance;
  LyricStyleService._internal();

  static const String _storageKey = 'lyric_style';
  
  LyricStyle _currentStyle = LyricStyle.defaultStyle;

  /// 获取当前歌词样式
  LyricStyle get currentStyle => _currentStyle;

  /// 初始化服务
  Future<void> initialize() async {
    await _loadStyle();
  }

  /// 从本地存储加载样式设置
  Future<void> _loadStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStyleIndex = prefs.getInt(_storageKey);
      
      if (savedStyleIndex != null && savedStyleIndex >= 0 && savedStyleIndex < LyricStyle.values.length) {
        // 用户已设置过，使用用户设置
        _currentStyle = LyricStyle.values[savedStyleIndex];
      } else {
        // 用户未设置过，使用平台默认值
        // 桌面端默认使用流体云样式，移动端默认使用默认样式
        _currentStyle = Platform.isWindows || Platform.isMacOS || Platform.isLinux
            ? LyricStyle.fluidCloud
            : LyricStyle.defaultStyle;
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ [LyricStyleService] 加载歌词样式失败: $e');
      _currentStyle = LyricStyle.defaultStyle;
    }
  }

  /// 设置歌词样式
  Future<void> setStyle(LyricStyle style) async {
    if (_currentStyle == style) return;
    
    _currentStyle = style;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageKey, style.index);
      print('✅ [LyricStyleService] 歌词样式已保存: ${_getStyleName(style)}');
    } catch (e) {
      print('❌ [LyricStyleService] 保存歌词样式失败: $e');
    }
  }

  /// 获取样式的显示名称
  String getStyleName(LyricStyle style) => _getStyleName(style);

  static String _getStyleName(LyricStyle style) {
    switch (style) {
      case LyricStyle.defaultStyle:
        return '默认样式';
      case LyricStyle.fluidCloud:
        return '流体云';
    }
  }

  /// 获取样式的描述
  String getStyleDescription(LyricStyle style) {
    switch (style) {
      case LyricStyle.defaultStyle:
        return '经典卡拉OK效果，从左到右填充';
      case LyricStyle.fluidCloud:
        return '云朵般流动的歌词效果，柔和舒适';
    }
  }
}

