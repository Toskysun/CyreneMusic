import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../services/player_service.dart';
import '../../services/lyric_font_service.dart';
import '../../services/lyric_style_service.dart';
import '../../models/lyric_line.dart';

/// 核心：弹性间距动画 + 波浪式延迟 (1:1 复刻 HTML)
class PlayerFluidCloudLyricsPanel extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;
  final int visibleLineCount;

  const PlayerFluidCloudLyricsPanel({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.showTranslation,
    this.visibleLineCount = 7,
  });

  @override
  State<PlayerFluidCloudLyricsPanel> createState() => _PlayerFluidCloudLyricsPanelState();
}

class _PlayerFluidCloudLyricsPanelState extends State<PlayerFluidCloudLyricsPanel>
    with TickerProviderStateMixin {
  
  // 核心变量
  final double _lineHeight = 100.0;
  static const double _maxActiveScale = 1.15; // 最大活跃缩放比例
  // HTML 中是 80px，这里我们也用 80 逻辑像素
  
  // 滚动/拖拽相关
  double _dragOffset = 0.0;
  bool _isDragging = false;
  Timer? _dragResetTimer;

  // [New] 布局缓存
  final Map<String, double> _heightCache = {};
  double? _lastViewportWidth;
  String? _lastFontFamily;
  bool? _lastShowTranslation;
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _dragResetTimer?.cancel();
    super.dispose();
  }

  // 简单的拖拽手势处理，允许用户微调查看
  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragResetTimer?.cancel();
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
    });
  }

  void _onDragEnd(DragEndDetails details) {
     // 拖拽结束后，延时回弹归位
     _dragResetTimer = Timer(const Duration(milliseconds: 600), () {
       if (mounted) {
         setState(() {
           _isDragging = false;
           _dragOffset = 0.0; 
         });
       }
     });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return _buildNoLyric();
    }

    return AnimatedBuilder(
      animation: LyricStyleService(),
      builder: (context, _) {
        final lyricStyle = LyricStyleService();
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;
            final viewportWidth = constraints.maxWidth;
            
            // 根据对齐设置动态计算中心点偏移
            // 居中对齐：50%; 顶部对齐：25% (稍微靠上但不至于刷到最顶部)
            final centerY = lyricStyle.currentAlignment == LyricAlignment.center 
                ? viewportHeight * 0.5 
                : viewportHeight * 0.25;
            
            // 可视区域计算
            final visibleBuffer = 6; 
            final visibleLines = (viewportHeight / _lineHeight).ceil(); // 估算
            final minIndex = max(0, widget.currentLyricIndex - visibleBuffer - (visibleLines ~/ 2));
            final maxIndex = min(widget.lyrics.length - 1, widget.currentLyricIndex + visibleBuffer + (visibleLines ~/ 2));

            // [New] 动态高度计算
            // 1. 计算每个可见 Item 的高度
            final Map<int, double> heights = {};
            // 🔥 关键重构：为了应对活跃行 1.15x 的放大，基础布局宽度需要收缩
            // 使得 基础宽度 * 1.15 = 视口宽度。这样放大后文字刚好贴边不溢出。
            final layoutWidth = viewportWidth / _maxActiveScale;
            final textMaxWidth = layoutWidth - 80; // horizontal padding 40 * 2
            
            for (int i = minIndex; i <= maxIndex; i++) {
              heights[i] = _measureLyricItemHeight(i, textMaxWidth);
            }

            // 2. 计算偏移量 (相对于 activeIndex 中心)
            final Map<int, double> offsets = {};
            offsets[widget.currentLyricIndex] = 0;

            // 🔥 关键重构：完全自适应偏移量计算
            // 每一行在垂直布局中占用的空间 = 其原始高度 * 对应的缩放比例
            
            double currentOffset = 0;
            // 活跃行的半高度（已缩放）
            double prevHalfHeight = ((heights[widget.currentLyricIndex] ?? _lineHeight) * 1.15) / 2;
            
            for (int i = widget.currentLyricIndex + 1; i <= maxIndex; i++) {
              final h = heights[i] ?? _lineHeight;
              final s = _getScaleSync(i - widget.currentLyricIndex); // 获取目标行的最终缩放比例
              final scaledHalfHeight = (h * s) / 2;
              currentOffset += prevHalfHeight + scaledHalfHeight; 
              offsets[i] = currentOffset;
              prevHalfHeight = scaledHalfHeight;
            }

            // 向上累加 (active - 1, active - 2 ...)
            currentOffset = 0;
            double nextHalfHeight = ((heights[widget.currentLyricIndex] ?? _lineHeight) * 1.15) / 2;
            
            for (int i = widget.currentLyricIndex - 1; i >= minIndex; i--) {
              final h = heights[i] ?? _lineHeight;
              final s = _getScaleSync(i - widget.currentLyricIndex);
              final scaledHalfHeight = (h * s) / 2;
              currentOffset -= (nextHalfHeight + scaledHalfHeight);
              offsets[i] = currentOffset;
              nextHalfHeight = scaledHalfHeight;
            }

            List<Widget> children = [];
            for (int i = minIndex; i <= maxIndex; i++) {
              children.add(_buildLyricItem(i, centerY, offsets[i] ?? 0.0, heights[i] ?? _lineHeight, layoutWidth));
            }

            return GestureDetector(
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              behavior: HitTestBehavior.translucent, 
              child: Stack(
                fit: StackFit.expand,
                children: children,
              ),
            );
          },
        );
      },
    );
  }

  /// 估算歌词项高度
  double _measureLyricItemHeight(int index, double maxWidth) {
    if (index < 0 || index >= widget.lyrics.length) return _lineHeight;
    final lyric = widget.lyrics[index];
    final fontFamily = LyricFontService().currentFontFamily ?? 'Microsoft YaHei';
    
    // [Optimization] 检查缓存
    final cacheKey = '${lyric.startTime.inMilliseconds}_${lyric.text.hashCode}_$maxWidth';
    if (_lastViewportWidth == maxWidth && 
        _lastFontFamily == fontFamily && 
        _lastShowTranslation == widget.showTranslation &&
        _heightCache.containsKey(cacheKey)) {
      return _heightCache[cacheKey]!;
    }

    final fontSize = 32.0; // 与 _buildInnerContent 保持一致

    // 测量原文高度 (maxLines: 2)
    final textPainter = TextPainter(
      text: TextSpan(
        text: lyric.text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      // 移除 maxLines 限制，实现自适应宽度换行后的真实高度测量
    );
    textPainter.layout(maxWidth: maxWidth);
    
    // 计算行数以补偿 _WordFillWidget 内部的 Padding (上下共 12.0)
    int numLines = (textPainter.height / (fontSize * 1.15)).round();
    if (numLines <= 0) numLines = 1;
    double h = textPainter.height + (numLines * 12.0); 

    // 测量翻译高度
    if (widget.showTranslation && lyric.translation != null && lyric.translation!.isNotEmpty) {
      final transPainter = TextPainter(
        text: TextSpan(
          text: lyric.translation,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 18, // 与 _buildInnerContent 保持一致
            fontWeight: FontWeight.w600,
            height: 1.4, // 保持与渲染一致的 height
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      transPainter.layout(maxWidth: maxWidth);
      h += 4.0; // 降低原文与译文之间的间距 (原 8.0)
      h += transPainter.height; // 使用真实高度
    }
    
    // 增加最后的一点安全余量 (底部额外留白)
    h += 8.0; 
    
    // 保证最小高度，避免空行太窄
    final result = max(h, _lineHeight);
    
    // 更新缓存状态
    _lastViewportWidth = maxWidth;
    _lastFontFamily = fontFamily;
    _lastShowTranslation = widget.showTranslation;
    _heightCache[cacheKey] = result;
    
    return result;
  }

  /// 内部辅助方法：计算同步缩放值（用于偏移量预计算）
  double _getScaleSync(int diff) {
    if (diff == 0) return _maxActiveScale;
    if (diff.abs() < 3) return 1.0 - diff.abs() * 0.1;
    return 0.7;
  }

  Widget _buildLyricItem(int index, double centerYOffset, double relativeOffset, double itemHeight, double layoutWidth) {
    final activeIndex = widget.currentLyricIndex;
    final diff = index - activeIndex;
    
    // 1. 基础位移 (改为使用预计算的相对 Dynamic Offset)
    final double baseTranslation = relativeOffset;
    
    // 2. 正弦偏移：保持原有的“果冻”弹性算法
    // Math.sin(diff * 0.8) * 20
    final double sineOffset = sin(diff * 0.8) * 20.0;
    
    // 4. 缩放逻辑
    double targetScale = _getScaleSync(diff);

    // 5. 最终Y坐标
    // centerYOffset 是屏幕中心
    // baseTranslation 是该 Item 中心相对于屏幕中心的偏移
    // sineOffset 是动画偏移
    // 最后要减去 (itemHeight * targetScale) / 2 因为 Positioned top 是左上角
    double targetY = centerYOffset + baseTranslation + sineOffset - (itemHeight * targetScale / 2);

    // 叠加拖拽偏移
    if (_isDragging) {
       targetY += _dragOffset;
    }
    
    // 6. 透明度逻辑
    // const opacity = Math.abs(diff) > 4 ? 0 : 1 - Math.abs(diff) * 0.2;
    double targetOpacity;
    if (diff.abs() > 4) {
      targetOpacity = 0.0;
    } else {
      targetOpacity = 1.0 - diff.abs() * 0.2;
    }
    targetOpacity = targetOpacity.clamp(0.0, 1.0).toDouble();

    // 6. 延迟逻辑
    // transitionDelay = ${Math.abs(diff) * 0.05}s
    final int delayMs = (diff.abs() * 50).toInt();

    // 7. 模糊逻辑
    // active: 0, near (diff=1): 1px, others: 4px
    double targetBlur = 4.0;
    if (diff == 0) targetBlur = 0.0;
    else if (diff.abs() == 1) targetBlur = 1.0;

    final bool isActive = (diff == 0);

    return _ElasticLyricLine(
      key: ValueKey(index), // 保持 Key 稳定以复用 State
      text: widget.lyrics[index].text,
      translation: widget.lyrics[index].translation,
      lyric: widget.lyrics[index], 
      lyrics: widget.lyrics,     
      index: index,             
      lineHeight: _lineHeight,
      viewportWidth: layoutWidth, // [Refactor] 这里传递其实是缩减后的基础布局宽度
      targetY: targetY,
      targetScale: targetScale,
      targetOpacity: targetOpacity,
      targetBlur: targetBlur,
      isActive: isActive,
      delay: Duration(milliseconds: delayMs),
      isDragging: _isDragging,
      showTranslation: widget.showTranslation,
    );
  }

  Widget _buildNoLyric() {
    return const Center(
      child: Text(
        '暂无歌词',
        style: TextStyle(color: Colors.white54, fontSize: 24),
      ),
    );
  }
}

/// 能够处理延迟和弹性动画的单行歌词组件
/// 对应 HTML .lyric-line 及其 CSS transition
class _ElasticLyricLine extends StatefulWidget {
  final String text;
  final String? translation;
  final LyricLine lyric;
  final List<LyricLine> lyrics;
  final int index;
  final double lineHeight;
  final double viewportWidth;
  
  final double targetY;
  final double targetScale;
  final double targetOpacity;
  final double targetBlur;
  final bool isActive;
  final Duration delay;
  final bool isDragging;
  final bool showTranslation;

  const _ElasticLyricLine({
    Key? key,
    required this.text,
    this.translation,
    required this.lyric,
    required this.lyrics,
    required this.index,
    required this.lineHeight,
    required this.viewportWidth,
    required this.targetY,
    required this.targetScale,
    required this.targetOpacity,
    required this.targetBlur,
    required this.isActive,
    required this.delay,
    required this.isDragging,
    required this.showTranslation,
  }) : super(key: key);

  @override
  State<_ElasticLyricLine> createState() => _ElasticLyricLineState();
}

class _ElasticLyricLineState extends State<_ElasticLyricLine> with TickerProviderStateMixin {
  // 当前动画值
  late double _y;
  late double _scale;
  late double _opacity;
  late double _blur;
  
  AnimationController? _controller;
  Animation<double>? _yAnim;
  Animation<double>? _scaleAnim;
  Animation<double>? _opacityAnim;
  Animation<double>? _blurAnim;
  
  Timer? _delayTimer;

  // HTML CSS: transition: transform 0.8s cubic-bezier(0.34, 1.56, 0.64, 1)
  // 这是带回弹的曲线
  static const Curve elasticCurve = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Duration animDuration = Duration(milliseconds: 800);
  
  @override
  void initState() {
    super.initState();
    _y = widget.targetY;
    _scale = widget.targetScale;
    _opacity = widget.targetOpacity;
    _blur = widget.targetBlur;
  }

  @override
  void didUpdateWidget(_ElasticLyricLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 使用 Epsilon 阈值防止微小浮点误差/UI抖动导致的动画频繁重启
    const double epsilon = 0.05;
    
    // 只在变化显著时才触发动画
    bool positionChanged = (oldWidget.targetY - widget.targetY).abs() > epsilon;
    bool scaleChanged = (oldWidget.targetScale - widget.targetScale).abs() > 0.001;
    bool opacityChanged = (oldWidget.targetOpacity - widget.targetOpacity).abs() > 0.01;
    bool blurChanged = (oldWidget.targetBlur - widget.targetBlur).abs() > 0.1;
    
    if (positionChanged || scaleChanged || opacityChanged || blurChanged) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _delayTimer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    _delayTimer?.cancel();
    
    // 如果正在拖拽，或者目标一致，则不播放动画
    if (widget.isDragging) {
      _controller?.stop();
      setState(() {
        _y = widget.targetY;
        _scale = widget.targetScale;
        _opacity = widget.targetOpacity;
        _blur = widget.targetBlur;
      });
      return;
    }

    void play() {
      // 创建新的控制器
      _controller?.dispose();
      _controller = AnimationController(
        vsync: this,
        duration: animDuration,
      );

      _yAnim = Tween<double>(begin: _y, end: widget.targetY).animate(
        CurvedAnimation(parent: _controller!, curve: elasticCurve)
      );
      _scaleAnim = Tween<double>(begin: _scale, end: widget.targetScale).animate(
         CurvedAnimation(parent: _controller!, curve: elasticCurve)
      );
      // Opacity/Blur 使用 ease，避免回弹导致闪烁
      _opacityAnim = Tween<double>(begin: _opacity, end: widget.targetOpacity).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.ease)
      );
      _blurAnim = Tween<double>(begin: _blur, end: widget.targetBlur).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.ease)
      );

      _controller!.addListener(() {
        if (!mounted) return;
        setState(() {
          _y = _yAnim!.value;
          _scale = _scaleAnim!.value;
          _opacity = _opacityAnim!.value;
          _blur = _blurAnim!.value;
        });
      });

      _controller!.forward();
    }

    if (widget.delay == Duration.zero) {
      play();
    } else {
      _delayTimer = Timer(widget.delay, play);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 性能优化：如果透明度极低，不渲染
    if (_opacity < 0.01) return const SizedBox();

    return Positioned(
      top: _y,
      left: 0,
      width: widget.viewportWidth, // [Refactor] 显式设置宽度为缩减后的 layoutWidth
      // height: widget.lineHeight, // Remove strict height constraint
      child: Transform.scale(
        scale: _scale,
        alignment: Alignment.centerLeft, // HTML: transform-origin: left center
        child: Opacity(
          opacity: _opacity,
          child: _OptionalBlur(
            blur: _blur,
            child: Container(
              // 关键约束：限制渲染宽度与测量宽度一致
              constraints: BoxConstraints(maxWidth: widget.viewportWidth),
              padding: const EdgeInsets.symmetric(horizontal: 40), // HTML: padding: 0 40px
              alignment: Alignment.centerLeft, // HTML: display: flex; align-items: center
              child: _buildInnerContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerContent() {
    final fontFamily = LyricFontService().currentFontFamily ?? 'Microsoft YaHei';
    
    // HTML font-size: 2.4rem.
    // 我们使用固定大小，或者根据需求调整。原 Flutter 代码是 32。
    final double textFontSize = 32.0;

    // 颜色:
    // HTML .lyric-line.active -> rgba(255, 255, 255, 1)
    // HTML .lyric-line -> rgba(255, 255, 255, 0.2)
    // 我们的 _opacity 已经模拟了整体容器的透明度。
    // 但是 HTML 同时改变了 color 和 opacity。
    // Active 行 color 是完全不透明白色。
    // 非 Active 行 color 是 0.2 白。
    // 加上容器 opacity，非 Active 行会非常暗 (0.2 * opacity)。
    // 为了匹配效果，我们需要同时调整 color 的 opacity。
    
    Color textColor;
    if (widget.isActive) {
      textColor = Colors.white;
    } else {
      // 匹配 HTML rgba(255, 255, 255, 0.2)
      textColor = Colors.white.withOpacity(0.3); 
    }
    
    // 构建文本 Widget
    Widget textWidget;
    // 只有当服务端提供了逐字歌词(hasWordByWord)时，才启用卡拉OK动画
    // 否则仅保留基础的变白+放大效果 (由 textColor 和 parent scale控制)
    if (widget.isActive && widget.lyric.hasWordByWord) {
      textWidget = _KaraokeText(
        text: widget.text,
        lyric: widget.lyric,
        lyrics: widget.lyrics,
        index: widget.index,
        originalTextStyle: TextStyle(
             fontFamily: fontFamily,
             fontSize: textFontSize, 
             fontWeight: FontWeight.w800,
             color: Colors.white,
             height: 1.15, // 缩小行高以修复间距过大问题
        ),
      );
    } else {
      textWidget = Text(
        widget.text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: textFontSize, 
          fontWeight: FontWeight.w800,
          color: textColor,
          height: 1.15, // 缩小行高以修复间距过大问题
        ),
      );
    }
    
    // 如果有翻译
    if (widget.showTranslation && widget.translation != null && widget.translation!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          textWidget,
          Padding(
            padding: const EdgeInsets.only(top: 4.0), // 缩小译文间距 (原 8.0)
            child: Text(
              widget.translation!,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.3),
                height: 1.4, // 增加行高防止译文本身换行时拥挤
              ),
            ),
          )
        ],
      );
    }
    
    // 如果是第一行，且活跃，显示倒计时点 (Features)
    if (widget.index == 0 && !widget.isDragging) {
       return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           _CountdownDots(lyrics: widget.lyrics, countdownThreshold: 5.0),
           textWidget, 
        ]
       );
    }

    return textWidget;
  }
}

