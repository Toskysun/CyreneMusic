import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/rhythm_service.dart';

/// 动态网格渐变背景组件 (Apple Music 风格重写版)
/// 通过多层随机位移的色块 + 深度高斯模糊实现丝滑液态效果
class MeshGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final double speed;
  final Color backgroundColor;
  final bool animate;
  /// 是否使用模拟节奏（非 Windows 平台自动启用）
  final bool? simulateRhythm;

  const MeshGradientBackground({
    super.key,
    required this.colors,
    this.speed = 0.35,
    this.backgroundColor = Colors.black,
    this.animate = true,
    this.simulateRhythm,
  });

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with TickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  
  // 用于色彩平滑过渡的控制器
  late AnimationController _colorController;
  List<Color> _previousColors = [];
  List<Color> _currentColors = [];
  List<Color> _targetColors = [];

  // 律动相关
  StreamSubscription? _rhythmSubscription;
  double _bassIntensity = 0.0;
  double _extraTime = 0.0; // 用于根据节奏加速时间

  // 判断是否应该使用模拟节奏
  bool get _shouldSimulateRhythm {
    if (widget.simulateRhythm != null) return widget.simulateRhythm!;
    // 非 Windows 平台自动启用模拟模式
    if (kIsWeb) return true;
    return !Platform.isWindows;
  }

  @override
  void initState() {
    super.initState();
    _currentColors = _ensureMinColors(widget.colors);
    _previousColors = List.from(_currentColors);
    _targetColors = List.from(_currentColors);

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _ticker = createTicker(_onTick);
    if (widget.animate) {
      _ticker.start();
      if (!_shouldSimulateRhythm) {
        _setupRhythmListener();
      }
    }
  }

  void _setupRhythmListener() {
    _rhythmSubscription?.cancel();
    _rhythmSubscription = RhythmService().bandsStream.listen((bands) {
      if (!mounted) return;
      setState(() {
        _bassIntensity = RhythmService().bassIntensity;
      });
    });
    // Windows 平台默认启动捕获
    RhythmService().start();
  }

  List<Color> _ensureMinColors(List<Color> colors) {
    if (colors.isEmpty) return DynamicBackgroundColorExtractor.getDefaultColors();
    List<Color> result = List.from(colors);
    // 补齐到至少 5 个颜色以保证丰富度
    while (result.length < 5) {
      result.add(result[result.length % result.length].withOpacity(0.8));
    }
    return result;
  }

  @override
  void didUpdateWidget(MeshGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (!_colorsEqual(oldWidget.colors, widget.colors)) {
      _previousColors = List.from(_currentColors);
      _targetColors = _ensureMinColors(widget.colors);
      _colorController.forward(from: 0.0);
    } else if (widget.colors.isNotEmpty && _currentColors.isEmpty) {
      // 容错处理：如果当前颜色为空但新传入了颜色，强制初始化
      _targetColors = _ensureMinColors(widget.colors);
      _currentColors = List.from(_targetColors);
    }
    
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _ticker.start();
        _setupRhythmListener();
      } else {
        _ticker.stop();
        _rhythmSubscription?.cancel();
        RhythmService().stop();
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
    if (!mounted) return;
    
    // 模拟节奏模式：使用正弦波生成平滑的强度变化
    if (_shouldSimulateRhythm) {
      final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
      // 多重正弦波叠加，模拟自然的节奏感
      _bassIntensity = 0.25 + 
          0.15 * math.sin(elapsedSeconds * 2.5) + 
          0.10 * math.sin(elapsedSeconds * 1.7 + 0.5) +
          0.08 * math.sin(elapsedSeconds * 4.1 + 1.2);
      _bassIntensity = _bassIntensity.clamp(0.0, 0.8);
    }
    
    // 根据重低音强度增加额外的时间偏移，产生动态加速感
    _extraTime += _bassIntensity * 0.03;
    
    setState(() {
      _time = (elapsed.inMilliseconds / 1000.0 * widget.speed) + _extraTime;
      
      // 更新当前色彩（平滑过渡）
      if (_colorController.isAnimating) {
        final t = Curves.easeInOut.transform(_colorController.value);
        _currentColors = List.generate(_targetColors.length, (i) {
          final startColor = i < _previousColors.length ? _previousColors[i] : _previousColors.last;
          return Color.lerp(startColor, _targetColors[i], t)!;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _colorController.dispose();
    _rhythmSubscription?.cancel();
    // 注意：这里不全局停止 RhythmService，因为可能有多个背景引用，或者全局生命周期管理
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          // 核心绘制层
          CustomPaint(
            painter: _MeshGradientPainter(
              colors: _currentColors,
              time: _time,
              backgroundColor: widget.backgroundColor,
              bassIntensity: _bassIntensity,
            ),
            size: Size.infinite,
          ),
          // 质感杂色层 (Grain/Noise)
          const Positioned.fill(child: _GrainTexture()),
        ],
      ),
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double time;
  final Color backgroundColor;
  final double bassIntensity;

  _MeshGradientPainter({
    required this.colors,
    required this.time,
    required this.backgroundColor,
    required this.bassIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || colors.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. 绘制底层渐变 (参考 bg.html linear-gradient(40deg, #1a0b2e, #2e1a47))
    final bgHSL = HSLColor.fromColor(backgroundColor);
    final bgDarker = bgHSL.withLightness((bgHSL.lightness * 0.8).clamp(0.0, 1.0)).toColor();
    final bgLighter = bgHSL.withLightness((bgHSL.lightness * 1.2).clamp(0.0, 1.0)).toColor();

    final bgGradient = ui.Gradient.linear(
      Offset(0, size.height),
      Offset(size.width, 0),
      [bgDarker, bgLighter],
      [0.0, 1.0],
    );
    canvas.drawRect(Offset.zero & size, paint..shader = bgGradient);
    paint.shader = null;

    final double shortestSide = size.shortestSide;
    final double longestSide = size.longestSide;

    // 2. 绘制 5 个动态光斑 (参考 bg.html)
    // 映射颜色：确保至少有 5 个颜色
    final activeColors = colors;
    
    // 定义 5 个光斑的配置
    final blobConfigs = [
      // Blob 1: 左上，金黄色/橙色变体
      _BlobConfig(
        basePos: const Offset(-0.1, -0.1),
        sizeRatio: 0.5 * (longestSide / shortestSide),
        speed: 1.0,
        blendMode: BlendMode.screen,
        moveFn: (time, i) {
          return Offset(
            0.2 * math.sin(time * 0.3),
            0.2 * math.cos(time * 0.2),
          );
        },
        scaleFn: (time) => 1.0 + 0.2 * math.sin(time * 0.4),
      ),
      // Blob 2: 左下，艳丽玫红色变体
      _BlobConfig(
        basePos: const Offset(-0.1, 1.1),
        sizeRatio: 0.6 * (longestSide / shortestSide),
        speed: 0.8,
        blendMode: BlendMode.screen,
        moveFn: (time, i) {
          return Offset(
            0.25 * math.cos(time * 0.25),
            -0.2 * math.sin(time * 0.3),
          );
        },
        rotateFn: (time) => time * 0.2,
      ),
      // Blob 3: 右上，淡蓝色/青色变体
      _BlobConfig(
        basePos: const Offset(1.1, -0.2),
        sizeRatio: 0.55 * (longestSide / shortestSide),
        speed: 0.9,
        blendMode: BlendMode.screen,
        moveFn: (time, i) {
          return Offset(
            -0.2 * math.sin(time * 0.35),
            0.25 * math.cos(time * 0.2),
          );
        },
        scaleFn: (time) => 1.0 + 0.3 * math.sin(time * 0.3),
      ),
      // Blob 4: 右下，深蓝紫色变体
      _BlobConfig(
        basePos: const Offset(1.2, 1.2),
        sizeRatio: 0.7 * (longestSide / shortestSide),
        speed: 0.7,
        blendMode: BlendMode.screen,
        moveFn: (time, i) {
          return Offset(
            -0.25 * math.cos(time * 0.2),
            -0.25 * math.sin(time * 0.25),
          );
        },
        scaleFn: (time) => 0.8 + 0.2 * math.cos(time * 0.3),
      ),
      // Blob 5: 中间，高光
      _BlobConfig(
        basePos: const Offset(0.5, 0.5),
        sizeRatio: 0.4 * (longestSide / shortestSide),
        speed: 1.25,
        blendMode: BlendMode.overlay,
        moveFn: (time, i) {
          return Offset(
            0.2 * math.sin(time * 0.5),
            -0.2 * math.cos(time * 0.4),
          );
        },
        scaleFn: (time) => 1.0 + 0.4 * math.sin(time * 0.5),
        opacity: 0.6,
      ),
    ];

    for (int i = 0; i < 5; i++) {
      final config = blobConfigs[i];
      final color = activeColors[i % activeColors.length];
      
      final offset = config.moveFn(time, i);
      final centerX = size.width * (config.basePos.dx + offset.dx);
      final centerY = size.height * (config.basePos.dy + offset.dy);
      
      double radius = shortestSide * config.sizeRatio;
      if (config.scaleFn != null) {
        radius *= config.scaleFn!(time);
      }
      
      // 律动加成
      radius += (shortestSide * 0.1) * bassIntensity;
      
      if (radius < 10) radius = 10;

      final hsl = HSLColor.fromColor(color);
      final boostedColor = hsl
          .withSaturation((hsl.saturation + 0.1).clamp(0.4, 1.0))
          .withLightness((hsl.lightness + 0.05).clamp(0.3, 0.9))
          .toColor();

      final paintBlob = Paint()
        ..blendMode = config.blendMode
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (radius * 0.4).clamp(40, 150));

      final gradient = ui.Gradient.radial(
        Offset(centerX, centerY),
        radius,
        [
          boostedColor.withOpacity(config.opacity),
          boostedColor.withOpacity(config.opacity * 0.5),
          boostedColor.withOpacity(0.0),
        ],
        const [0.0, 0.4, 1.0],
      );

      paintBlob.shader = gradient;

      canvas.save();
      if (config.rotateFn != null) {
        canvas.translate(centerX, centerY);
        canvas.rotate(config.rotateFn!(time));
        canvas.translate(-centerX, -centerY);
      }
      canvas.drawCircle(Offset(centerX, centerY), radius, paintBlob);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MeshGradientPainter oldDelegate) => 
      oldDelegate.time != time || 
      oldDelegate.colors != colors ||
      oldDelegate.bassIntensity != bassIntensity;
}

class _BlobConfig {
  final Offset basePos;
  final double sizeRatio;
  final double speed;
  final BlendMode blendMode;
  final Offset Function(double time, int index) moveFn;
  final double Function(double time)? scaleFn;
  final double Function(double time)? rotateFn;
  final double opacity;

  _BlobConfig({
    required this.basePos,
    required this.sizeRatio,
    required this.speed,
    required this.blendMode,
    required this.moveFn,
    this.scaleFn,
    this.rotateFn,
    this.opacity = 0.8,
  });
}

/// 增加质感的杂色层
class _GrainTexture extends StatelessWidget {
  const _GrainTexture();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.04, // 非常微弱
      child: CustomPaint(
        painter: _GrainPainter(),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(123); // 固定种子
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    
    // 增加点数并减小尺寸，让噪点更细腻
    for (int i = 0; i < 2000; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final dotSize = 0.5 + random.nextDouble() * 0.8;
      canvas.drawRect(Rect.fromLTWH(x, y, dotSize, dotSize), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DynamicBackgroundColorExtractor {
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
    
    // 候选池：按优先级排序
    final List<Color?> candidates = [
      vibrantColor,
      mutedColor,
      dominantColor,
      darkVibrantColor,
      lightVibrantColor,
      darkMutedColor,
      lightMutedColor,
    ];

    // 1. 基础筛选与去重
    for (final color in candidates) {
      if (color != null && !_isSimilarColor(color, result)) {
        result.add(color);
      }
    }
    
    // 3. 增强逻辑：如果颜色少于 3 个，通过色相旋转生成互补/邻近色，确保背景丰富度
    if (result.length < 3) {
      if (result.isEmpty) {
        result.addAll(getDefaultColors());
      } else {
        final baseColor = result[0];
        final hsl = HSLColor.fromColor(baseColor);
        
        // 如果只有一个颜色，生成三元色 (Triadic) + 更大的明度差异
        if (result.length == 1) {
          // 第二色：色相 +120°，明度略微调暗
          final color2 = hsl
              .withHue((hsl.hue + 120) % 360)
              .withSaturation(math.max(hsl.saturation, 0.55))
              .withLightness((hsl.lightness - 0.15).clamp(0.2, 0.75))
              .toColor();
          // 第三色：色相 +240°，明度略微调亮
          final color3 = hsl
              .withHue((hsl.hue + 240) % 360)
              .withSaturation(math.max(hsl.saturation, 0.55))
              .withLightness((hsl.lightness + 0.15).clamp(0.25, 0.8))
              .toColor();
          result.add(color2);
          result.add(color3);
        } 
        // 如果有两个颜色，生成一个互补色（色相 +180°）
        else if (result.length == 2) {
          final color3 = hsl
              .withHue((hsl.hue + 180) % 360)
              .withSaturation(math.max(hsl.saturation, 0.5))
              .withLightness((hsl.lightness + 0.1).clamp(0.25, 0.75))
              .toColor();
          result.add(color3);
        }
      }
    }
    
    // 4. 最终补齐到 5 个（通过更大的色相偏移和明度变化防止单调）
    int fillIndex = 0;
    while (result.length < 5) {
      final base = result[fillIndex % result.length];
      final hsl = HSLColor.fromColor(base);
      // 交替使用不同的偏移策略
      final hueOffset = (fillIndex % 2 == 0) ? 45.0 : -30.0;
      final lightnessOffset = (fillIndex % 2 == 0) ? 0.18 : -0.12;
      result.add(hsl
          .withHue((hsl.hue + hueOffset) % 360)
          .withLightness((hsl.lightness + lightnessOffset).clamp(0.15, 0.85))
          .toColor());
      fillIndex++;
    }
    
    return result.take(5).toList();
  }
  
  /// 色彩相似度判定 (基于 HSL 颜色空间)
  /// 使用色相、饱和度、明度三个维度综合判断，比 RGB 欧几里得距离更符合人眼感知
  static bool _isSimilarColor(Color color, List<Color> existingColors) {
    final hsl = HSLColor.fromColor(color);
    
    for (final existing in existingColors) {
      final existingHsl = HSLColor.fromColor(existing);
      
      // 计算色相差（考虑色环的循环特性，0° 和 360° 是同一个颜色）
      double hueDiff = (hsl.hue - existingHsl.hue).abs();
      if (hueDiff > 180) hueDiff = 360 - hueDiff;
      
      // 明度差
      final lightnessDiff = (hsl.lightness - existingHsl.lightness).abs();
      
      // 饱和度差
      final saturationDiff = (hsl.saturation - existingHsl.saturation).abs();
      
      // 判定规则：
      // - 色相差 < 25° 且 明度差 < 0.12 且 饱和度差 < 0.2 => 认为相似
      // - 任一维度超出阈值则认为不同
      if (hueDiff < 25 && lightnessDiff < 0.12 && saturationDiff < 0.2) {
        return true;
      }
    }
    return false;
  }

  static Color _adjustBrightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static List<Color> getDefaultColors() => const [
    Color(0xFF60A5FA), Color(0xFF1E3A5F), Color(0xFF3B82F6),
    Color(0xFF6366F1), Color(0xFF1E1B4B),
  ];
}
