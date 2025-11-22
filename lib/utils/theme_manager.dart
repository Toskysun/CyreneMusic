import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/system_theme_color_service.dart';

/// 桌面端主题框架
enum ThemeFramework {
  material,
  fluent,
}

/// 预设主题色方案
class ThemeColorScheme {
  final String name;
  final Color color;
  final IconData icon;

  const ThemeColorScheme({
    required this.name,
    required this.color,
    required this.icon,
  });
}

/// 预设的主题色列表
class ThemeColors {
  static const List<ThemeColorScheme> presets = [
    ThemeColorScheme(name: '深紫色', color: Colors.deepPurple, icon: Icons.palette),
    ThemeColorScheme(name: '蓝色', color: Colors.blue, icon: Icons.water_drop),
    ThemeColorScheme(name: '青色', color: Colors.cyan, icon: Icons.waves),
    ThemeColorScheme(name: '绿色', color: Colors.green, icon: Icons.eco),
    ThemeColorScheme(name: '橙色', color: Colors.orange, icon: Icons.wb_sunny),
    ThemeColorScheme(name: '粉色', color: Colors.pink, icon: Icons.favorite),
    ThemeColorScheme(name: '红色', color: Colors.red, icon: Icons.local_fire_department),
    ThemeColorScheme(name: '靛蓝色', color: Colors.indigo, icon: Icons.nights_stay),
    ThemeColorScheme(name: '青柠色', color: Colors.lime, icon: Icons.energy_savings_leaf),
    ThemeColorScheme(name: '琥珀色', color: Colors.amber, icon: Icons.light_mode),
  ];
}