/// 性能优化：模糊组件
class _OptionalBlur extends StatelessWidget {
  final double blur;
  final Widget child;

  const _OptionalBlur({required this.blur, required this.child});

  @override
  Widget build(BuildContext context) {
    // 只有模糊度显着时才渲染滤镜，减少 GPU 合成开销
    if (blur < 1.0) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: child,
    );
  }
}

/// 卡拉OK文本组件 - 实现逐字填充效果
/// (保留原有逻辑)
class _KaraokeText extends StatefulWidget {
  final String text;
  final LyricLine lyric;
  final List<LyricLine> lyrics;
  final int index;
  final TextStyle originalTextStyle; // 新增：允许外部传入样式

  const _KaraokeText({
    required this.text,
    required this.lyric,
    required this.lyrics,
    required this.index,
    required this.originalTextStyle,
  });

  @override
  State<_KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<_KaraokeText> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _lineProgress = 0.0;
  
  // [Performance] 公用进度通知器，供所有 _WordFillWidget 共享
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);

  // 缓存
  double _cachedMaxWidth = 0.0;
  TextStyle? _cachedStyle;
  int _cachedLineCount = 1;
  double _line1Width = 0.0;
  double _line2Width = 0.0;
  double _line1Height = 0.0;
  double _line2Height = 0.0;
  double _line1Ratio = 0.5;

  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _calculateDuration();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _positionNotifier.dispose();
    super.dispose();
  }

  void _calculateDuration() {
    if (widget.index < widget.lyrics.length - 1) {
      _duration = widget.lyrics[widget.index + 1].startTime - widget.lyric.startTime;
    } else {
      _duration = const Duration(seconds: 5);
    }
    if (_duration.inMilliseconds == 0) _duration = const Duration(seconds: 3);
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final currentPos = PlayerService().position;
    // 更新广播通知器
    _positionNotifier.value = currentPos;

    // 处理行级进度 (针对非逐字模式)
    if (!widget.lyric.hasWordByWord || widget.lyric.words == null) {
      final elapsedFromStart = currentPos - widget.lyric.startTime;
      final newProgress = (elapsedFromStart.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

      if ((newProgress - _lineProgress).abs() > 0.005) {
        setState(() {
          _lineProgress = newProgress;
        });
      }
    }
  }
  
  // 简化版布局缓存，因为现在是单行/Wrap 为主
  void _updateLayoutCache(BoxConstraints constraints, TextStyle style) {
    if (_cachedMaxWidth == constraints.maxWidth && _cachedStyle == style) return;
    _cachedMaxWidth = constraints.maxWidth;
    _cachedStyle = style;
    
    final textSpan = TextSpan(text: widget.text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: constraints.maxWidth);
    
    final metrics = textPainter.computeLineMetrics();
    _cachedLineCount = metrics.length.clamp(1, 2);
    if (metrics.isNotEmpty) {
       _line1Width = metrics[0].width;
       _line1Height = metrics[0].height;
       if (metrics.length > 1) {
           _line2Width = metrics[1].width;
           _line2Height = metrics[1].height;
       }
    }
    
    final totalWidth = _line1Width + _line2Width;
    _line1Ratio = totalWidth > 0 ? _line1Width / totalWidth : 0.5;
    textPainter.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用传入的样式
    final style = widget.originalTextStyle;

    if (widget.lyric.hasWordByWord && widget.lyric.words != null && widget.lyric.words!.isNotEmpty) {
      return _buildWordByWordEffect(style);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _updateLayoutCache(constraints, style);
        return _buildLineGradientEffect(style);
      },
    );
  }
  
  Widget _buildWordByWordEffect(TextStyle style) {
    final words = widget.lyric.words!;
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 0.0, // 将间距归零，以抵消组件内部 Padding 增加带来的空隙
      children: List.generate(words.length, (index) {
        final word = words[index];
        return _WordFillWidget(
          key: ValueKey('${widget.index}_$index'),
          text: word.text,
          word: word,
          style: style,
          positionNotifier: _positionNotifier, // 传递共享通知器
        );
      }),
    );
  }
  
  Widget _buildLineGradientEffect(TextStyle style) {
    if (_cachedLineCount == 1) {
      return RepaintBoundary(
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: const [Colors.white, Color(0x99FFFFFF)],
              stops: [_lineProgress, _lineProgress],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(widget.text, style: style),
        ),
      );
    }
    
    // 多行逻辑：计算每行进度
    double line1Progress = 0.0; 
    double line2Progress = 0.0;
    
    if (_lineProgress <= _line1Ratio) {
      // 正在播放第一行
      if (_line1Ratio > 0) {
        line1Progress = _lineProgress / _line1Ratio;
      }
      line2Progress = 0.0;
    } else {
      // 第一行已播完，正在播放第二行
      line1Progress = 1.0;
      if (_line1Ratio < 1.0) {
        line2Progress = (_lineProgress - _line1Ratio) / (1.0 - _line1Ratio);
      }
    }
    
    final dimText = Text(
      widget.text,
      style: style.copyWith(color: const Color(0x99FFFFFF)),
    );
    
    final brightText = Text(
      widget.text,
      style: style.copyWith(color: Colors.white),
    );
    
    return RepaintBoundary(
      child: Stack(
        children: [
          dimText,
          // 第一行裁剪
          ClipRect(
            clipper: _LineClipper(
              lineIndex: 0,
              progress: line1Progress,
              lineHeight: _line1Height,
              lineWidth: _line1Width,
            ),
            child: brightText,
          ),
          // 第二行裁剪
          if (_cachedLineCount > 1)
            ClipRect(
              clipper: _LineClipper(
                lineIndex: 1,
                progress: line2Progress,
                lineHeight: _line2Height + 10,
                lineWidth: _line2Width,
                yOffset: _line1Height,
              ),
              child: brightText,
            ),
        ],
      ),
    );
  }
}

