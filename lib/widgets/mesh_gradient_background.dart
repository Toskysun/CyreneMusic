import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 动态网格渐变背景组件
/// 模仿 Vue 项目中的 MeshGradient 效果
/// 使用 CustomPainter 实现高性能动画
class MeshGradientBackground extends StatefulWidget {
  /// 渐变使用的颜色列表（建议3-5个颜色）
  final List<Color> colors;
  
  /// 动画速度（0.0-1.0，默认0.3）
  final double speed;
  
  /// 背景色
  final Color backgroundColor;
  
  /// 是否启用动画
  final bool animate;

  const MeshGradientBackground({
    super.key,
    required this.colors,
    this.speed = 0.3,
    this.backgroundColor = Colors.black,
    this.animate = true,
  });

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  
  // 缓存的颜色列表，避免每帧重新创建
  List<Color> _cachedColors = [];
  
  // 性能优化：限制帧率
  static const double _targetFps = 30.0;
  static const double _frameInterval = 1000.0 / _targetFps;
  double _lastFrameTime = 0.0;

  @override
  void initState() {
    super.initState();
    _cachedColors = List.from(widget.colors);
    
    if (widget.animate) {
      _ticker = createTicker(_onTick);
      _ticker.start();
    } else {
      _ticker = createTicker((_) {});
    }
  }

