import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/toast_utils.dart';

/// 开发者模式服务
class DeveloperModeService extends ChangeNotifier {
  static final DeveloperModeService _instance = DeveloperModeService._internal();
  factory DeveloperModeService() => _instance;
  
  DeveloperModeService._internal() {
    _initFuture = _loadDeveloperMode();
  }

  bool _isDeveloperMode = false;
  bool get isDeveloperMode => _isDeveloperMode;

  bool _isSearchResultMergeEnabled = true;
  bool get isSearchResultMergeEnabled => _isSearchResultMergeEnabled;

  int _settingsClickCount = 0;
  DateTime? _lastClickTime;

  /// 初始化完成的 Future，用于等待加载完成
  late final Future<void> _initFuture;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// 等待初始化完成
  Future<void> ensureInitialized() => _initFuture;

  /// 记录日志
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  /// 处理设置按钮点击
  void onSettingsClicked() {
    _handleTrigger();
  }

  /// 处理版本信息点击
  void onVersionClicked() {
    _handleTrigger();
  }

  /// 统一处理触发逻辑
  void _handleTrigger() {
    final now = DateTime.now();
    
    // 如果距离上次点击超过2秒，重置计数
    if (_lastClickTime != null && now.difference(_lastClickTime!).inSeconds > 2) {
      _settingsClickCount = 0;
    }
    
    _lastClickTime = now;
    _settingsClickCount++;
    
    print('🔧 [DeveloperMode] 触发按钮点击次数: $_settingsClickCount');
    
    if (_isDeveloperMode) {
      // 如果已经开启，点击5次提示（类似于 Android 逻辑）
      if (_settingsClickCount >= 5) {
        ToastUtils.show('您已处于开发者模式');
        _settingsClickCount = 0;
      }
      return;
    }

    // 连续点击5次进入开发者模式
    if (_settingsClickCount >= 5) {
      _enableDeveloperMode();
      _settingsClickCount = 0;
    } else if (_settingsClickCount >= 2) {
      // 从第2次点击开始提示进度
      ToastUtils.show('再点击 ${5 - _settingsClickCount} 次即可开启开发者模式');
    }
  }

  /// 启用开发者模式
  Future<void> _enableDeveloperMode() async {
    _isDeveloperMode = true;
    await _saveDeveloperMode();
    addLog('🚀 开发者模式已启用');
    ToastUtils.success('开发者模式已启用');
    notifyListeners();
    print('🚀 [DeveloperMode] 开发者模式已启用');
  }

  /// 禁用开发者模式
  Future<void> disableDeveloperMode() async {
    _isDeveloperMode = false;
    await _saveDeveloperMode();
    addLog('🔒 开发者模式已禁用');
    notifyListeners();
    print('🔒 [DeveloperMode] 开发者模式已禁用');
  }

  /// 切换搜索结果合并开关
  Future<void> toggleSearchResultMerge(bool value) async {
    _isSearchResultMergeEnabled = value;
    await _saveDeveloperMode();
    addLog(value ? '🔄 已启用搜索结果合并' : '🔄 已禁用搜索结果合并');
    notifyListeners();
  }

  /// 添加日志
  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    
    // 限制日志数量，最多保留1000条
    if (_logs.length > 1000) {
      _logs.removeAt(0);
    }
    
    notifyListeners();
  }

  /// 清除所有日志
  void clearLogs() {
    _logs.clear();
    addLog('🗑️ 日志已清除');
    notifyListeners();
  }

  /// 加载开发者模式状态
  Future<void> _loadDeveloperMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDeveloperMode = prefs.getBool('developer_mode') ?? false;
      _isSearchResultMergeEnabled = prefs.getBool('search_result_merge_enabled') ?? true;
      _isInitialized = true;
      if (_isDeveloperMode) {
        print('🔧 [DeveloperMode] 从本地加载: 已启用');
        addLog('🔄 开发者模式状态已恢复');
      }
      print('🔧 [DeveloperMode] 搜索结果合并设置加载: $_isSearchResultMergeEnabled');
      notifyListeners();
    } catch (e) {
      print('❌ [DeveloperMode] 加载失败: $e');
      _isInitialized = true; // 即使加载失败也标记为已初始化，使用默认值
      notifyListeners();
    }
  }

  /// 保存开发者模式状态
  Future<void> _saveDeveloperMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('developer_mode', _isDeveloperMode);
      await prefs.setBool('search_result_merge_enabled', _isSearchResultMergeEnabled);
      print('💾 [DeveloperMode] 状态已保存: 开发者模式=$_isDeveloperMode, 搜索合并=$_isSearchResultMergeEnabled');
    } catch (e) {
      print('❌ [DeveloperMode] 保存失败: $e');
    }
  }
}