class _WordFillWidget extends StatefulWidget {
  final String text;
  final LyricWord word;
  final TextStyle style;
  final ValueNotifier<Duration> positionNotifier; // 新增

  const _WordFillWidget({
    Key? key,
    required this.text,
    required this.word,
    required this.style,
    required this.positionNotifier,
  }) : super(key: key);

  @override
  State<_WordFillWidget> createState() => _WordFillWidgetState();
}

class _WordFillWidgetState extends State<_WordFillWidget> with TickerProviderStateMixin {
  // 移除 _ticker，改用父级广播
  late AnimationController _floatController;
  late Animation<double> _floatOffset;
  double _progress = 0.0;
  bool? _isAsciiCached;

  static const double fadeRatio = 0.3;
  // 上浮的最大偏移量 (像素)
  static const double maxFloatOffset = -3.0; // 从 -5.0 缩小到 -3.0

  @override
  void initState() {
    super.initState();
    
    _floatController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 500),
    );
    _floatOffset = Tween<double>(begin: 0.0, end: maxFloatOffset).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeOutBack),
    );

    _updateProgress(widget.positionNotifier.value); 
    
    // 监听父级进度广播
    widget.positionNotifier.addListener(_onPositionUpdate);

    // 根据初始进度设置上浮状态
    const double threshold = 0.5;
    if (_progress >= threshold) {
      _floatController.value = 1.0;
    }
  }

  void _onPositionUpdate() {
     if (!mounted) return;
     final oldProgress = _progress;
     _updateProgress(widget.positionNotifier.value);

     const double threshold = 0.5;

     // 进度达到阈值时触发上浮
     if (_progress >= threshold && oldProgress < threshold) {
       _floatController.forward();
     } else if (_progress < threshold && oldProgress >= threshold) {
       _floatController.reverse();
     }

     // 性能核心：只有进度显着变化时才 setState
     // 对于非英文，保持 0.005 的阈值以节省性能
     // 对于英文，由于要计算复杂的波浪偏移，需要更高的采样频率
     final isAscii = _isAsciiText();
     final thresholdVal = isAscii ? 0.001 : 0.005;

     if ((oldProgress - _progress).abs() > thresholdVal || 
         (_progress >= 1.0 && oldProgress < 1.0) ||
         (_progress <= 0.0 && oldProgress > 0.0)) {
       setState(() {});
     }
  }

  @override
  void didUpdateWidget(_WordFillWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionNotifier != widget.positionNotifier) {
      oldWidget.positionNotifier.removeListener(_onPositionUpdate);
      widget.positionNotifier.addListener(_onPositionUpdate);
    }
    _updateProgress(widget.positionNotifier.value);
    
    const double threshold = 0.5;

    // 处理上浮动画状态（支持 Seek）
    if (_progress >= threshold) {
      if (!_floatController.isAnimating && _floatController.value < 1.0) {
        _floatController.forward();
      }
    } else {
      if (!_floatController.isAnimating && _floatController.value > 0.0) {
        _floatController.reverse();
      }
    }
  }

  void _updateProgress(Duration currentPos) {
    if (currentPos < widget.word.startTime) {
      _progress = 0.0;
    } else if (currentPos >= widget.word.endTime) {
      _progress = 1.0;
    } else {
      final wordDuration = widget.word.duration.inMilliseconds;
      if (wordDuration <= 0) {
         _progress = 1.0;
      } else {
         final wordElapsed = currentPos - widget.word.startTime;
         _progress = (wordElapsed.inMilliseconds / wordDuration).clamp(0.0, 1.0);
      }
    }
  }

  @override
  void dispose() {
    widget.positionNotifier.removeListener(_onPositionUpdate);
    _floatController.dispose();
    super.dispose();
  }

  bool _isAsciiText() {
    if (_isAsciiCached != null) return _isAsciiCached!;
    if (widget.text.isEmpty) {
      _isAsciiCached = false;
      return false;
    }
    int asciiCount = 0;
    for (final char in widget.text.runes) {
      if ((char >= 65 && char <= 90) || (char >= 97 && char <= 122)) asciiCount++;
    }
    _isAsciiCached = asciiCount > widget.text.length / 2;
    return _isAsciiCached!;
  }


  @override
  Widget build(BuildContext context) {
    final useLetterAnimation = _isAsciiText() && widget.text.length > 1;
    
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _floatOffset,
        builder: (context, child) {
          // 如果开启了逐字母动画，父级的位移仅作为整体辅助，或者根据需要禁用
          // 这里我们让英文状态下父级 Transform 失效，完全由子项控制
          final double effectiveY = useLetterAnimation ? 0.0 : _floatOffset.value;
          
          return Transform.translate(
            offset: Offset(0, effectiveY),
            child: child,
          );
        },
        child: _buildInner(),
      ),
    );
  }

  Widget _buildInner() {
    if (_isAsciiText() && widget.text.length > 1) return _buildLetterByLetterEffect();
    return _buildWholeWordEffect();
  }
  
  Widget _buildWholeWordEffect() {
    // 统一使用 4-stops 结构的 LinearGradient，避免 GPU 重新编译着色器导致闪烁
    List<Color> gradientColors;
    List<double> gradientStops;
    
    if (_progress <= 0.0) {
      gradientColors = const [Color(0x99FFFFFF), Color(0x99FFFFFF)];
      gradientStops = const [0.0, 1.0];
    } else if (_progress >= 1.0) {
      gradientColors = const [Colors.white, Colors.white];
      gradientStops = const [0.0, 1.0];
    } else {
      // 核心：在进度锋面插入一个更亮的点来模拟“发光扫描线”
      const double glowWidth = 0.05; // 光条宽度
      gradientColors = [
        Colors.white.withOpacity(0.9), // 已播部分
        Colors.white,                  // 光条起点
        Colors.white,                  // 光条最亮部 (进度所在位置)
        const Color(0x99FFFFFF),       // 渐变过渡
        const Color(0x99FFFFFF),       // 未播部分
      ];
      gradientStops = [
        0.0,
        (_progress - glowWidth).clamp(0.0, 1.0),
        _progress,
        (_progress + fadeRatio).clamp(0.0, 1.0),
        1.0,
      ];
    }

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: gradientColors,
        stops: gradientStops,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      // Padding 扩展边界：底部增加到 10px 以容纳 g, y, q 等下沉字符防止 ShaderMask 裁切产生白边
      child: Padding(
        padding: const EdgeInsets.only(top: 2.0, bottom: 10.0),
        child: Text(widget.text, style: widget.style.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildLetterByLetterEffect() {
    final letters = widget.text.split('');
    final letterCount = letters.length;
    
    // 波浪参数
    const double rippleWidth = 1.2; // 波浪影响的范围因子 (相对于单个字母宽度)
    const double maxLetterFloat = -4.0; // 字母上浮最大高度 (从 -6.0 缩小到 -4.0)

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: List.generate(letterCount, (index) {
        final letter = letters[index];
        final baseWidth = 1.0 / letterCount;
        
        // --- 1. 计算填充进度 (ShaderMask) ---
        final fillStart = index * baseWidth;
        final fillEnd = (index + 1) * baseWidth;
        final fillProgress = ((_progress - fillStart) / (fillEnd - fillStart)).clamp(0.0, 1.0);

        // --- 2. 计算上浮偏移 (Ripple Animation) ---
        final letterCenter = (index + 0.5) * baseWidth;
        double currentLetterOffset = 0.0;
        
        if (_progress <= 0.0) {
          // 初始状态强制为 0，防止第一位字符抖动
          currentLetterOffset = 0.0;
        } else if (_progress >= fillEnd) {
          currentLetterOffset = maxLetterFloat;
        } else {
          // 只有当进度接近该字母时才开始带动
          // 稍微延迟带动时机，防止第一个字母在播放前由于 rippleWidth 太大而浮起
          final startTrigger = (fillStart - (baseWidth * rippleWidth)).clamp(0.001, 1.0);
          if (_progress > startTrigger) {
            final t = ((_progress - startTrigger) / (fillEnd - startTrigger)).clamp(0.0, 1.0);
            currentLetterOffset = Curves.easeOut.transform(t) * maxLetterFloat;
          }
        }

        // --- 3. 构建 ShaderMask ---
        // 填充前端发光渐变
        List<Color> lColors;
        List<double> lStops;
        
        if (fillProgress <= 0.0) {
          lColors = const [Color(0x99FFFFFF), Color(0x99FFFFFF)];
          lStops = const [0.0, 1.0];
        } else if (fillProgress >= 1.0) {
          lColors = const [Colors.white, Colors.white];
          lStops = const [0.0, 1.0];
        } else {
          const double glowW = 0.15; // 字母内发光稍微宽一点
          lColors = [
            Colors.white.withOpacity(0.9),
            Colors.white,
            Colors.white,
            const Color(0x99FFFFFF),
            const Color(0x99FFFFFF),
          ];
          lStops = [
            0.0,
            (fillProgress - glowW).clamp(0.0, 1.0),
            fillProgress,
            (fillProgress + fadeRatio).clamp(0.0, 1.0),
            1.0,
          ];
        }

        return Transform.translate(
          offset: Offset(0, currentLetterOffset),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: lColors,
              stops: lStops,
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            // Padding 扩展边界：底部增加到 10px 以容纳 g, y, q 等下沉字符防止 ShaderMask 裁切产生白边
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0, bottom: 10.0),
              child: Text(letter, style: widget.style.copyWith(color: Colors.white)),
            ),
          ),
        );
      }),
    );
  }
}