  @override
  void didUpdateWidget(MeshGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 检查颜色是否变化
    if (!_colorsEqual(oldWidget.colors, widget.colors)) {
      _cachedColors = List.from(widget.colors);
    }
    
    // 处理动画状态变化
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        if (!_ticker.isActive) {
          _ticker.start();
        }
      } else {
        if (_ticker.isActive) {
          _ticker.stop();
        }
      }
    }
  }

  bool _colorsEqual(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toARGB32() != b[i].toARGB32()) return false;
    }
    return true;
  }

  void _onTick(Duration elapsed) {
    final currentTime = elapsed.inMilliseconds.toDouble();
    
    // 性能优化：限制帧率到30fps
    if (currentTime - _lastFrameTime < _frameInterval) {
      return;
    }
    _lastFrameTime = currentTime;
    
    setState(() {
      _time = elapsed.inMilliseconds / 1000.0 * widget.speed;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _MeshGradientPainter(
          colors: _cachedColors,
          time: _time,
          backgroundColor: widget.backgroundColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// 网格渐变绘制器
/// 模拟 Paper Shaders 的 MeshGradient 效果
/// 使用多个大型重叠色块填满整个画布
class _MeshGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double time;
  final Color backgroundColor;
  
  // 缓存画笔以提高性能
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  _MeshGradientPainter({
    required this.colors,
    required this.time,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    
    final width = size.width;
    final height = size.height;
    final diagonal = math.sqrt(width * width + height * height);
    
    // 首先用第一个颜色填充整个背景
    _paint.shader = null;
    _paint.color = colors[0];
    canvas.drawRect(Offset.zero & size, _paint);
    
    // 绘制多个大型流动色块，确保完全覆盖
    // 每个颜色绘制2个重叠的大色块（减少绘制次数提高性能）
    for (int colorIndex = 0; colorIndex < colors.length; colorIndex++) {
      for (int blobIndex = 0; blobIndex < 2; blobIndex++) {
        _drawLargeBlob(canvas, size, diagonal, colorIndex, blobIndex);
      }
    }
  }

  void _drawLargeBlob(Canvas canvas, Size size, double diagonal, int colorIndex, int blobIndex) {
    final color = colors[colorIndex];
    
    // 为每个色块创建独特的相位偏移
    final phase = colorIndex * math.pi * 2 / colors.length + blobIndex * math.pi * 0.7;
    final timeOffset = blobIndex * 0.3;
    
    // 计算动态中心位置 - 色块在整个画布范围内移动
    // 使用不同的频率和相位创建有机的流动效果
    final centerX = size.width * (0.5 + 0.6 * math.sin(time * 0.3 + phase + timeOffset));
    final centerY = size.height * (0.5 + 0.6 * math.cos(time * 0.25 + phase * 1.3 + timeOffset));
    
    // 使用非常大的半径确保色块覆盖大部分画布
    // 半径是对角线的 60-100%
    final baseRadius = diagonal * (0.6 + 0.4 * (colorIndex + blobIndex) / (colors.length + 2));
    final radius = baseRadius * (0.9 + 0.2 * math.sin(time * 0.4 + phase * 2));
    
    // 创建大型径向渐变 - 中心不透明，边缘透明
    // 使用更平滑的渐变过渡
    final gradient = ui.Gradient.radial(
      Offset(centerX, centerY),
      radius,
      [
        color.withValues(alpha: 0.85),
        color.withValues(alpha: 0.6),
        color.withValues(alpha: 0.3),
        color.withValues(alpha: 0.0),
      ],
      const [0.0, 0.3, 0.6, 1.0],
    );
    
    _paint.shader = gradient;
    
    // 绘制变形的椭圆形色块
    final scaleX = 1.0 + 0.4 * math.sin(time * 0.35 + phase + blobIndex);
    final scaleY = 1.0 + 0.4 * math.cos(time * 0.4 + phase * 1.2 + blobIndex);
    final rotation = time * 0.1 + phase;
    
    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(rotation);
    canvas.scale(scaleX, scaleY);
    canvas.drawCircle(Offset.zero, radius, _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MeshGradientPainter oldDelegate) {
    return oldDelegate.time != time ||
           oldDelegate.backgroundColor != backgroundColor ||
           !_colorsEqual(oldDelegate.colors, colors);
  }
  
  bool _colorsEqual(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toARGB32() != b[i].toARGB32()) return false;
    }
    return true;
  }
}

/// 动态背景颜色提取服务
/// 从专辑封面中提取3个不同的颜色用于动态背景
class DynamicBackgroundColorExtractor {
  /// 从 PaletteGenerator 结果中提取3个不同的颜色
  /// 优先选择：vibrant, muted, dominant
  static List<Color> extractColors({
    Color? vibrantColor,
    Color? mutedColor,
    Color? dominantColor,
    Color? lightVibrantColor,
    Color? darkVibrantColor,
    Color? lightMutedColor,
    Color? darkMutedColor,
  }) {
    final List<Color> result = [];
    
    // 优先添加 vibrant 颜色
    if (vibrantColor != null) {
      result.add(vibrantColor);
    }
    
    // 添加 muted 颜色
    if (mutedColor != null && !_isSimilarColor(mutedColor, result)) {
      result.add(mutedColor);
    }
    
    // 添加 dominant 颜色
    if (dominantColor != null && !_isSimilarColor(dominantColor, result)) {
      result.add(dominantColor);
    }
    
    // 如果颜色不够，添加其他变体
    if (result.length < 3 && darkVibrantColor != null && !_isSimilarColor(darkVibrantColor, result)) {
      result.add(darkVibrantColor);
    }
    
    if (result.length < 3 && lightVibrantColor != null && !_isSimilarColor(lightVibrantColor, result)) {
      result.add(lightVibrantColor);
    }
    
    if (result.length < 3 && darkMutedColor != null && !_isSimilarColor(darkMutedColor, result)) {
      result.add(darkMutedColor);
    }
    
    if (result.length < 3 && lightMutedColor != null && !_isSimilarColor(lightMutedColor, result)) {
      result.add(lightMutedColor);
    }
    
    // 如果仍然不够3个颜色，用默认颜色填充
    while (result.length < 3) {
      if (result.isEmpty) {
        result.add(const Color(0xFF60A5FA)); // 淡蓝色
      } else if (result.length == 1) {
        result.add(_adjustBrightness(result[0], 0.3));
      } else {
        result.add(_adjustBrightness(result[0], -0.3));
      }
    }
    
    return result.take(3).toList();
  }
  
  /// 检查颜色是否与列表中的颜色相似
  static bool _isSimilarColor(Color color, List<Color> existingColors) {
    for (final existing in existingColors) {
      if (_colorDistance(color, existing) < 50) {
        return true;
      }
    }
    return false;
  }
  
  /// 计算两个颜色之间的距离
  static double _colorDistance(Color a, Color b) {
    final dr = (a.r * 255).round() - (b.r * 255).round();
    final dg = (a.g * 255).round() - (b.g * 255).round();
    final db = (a.b * 255).round() - (b.b * 255).round();
    return math.sqrt(dr * dr + dg * dg + db * db);
  }
  
  /// 调整颜色亮度
  static Color _adjustBrightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final newLightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }
  
  /// 获取默认的动态背景颜色（当无法从封面提取时使用）
  static List<Color> getDefaultColors() {
    return const [
      Color(0xFF60A5FA), // 淡蓝色
      Color(0xFF1E3A5F), // 深蓝色
      Color(0xFF3B82F6), // 蓝色
    ];
  }
}