/// 主题管理器 - 使用单例模式管理应用主题
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal() {
    _loadSettings();
  }

  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = Colors.deepPurple;
  bool _followSystemColor = true; // 默认跟随系统主题色
  Color? _systemColor; // 系统主题色缓存
  ThemeFramework _themeFramework = ThemeFramework.material; // 默认使用 Material 3
  WindowEffect _windowEffect = WindowEffect.disabled; // 窗口材质效果
  bool _isApplyingWindowEffect = false; // 防止并发应用导致插件内部状态错误

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get followSystemColor => _followSystemColor;
  Color? get systemColor => _systemColor;
  ThemeFramework get themeFramework => _themeFramework;
  bool get isMaterialFramework => _themeFramework == ThemeFramework.material;
  bool get isFluentFramework => _themeFramework == ThemeFramework.fluent;
  WindowEffect get windowEffect => _windowEffect;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// 根据当前主题框架生成 ThemeData
  ThemeData buildThemeData(Brightness brightness) {
    return switch (_themeFramework) {
      ThemeFramework.material => _buildMaterialTheme(brightness),
      ThemeFramework.fluent => _buildFluentTheme(brightness),
    };
  }

  fluent.FluentThemeData buildFluentThemeData(Brightness brightness) {
    final useTransparent = Platform.isWindows && _windowEffect != WindowEffect.disabled;
    return fluent.FluentThemeData(
      brightness: brightness,
      accentColor: _buildAccentColor(_seedColor),
      fontFamily: 'Microsoft YaHei',
      scaffoldBackgroundColor: useTransparent ? fluent.Colors.transparent : null,
      navigationPaneTheme: fluent.NavigationPaneThemeData(
        backgroundColor: useTransparent ? fluent.Colors.transparent : null,
      ),
    );
  }

  ThemeData _buildMaterialTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Microsoft YaHei',
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        // 使用正常的背景色，避免透明导致深色模式下看不见文字
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  fluent.AccentColor _buildAccentColor(Color color) {
    return fluent.AccentColor.swatch({
      'lightest': _shiftColor(color, 0.5),
      'lighter': _shiftColor(color, 0.35),
      'light': _shiftColor(color, 0.2),
      'normal': color,
      'dark': _shiftColor(color, -0.15),
      'darker': _shiftColor(color, -0.3),
      'darkest': _shiftColor(color, -0.45),
    });
  }

  ThemeData _buildFluentTheme(Brightness brightness) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    final bool isLight = brightness == Brightness.light;
    final surface = isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1F1F1F);
    final background = isLight ? const Color(0xFFF3F3F3) : const Color(0xFF121212);
    final onSurface = isLight ? const Color(0xFF1B1B1B) : Colors.white;
    final borderColor = isLight
        ? Colors.black.withOpacity(0.06)
        : Colors.white.withOpacity(0.08);

    final colorScheme = baseScheme.copyWith(
      surface: surface,
      background: background,
      onSurface: onSurface,
    );

    return ThemeData(
      useMaterial3: false,
      fontFamily: 'Microsoft YaHei',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dialogBackgroundColor: surface,
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorColor: baseScheme.primary.withOpacity(0.18),
        selectedIconTheme: IconThemeData(color: baseScheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: baseScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: onSurface.withOpacity(0.7),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        selectedColor: baseScheme.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 4,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.all(baseScheme.primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return isLight ? const Color(0xFFE1E1E1) : const Color(0xFF2E2E2E);
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return baseScheme.primary;
          }
          return isLight ? const Color(0xFFC6C6C6) : const Color(0xFF3A3A3A);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        contentTextStyle: TextStyle(color: onSurface),
        actionTextColor: baseScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight
              ? Colors.black.withOpacity(0.85)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(
          color: isLight ? Colors.white : Colors.black,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: baseScheme.primary,
        unselectedLabelColor: onSurface.withOpacity(0.7),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: baseScheme.primary, width: 2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: baseScheme.primary, width: 1.8),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: baseScheme.primary,
        unselectedItemColor: onSurface.withOpacity(0.7),
        type: BottomNavigationBarType.fixed,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(baseScheme.primary),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: baseScheme.primary,
        inactiveTrackColor: onSurface.withOpacity(isLight ? 0.1 : 0.3),
        thumbColor: baseScheme.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: onSurface,
        centerTitle: false,
      ),
    );
  }

  Color _shiftColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0).toDouble();
    return hsl.withLightness(lightness).toColor();
  }

  /// 从本地存储加载主题设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载主题模式（默认为 light 亮色模式，避免首次启动跟随系统深色模式导致显示异常）
      final themeModeIndex = prefs.getInt('theme_mode') ?? ThemeMode.light.index;
      _themeMode = ThemeMode.values[themeModeIndex];
      
      // 加载跟随系统主题色设置（默认为 true）
      _followSystemColor = prefs.getBool('follow_system_color') ?? true;
      
      // 加载主题色
      final colorValue = prefs.getInt('seed_color') ?? Colors.deepPurple.value;
      _seedColor = Color(colorValue);

      // 加载桌面主题框架
      final frameworkIndex = prefs.getInt('theme_framework') ?? ThemeFramework.material.index;
      if (frameworkIndex >= 0 && frameworkIndex < ThemeFramework.values.length) {
        _themeFramework = ThemeFramework.values[frameworkIndex];
      } else {
        _themeFramework = ThemeFramework.material;
      }

      // 加载窗口材质（默认：Windows 11 设为 Mica，否则 Disabled）
      final windowEffectIndex = prefs.getInt('window_effect');
      if (windowEffectIndex != null && windowEffectIndex >= 0 && windowEffectIndex < WindowEffect.values.length) {
        _windowEffect = WindowEffect.values[windowEffectIndex];
      } else {
        if (Platform.isWindows) {
          // 假定 Windows 11 优先使用 Mica；若不支持，运行时应用时会回退
          _windowEffect = WindowEffect.mica;
        } else {
          _windowEffect = WindowEffect.disabled;
        }
      }
      
      print('🎨 [ThemeManager] 从本地加载主题: ${_themeMode.name}');
      print('🎨 [ThemeManager] 跟随系统主题色: $_followSystemColor');
      print('🎨 [ThemeManager] 主题色: 0x${_seedColor.value.toRadixString(16)}');
      print('🎨 [ThemeManager] 桌面主题框架: ${_themeFramework.name}');
      // 应用一次窗口材质并在帧后通知，避免在布局阶段触发重建
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _applyWindowEffectInternal();
        notifyListeners();
      });
    } catch (e) {
      print('❌ [ThemeManager] 加载主题设置失败: $e');
    }
  }

  /// 保存主题模式到本地
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', _themeMode.index);
      print('💾 [ThemeManager] 主题模式已保存: ${_themeMode.name}');
    } catch (e) {
      print('❌ [ThemeManager] 保存主题模式失败: $e');
    }
  }

  /// 保存主题色到本地
  Future<void> _saveSeedColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('seed_color', _seedColor.value);
      print('💾 [ThemeManager] 主题色已保存: 0x${_seedColor.value.toRadixString(16)}');
    } catch (e) {
      print('❌ [ThemeManager] 保存主题色失败: $e');
    }
  }

  /// 保存跟随系统主题色设置到本地
  Future<void> _saveFollowSystemColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('follow_system_color', _followSystemColor);
      print('💾 [ThemeManager] 跟随系统主题色设置已保存: $_followSystemColor');
    } catch (e) {
      print('❌ [ThemeManager] 保存跟随系统主题色设置失败: $e');
    }
  }

  /// 保存桌面主题框架到本地
  Future<void> _saveThemeFramework() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_framework', _themeFramework.index);
      print('💾 [ThemeManager] 桌面主题框架已保存: ${_themeFramework.name}');
    } catch (e) {
      print('❌ [ThemeManager] 保存桌面主题框架失败: $e');
    }
  }

  /// 切换主题模式
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemeMode();
      // 深浅色改变时更新窗口材质（Mica/Acrylic 受暗色影响），放到帧结束后执行
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _applyWindowEffectInternal();
        notifyListeners();
      });
    }
  }

  /// 切换深色模式开关
  void toggleDarkMode(bool isDark) {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  /// 跟随系统主题
  void setSystemMode() {
    setThemeMode(ThemeMode.system);
  }

  /// 设置主题色
  void setSeedColor(Color color) {
    if (_seedColor != color) {
      _seedColor = color;
      _saveSeedColor();
      
      // 手动设置主题色时，自动关闭跟随系统主题色
      if (_followSystemColor) {
        _followSystemColor = false;
        _saveFollowSystemColor();
        print('ℹ️ [ThemeManager] 手动设置主题色，已自动关闭跟随系统主题色');
      }
      
      notifyListeners();
    }
  }

  /// 设置跟随系统主题色
  Future<void> setFollowSystemColor(bool follow, {BuildContext? context}) async {
    if (_followSystemColor != follow) {
      _followSystemColor = follow;
      await _saveFollowSystemColor();
      
      if (follow && context != null) {
        // 如果启用跟随系统主题色，立即尝试获取并应用系统颜色
        await fetchAndApplySystemColor(context);
      }
      
      notifyListeners();
    }
  }

  /// 设置桌面端主题框架
  void setThemeFramework(ThemeFramework framework) {
    if (_themeFramework != framework) {
      _themeFramework = framework;
      _saveThemeFramework();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _applyWindowEffectInternal();
        notifyListeners();
      });
    }
  }

  /// 保存窗口材质到本地
  Future<void> _saveWindowEffect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('window_effect', _windowEffect.index);
      print('💾 [ThemeManager] 窗口材质已保存: ${_windowEffect.name}');
    } catch (e) {
      print('❌ [ThemeManager] 保存窗口材质失败: $e');
    }
  }

  /// 设置窗口材质
  Future<void> setWindowEffect(WindowEffect effect) async {
    if (_windowEffect != effect) {
      _windowEffect = effect;
      await _saveWindowEffect();
      // 在当前帧结束后应用，避免在复杂布局（如 SliverGrid）布局阶段触发重建
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _applyWindowEffectInternal();
        notifyListeners();
      });
    }
  }

  /// 应用窗口材质（仅 Windows）
  Future<void> _applyWindowEffectInternal() async {
    if (!Platform.isWindows) return;
    if (_isApplyingWindowEffect) return;
    _isApplyingWindowEffect = true;
    try {
      switch (_windowEffect) {
        case WindowEffect.disabled:
          await Window.setEffect(effect: WindowEffect.disabled);
          break;
        case WindowEffect.mica:
          await Window.setEffect(effect: WindowEffect.mica, dark: isDarkMode);
          break;
        case WindowEffect.acrylic:
          await Window.setEffect(
            effect: WindowEffect.acrylic,
            color: isDarkMode ? const Color(0xCC222222) : const Color(0xCCFFFFFF),
          );
          break;
        case WindowEffect.transparent:
          await Window.setEffect(effect: WindowEffect.transparent);
          break;
        default:
          await Window.setEffect(effect: WindowEffect.disabled);
      }
      // 隐藏系统窗口默认控制区域，避免与自定义标题栏按钮重叠
      await Window.hideWindowControls();
      await Window.hideTitle();
      print('✨ [ThemeManager] 已应用窗口材质: ${_windowEffect.name} (dark=$isDarkMode)');
    } catch (e) {
      print('⚠️ [ThemeManager] 应用窗口材质失败，将回退到默认: $e');
      try {
        await Window.setEffect(effect: WindowEffect.disabled);
      } catch (_) {}
    } finally {
      _isApplyingWindowEffect = false;
    }
  }

  /// 获取并应用系统主题色
  Future<void> fetchAndApplySystemColor(BuildContext context) async {
    if (!_followSystemColor) {
      print('ℹ️ [ThemeManager] 跟随系统主题色已关闭，跳过');
      return;
    }

    try {
      print('🎨 [ThemeManager] 开始获取系统主题色...');
      final systemColor = await SystemThemeColorService().getSystemThemeColor(context);
      
      if (systemColor != null) {
        _systemColor = systemColor;
        _seedColor = systemColor;
        await _saveSeedColor();
        print('✅ [ThemeManager] 已应用系统主题色: 0x${systemColor.value.toRadixString(16)}');
        notifyListeners();
      } else {
        print('⚠️ [ThemeManager] 无法获取系统主题色，保持当前颜色');
      }
    } catch (e) {
      print('❌ [ThemeManager] 获取系统主题色失败: $e');
    }
  }

  /// 初始化系统主题色（应在应用启动时调用）
  Future<void> initializeSystemColor(BuildContext context) async {
    if (_followSystemColor) {
      print('🎨 [ThemeManager] 初始化：跟随系统主题色已启用');
      await fetchAndApplySystemColor(context);
    } else {
      print('🎨 [ThemeManager] 初始化：使用自定义主题色');
    }
  }

  /// 获取当前主题色在预设列表中的索引
  int getCurrentColorIndex() {
    for (int i = 0; i < ThemeColors.presets.length; i++) {
      if (ThemeColors.presets[i].color.value == _seedColor.value) {
        return i;
      }
    }
    return 0; // 默认返回第一个
  }

  /// 获取主题色来源描述
  String getThemeColorSource() {
    if (_followSystemColor) {
      if (_systemColor != null) {
        return '系统主题色';
      } else {
        return '跟随系统（获取中...）';
      }
    } else {
      return '自定义';
    }
  }
}
