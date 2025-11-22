import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 窗口背景类型
enum WindowBackgroundType {
  image,  // 图片背景
  video,  // 视频背景
}

/// 窗口背景服务 - 管理 Fluent UI 窗口背景图片/视频和模糊度
/// 注意：此功能独立于播放器背景，仅用于整个窗口的背景
class WindowBackgroundService extends ChangeNotifier {
  static final WindowBackgroundService _instance = WindowBackgroundService._internal();
  factory WindowBackgroundService() => _instance;
  WindowBackgroundService._internal() {
    _loadSettings();
  }

  // 是否启用窗口背景
  bool _enabled = false;
  
  // 背景类型
  WindowBackgroundType _backgroundType = WindowBackgroundType.image;
  
  // 背景文件路径（图片或视频）
  String? _mediaPath;
  
  // 模糊程度 (0-50)
  double _blurAmount = 20.0;
  
  // 不透明度 (0.0-1.0)
  double _opacity = 0.6;

  bool get enabled => _enabled;
  WindowBackgroundType get backgroundType => _backgroundType;
  String? get mediaPath => _mediaPath;
  String? get imagePath => _mediaPath; // 兼容旧代码
  double get blurAmount => _blurAmount;
  double get opacity => _opacity;
  bool get isVideo => _backgroundType == WindowBackgroundType.video;
  bool get isImage => _backgroundType == WindowBackgroundType.image;

  /// 从本地存储加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('window_background_enabled') ?? false;
      
      // 读取背景类型（向后兼容）
      final typeIndex = prefs.getInt('window_background_type');
      if (typeIndex != null && typeIndex < WindowBackgroundType.values.length) {
        _backgroundType = WindowBackgroundType.values[typeIndex];
      }
      
      // 先尝试读取新的 media_path，如果不存在则读取旧的 image_path（向后兼容）
      _mediaPath = prefs.getString('window_background_media_path') ?? 
                   prefs.getString('window_background_image_path');
      
      _blurAmount = prefs.getDouble('window_background_blur') ?? 20.0;
      _opacity = prefs.getDouble('window_background_opacity') ?? 0.6;
      
      // 根据文件扩展名自动检测类型
      if (_mediaPath != null && typeIndex == null) {
        _detectMediaType();
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ [WindowBackgroundService] 加载设置失败: $e');
    }
  }
  
  /// 根据文件扩展名检测媒体类型
  void _detectMediaType() {
    if (_mediaPath == null) return;
    
    final ext = _mediaPath!.toLowerCase().split('.').last;
    if (ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv' || ext == 'webm') {
      _backgroundType = WindowBackgroundType.video;
    } else {
      _backgroundType = WindowBackgroundType.image;
    }
  }

  /// 设置是否启用窗口背景
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('window_background_enabled', value);
    notifyListeners();
  }

  /// 设置背景媒体文件（图片或视频）
  Future<void> setMediaPath(String? path) async {
    _mediaPath = path;
    final prefs = await SharedPreferences.getInstance();
    
    if (path != null) {
      // 自动检测媒体类型
      _detectMediaType();
      
      await prefs.setString('window_background_media_path', path);
      await prefs.setInt('window_background_type', _backgroundType.index);
      
      print('✅ [WindowBackground] 背景已设置: $path (类型: $_backgroundType)');
    } else {
      await prefs.remove('window_background_media_path');
      await prefs.remove('window_background_type');
    }
    
    notifyListeners();
  }
  
  /// 设置背景图片（兼容旧代码）
  Future<void> setImagePath(String? path) async {
    await setMediaPath(path);
  }
  
  /// 设置背景类型
  Future<void> setBackgroundType(WindowBackgroundType type) async {
    if (_backgroundType == type) return;
    
    _backgroundType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('window_background_type', type.index);
    
    notifyListeners();
    print('🎨 [WindowBackground] 背景类型已更改: $type');
  }

  /// 设置模糊程度
  Future<void> setBlurAmount(double value) async {
    _blurAmount = value.clamp(0.0, 50.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_background_blur', _blurAmount);
    notifyListeners();
  }

  /// 设置不透明度
  Future<void> setOpacity(double value) async {
    _opacity = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_background_opacity', _opacity);
    notifyListeners();
  }

  /// 清除背景媒体
  Future<void> clearMedia() async {
    await setMediaPath(null);
    await setEnabled(false);
  }
  
  /// 清除背景图片（兼容旧代码）
  Future<void> clearImage() async {
    await clearMedia();
  }

  /// 获取背景媒体文件（如果存在）
  File? getMediaFile() {
    if (_mediaPath == null || _mediaPath!.isEmpty) return null;
    final file = File(_mediaPath!);
    return file.existsSync() ? file : null;
  }
  
  /// 获取背景图片文件（兼容旧代码）
  File? getImageFile() {
    return getMediaFile();
  }

  /// 检查是否有有效的背景媒体
  bool get hasValidMedia {
    return _mediaPath != null && _mediaPath!.isNotEmpty && getMediaFile() != null;
  }
  
  /// 检查是否有有效的背景图片（兼容旧代码）
  bool get hasValidImage {
    return hasValidMedia;
  }
  
  /// 检查文件是否为支持的图片格式
  bool isImageFile(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }
  
  /// 检查文件是否为支持的视频格式
  bool isVideoFile(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(ext);
  }
}