/// 裁剪器 (保留但可能未被直接使用，防止报错)
class _LineClipper extends CustomClipper<Rect> {
  final int lineIndex;
  final double progress;
  final double lineHeight;
  final double lineWidth;
  final double yOffset;
  _LineClipper({required this.lineIndex, required this.progress, required this.lineHeight, required this.lineWidth, this.yOffset = 0.0});
  @override Rect getClip(Size size) => Rect.fromLTWH(0, yOffset, lineWidth * progress, lineHeight);
  @override bool shouldReclip(_LineClipper oldClipper) => oldClipper.progress != progress;
}

/// 倒计时点组件 - Apple Music 风格 (保留)
class _CountdownDots extends StatefulWidget {
  final List<LyricLine> lyrics;
  final double countdownThreshold;
  const _CountdownDots({required this.lyrics, required this.countdownThreshold});
  @override State<_CountdownDots> createState() => _CountdownDotsState();
}

class _CountdownDotsState extends State<_CountdownDots> with TickerProviderStateMixin {
  late Ticker _ticker;
  double _progress = 0.0;
  bool _isVisible = false;
  bool _wasVisible = false;
  late AnimationController _appearController;
  late Animation<double> _appearAnimation;
  
  static const int _dotCount = 3;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _appearAnimation = CurvedAnimation(parent: _appearController, curve: Curves.easeOutBack, reverseCurve: Curves.easeInBack);
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _appearController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (widget.lyrics.isEmpty) return;
    final firstLyricTime = widget.lyrics.first.startTime;
    final currentPos = PlayerService().position;
    final timeUntilFirstLyric = (firstLyricTime - currentPos).inMilliseconds / 1000.0;
    final isPlaying = PlayerService().isPlaying;
    final shouldShow = isPlaying && currentPos.inMilliseconds > 0 && timeUntilFirstLyric > 0 && timeUntilFirstLyric <= widget.countdownThreshold;

    if (shouldShow) {
      final newProgress = 1.0 - (timeUntilFirstLyric / widget.countdownThreshold);
      if (!_wasVisible) {
        _wasVisible = true;
        _appearController.forward();
      }
      if (!_isVisible || (newProgress - _progress).abs() > 0.01) {
        setState(() {
          _isVisible = true;
          _progress = newProgress.clamp(0.0, 1.0);
        });
      }
    } else if (_isVisible || _wasVisible) {
      if (_wasVisible) {
        _wasVisible = false;
        _appearController.reverse();
      }
      setState(() {
        _isVisible = false;
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appearAnimation,
      builder: (context, child) {
        if (_appearAnimation.value <= 0.01 && !_isVisible) return const SizedBox.shrink();
        
        return RepaintBoundary(
          child: SizedBox(
            height: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_dotCount, (index) {
                final dotStartProgress = index / _dotCount;
                final dotEndProgress = (index + 1) / _dotCount;
                double dotProgress = 0.0;
                if (_progress > dotStartProgress) {
                   dotProgress = (_progress - dotStartProgress) / (dotEndProgress - dotStartProgress);
                   if (_progress >= dotEndProgress) dotProgress = 1.0;
                }
                
                final staggerDelay = index * 0.15;
                double appearScale = 0.0;
                if (_appearAnimation.value >= staggerDelay) {
                  appearScale = ((_appearAnimation.value - staggerDelay) / (1.0 - staggerDelay)).clamp(0.0, 1.0);
                }
                
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Transform.scale(
                    scale: _easeOutBack(appearScale),
                    child: _CountdownDot(
                      size: 12.0,
                      fillProgress: dotProgress,
                      appearProgress: appearScale,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
  double _easeOutBack(double t) {
    if (t <= 0) return 0; if (t >= 1) return 1;
    const c1 = 1.70158; const c3 = c1 + 1;
    return 1 + c3 * (t - 1) * (t - 1) * (t - 1) + c1 * (t - 1) * (t - 1);
  }
}

class _CountdownDot extends StatelessWidget {
  final double size;
  final double fillProgress;
  final double appearProgress;
  const _CountdownDot({required this.size, required this.fillProgress, required this.appearProgress});
  
  @override
  Widget build(BuildContext context) {
    final innerSize = (size - 4) * (1 - (1 - fillProgress) * (1 - fillProgress) * (1 - fillProgress) * (1 - fillProgress));
    final borderOpacity = 0.4 + (0.2 * appearProgress);
    final glowIntensity = fillProgress > 0.3 ? (fillProgress - 0.3) / 0.7 : 0.0;
    
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(borderOpacity), width: 1.5),
      ),
      child: Center(
        child: Container(
          width: innerSize, height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.9),
            boxShadow: glowIntensity > 0 ? [BoxShadow(color: Colors.white.withOpacity(0.4 * glowIntensity), blurRadius: 8 * glowIntensity)] : null,
          ),
        ),
      ),
    );
  }
}