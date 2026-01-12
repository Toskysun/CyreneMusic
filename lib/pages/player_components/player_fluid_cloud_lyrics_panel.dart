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
enum _VirtualEntryType { lyric, dots }

class _VirtualLyricEntry {
  final _VirtualEntryType type;
  final int? lyricIndex; 
  final Duration startTime;
  final String key;

  _VirtualLyricEntry({
    required this.type,
    this.lyricIndex,
    required this.startTime,
    required this.key,
  });
}

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
  
  // 核心变量 (从 Service 获取)
  double get _lineHeight => LyricStyleService().lineHeight;
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

  late Ticker _ticker;
  
  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
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
            final currentPos = PlayerService().position;

            // 1. 构建虚拟项列表 (动态触发)
            final List<_VirtualLyricEntry> virtualEntries = [];
            
            // 检查前奏 dots：只有在距离第一句歌词开始 <= 5s 时才真正“加载”进入队列
            if (widget.lyrics.isNotEmpty) {
              final firstTime = widget.lyrics[0].startTime;
              final timeToFirst = (firstTime - currentPos).inSeconds;
              // 如果距离首句还早（>5s），则不加载 dots 项。
              // 如果进入了 5s 倒计时，或者已经超过首句（用于支持 passed dots 的停留），则加载。
              if (timeToFirst <= 5) {
                 virtualEntries.add(_VirtualLyricEntry(
                   type: _VirtualEntryType.dots,
                   startTime: Duration.zero,
                   key: 'dots-intro',
                 ));
              }
            }

            for (int i = 0; i < widget.lyrics.length; i++) {
              virtualEntries.add(_VirtualLyricEntry(
                type: _VirtualEntryType.lyric,
                lyricIndex: i,
                startTime: widget.lyrics[i].startTime,
                key: 'lyric-$i-${widget.lyrics[i].startTime.inMilliseconds}',
              ));

              // 检查间奏 dots：同样是动态触发
              if (i < widget.lyrics.length - 1) {
                final currentLine = widget.lyrics[i];
                final nextLine = widget.lyrics[i+1];
                final gap = (nextLine.startTime - currentLine.startTime).inSeconds;
                
                // 计算当前行结束时间
                Duration lineEndTime = currentLine.startTime + const Duration(seconds: 3); // 默认兜底 3s
                if (currentLine.words != null && currentLine.words!.isNotEmpty) {
                  lineEndTime = currentLine.words!.last.startTime + currentLine.words!.last.duration;
                } else if (currentLine.lineDuration != null) {
                   lineEndTime = currentLine.startTime + currentLine.lineDuration!;
                }

                // 只有当播放进度已经到达或超过当前句子的“结束点”，且间奏够长，才插入 dots 项
                if (gap >= 10 && currentPos >= lineEndTime) {
                  virtualEntries.add(_VirtualLyricEntry(
                    type: _VirtualEntryType.dots,
                    startTime: lineEndTime,
                    key: 'dots-interlude-$i',
                  ));
                }
              }
            }

            // 2. 找到当前活跃虚拟项索引
            int activeVirtualIndex = 0;
            for (int i = virtualEntries.length - 1; i >= 0; i--) {
              if (currentPos >= virtualEntries[i].startTime) {
                activeVirtualIndex = i;
                break;
              }
            }

            // 根据对齐设置动态计算中心点偏移
            final centerY = lyricStyle.currentAlignment == LyricAlignment.center 
                ? viewportHeight * 0.5 
                : viewportHeight * 0.25;
            
            // 可视区域计算
            final visibleBuffer = 8; 
            final minIdx = max(0, activeVirtualIndex - visibleBuffer);
            final maxIdx = min(virtualEntries.length - 1, activeVirtualIndex + visibleBuffer + 4);

            final layoutWidth = viewportWidth / _maxActiveScale;
            final textMaxWidth = layoutWidth - 80;

            // 3. 计算高度和偏移
            final Map<int, double> heights = {};
            for (int i = minIdx; i <= maxIdx; i++) {
              heights[i] = _measureVirtualEntryHeight(virtualEntries[i], textMaxWidth);
            }

            final Map<int, double> offsets = {};
            offsets[activeVirtualIndex] = 0;

            double currentOffset = 0;
            double prevHalfHeight = (heights[activeVirtualIndex]! * (virtualEntries[activeVirtualIndex].type == _VirtualEntryType.dots ? 1.0 : 1.15)) / 2;
            
            for (int i = activeVirtualIndex + 1; i <= maxIdx; i++) {
              final h = heights[i]!;
              final s = _getScaleSync(i - activeVirtualIndex);
              final scaledHalfHeight = (h * s) / 2;
              currentOffset += prevHalfHeight + scaledHalfHeight; 
              offsets[i] = currentOffset;
              prevHalfHeight = scaledHalfHeight;
            }

            currentOffset = 0;
            double nextHalfHeight = (heights[activeVirtualIndex]! * (virtualEntries[activeVirtualIndex].type == _VirtualEntryType.dots ? 1.0 : 1.15)) / 2;
            
            for (int i = activeVirtualIndex - 1; i >= minIdx; i--) {
              final h = heights[i]!;
              final s = _getScaleSync(i - activeVirtualIndex);
              final scaledHalfHeight = (h * s) / 2;
              currentOffset -= (nextHalfHeight + scaledHalfHeight);
              offsets[i] = currentOffset;
              nextHalfHeight = scaledHalfHeight;
            }

            List<Widget> children = [];
            for (int i = minIdx; i <= maxIdx; i++) {
               children.add(_buildVirtualItem(
                 virtualEntries[i], 
                 i, 
                 activeVirtualIndex, 
                 centerY, 
                 offsets[i] ?? 0.0, 
                 heights[i]!, 
                 layoutWidth
               ));
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

  double _measureVirtualEntryHeight(_VirtualLyricEntry entry, double maxWidth) {
    if (entry.type == _VirtualEntryType.dots) return 40.0;
    return _measureLyricItemHeight(entry.lyricIndex!, maxWidth);
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

    final fontSize = LyricStyleService().fontSize; 

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

  Widget _buildVirtualItem(_VirtualLyricEntry item, int index, int activeIndex, double centerYOffset, double relativeOffset, double itemHeight, double layoutWidth) {
    final diff = index - activeIndex;
    final currentPos = PlayerService().position;

    // 1. 缩放逻辑
    double targetScale = _getScaleSync(diff);
    if (item.type == _VirtualEntryType.dots) targetScale = 1.0;

    // 2. 最终Y坐标
    double baseTranslation = relativeOffset;
    double sineOffset = sin(diff * 0.8) * 20.0;
    
    // 【核心亮点】占位点原地消失逻辑
    // 如果是占位点，并且已经过期 (diff < 0)
    if (item.type == _VirtualEntryType.dots && diff < 0) {
       // 固定在中心位置附近停留消失，不跟随向上滚动
       baseTranslation = 0; 
       sineOffset = 0;
    }

    double targetY = centerYOffset + baseTranslation + sineOffset - (itemHeight * targetScale / 2);
    if (_isDragging) targetY += _dragOffset;
    
    // 3. 透明度逻辑
    double targetOpacity;
    if (diff.abs() > 4) {
      targetOpacity = 0.0;
    } else {
      targetOpacity = 1.0 - diff.abs() * 0.2;
    }

    // 过期占位符强制 0 透明度 (因为它们不再占用空间)
    if (item.type == _VirtualEntryType.dots && diff < 0) targetOpacity = 0.0;
    
    // 前奏占位符：只有在距离第一句 > 0 且 <= 5s 时才显示初现
    if (item.key == 'dots-intro') {
      final firstTime = widget.lyrics[0].startTime;
      final timeUntilFirst = (firstTime - currentPos).inMilliseconds / 1000.0;
      if (timeUntilFirst <= 0 || timeUntilFirst > 5.0) targetOpacity = 0.0;
    }

    targetOpacity = targetOpacity.clamp(0.0, 1.0).toDouble();

    final int delayMs = (diff.abs() * 50).toInt();

    final blurSigma = LyricStyleService().blurSigma;
    double targetBlur = blurSigma;
    if (diff == 0) targetBlur = 0.0;
    else if (diff.abs() == 1) targetBlur = blurSigma * 0.25;
    if (item.type == _VirtualEntryType.dots && diff < 0) targetBlur = blurSigma;

    final bool isActive = (diff == 0);

    return _ElasticLyricLine(
      key: ValueKey(item.key),
      text: item.type == _VirtualEntryType.lyric ? widget.lyrics[item.lyricIndex!].text : '',
      translation: item.type == _VirtualEntryType.lyric ? widget.lyrics[item.lyricIndex!].translation : null,
      lyric: item.type == _VirtualEntryType.lyric ? widget.lyrics[item.lyricIndex!] : LyricLine(startTime: item.startTime, text: ''),
      lyrics: widget.lyrics,     
      index: index,             
      lineHeight: _lineHeight,
      viewportWidth: layoutWidth,
      targetY: targetY,
      targetScale: targetScale,
      targetOpacity: targetOpacity,
      targetBlur: targetBlur,
      isActive: isActive,
      delay: Duration(milliseconds: delayMs),
      isDragging: _isDragging,
      showTranslation: widget.showTranslation,
      isDots: item.type == _VirtualEntryType.dots,
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
  final bool isDots;

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
    this.isDots = false,
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

  // --- 涟漪效果相关 ---
  final List<_RippleInfo> _ripples = [];
  
  void _addRipple(Offset localPosition) {
    // 占位点不需要涟漪效果
    if (widget.isDots) return;
    
    final ripple = _RippleInfo(
      position: localPosition,
      controller: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      ),
    );
    
    setState(() {
      _ripples.add(ripple);
    });

    ripple.controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _ripples.remove(ripple);
        });
      }
      ripple.controller.dispose();
    });
  }

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
    // 清理所有涟漪动画控制器
    for (final ripple in _ripples) {
      ripple.controller.dispose();
    }
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
      child: RepaintBoundary(
        child: GestureDetector(
          // 使用 opaque 拦截点击事件，防止冒泡到外部 Layout 触发控制栏显隐
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _addRipple(details.localPosition);
          },
          onTap: () {
            // 占位点不需要跳转
            if (widget.isDots) return;
            // 跳转到歌词开始时间
            PlayerService().seek(widget.lyric.startTime);
          },
          child: Transform.scale(
            scale: _scale,
            alignment: Alignment.centerLeft, // HTML: transform-origin: left center
            child: Opacity(
              opacity: _opacity,
              child: _OptionalBlur(
                blur: _blur,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12), // 卡片外边距
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // 仿 Apple Music 圆角
                    child: AnimatedBuilder(
                      animation: Listenable.merge(_ripples.map((r) => r.controller).toList()),
                      builder: (context, child) {
                        // 根据涟漪进度计算背景透明度
                        double bgOpacity = 0.0;
                        if (_ripples.isNotEmpty) {
                          final maxProgress = _ripples.map((r) => r.controller.value).reduce((a, b) => a > b ? a : b);
                          bgOpacity = 0.12 * (1.0 - maxProgress);
                        }

                        return Container(
                          // 关键约束：限制渲染宽度与测量宽度一致
                          constraints: BoxConstraints(maxWidth: widget.viewportWidth),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10), // 卡片内边距
                          color: Colors.white.withOpacity(bgOpacity),
                          alignment: Alignment.centerLeft, // HTML: display: flex; align-items: center
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              _buildInnerContent(),
                              // 涟漪层 (已在 ClipRRect 内部)
                              ..._ripples.map((ripple) => _buildRipple(ripple)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRipple(_RippleInfo ripple) {
    return AnimatedBuilder(
      animation: ripple.controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(
            progress: ripple.controller.value,
            center: ripple.position,
          ),
        );
      },
    );
  }
  Widget _buildInnerContent() {
    if (widget.isDots) {
      return const _CountdownDots();
    }
    final fontFamily = LyricFontService().currentFontFamily ?? 'Microsoft YaHei';
    final double textFontSize = LyricStyleService().fontSize;

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
              fontSize: textFontSize * 0.56, // 译文约原文 56% 大小
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.3),
                height: 1.4, // 增加行高防止译文本身换行时拥挤
              ),
            ),
          )
        ],
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
  static const double maxFloatOffset = -1.5; // 从 -3.0 缩小 50% 到 -1.5

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

/// 倒计时点组件 - Apple Music 风格 (三点呼吸动画)
class _CountdownDots extends StatefulWidget {
  const _CountdownDots();
  @override State<_CountdownDots> createState() => _CountdownDotsState();
}

class _CountdownDotsState extends State<_CountdownDots> with TickerProviderStateMixin {
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return _BreathDot(
            index: index,
            controller: _breatheController,
          );
        }),
      ),
    );
  }
}

class _BreathDot extends StatelessWidget {
  final int index;
  final AnimationController controller;

  const _BreathDot({required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // 计算每个点的延迟进度 (0.0 到 1.0)
        double progress = (controller.value - (index * 0.2)) % 1.0;
        if (progress < 0) progress += 1.0;

        // 呼吸曲线：0 -> 1 -> 0
        final double value = sin(progress * pi);
        
        // 样式：Scale 0.8 -> 1.2, Opacity 0.4 -> 1.0
        final double scale = 0.8 + (0.4 * value);
        final double opacity = 0.4 + (0.6 * value);

        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 涟漪信息类
class _RippleInfo {
  final Offset position;
  final AnimationController controller;
  _RippleInfo({required this.position, required this.controller});
}

/// 涟漪绘制器 - 仿 Apple Music 风格
class _RipplePainter extends CustomPainter {
  final double progress;
  final Offset center;

  _RipplePainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    // 极快扩张，平滑淡出
    final double radius = 300.0 * Curves.easeOutCubic.transform(progress);
    final double opacity = (1.0 - Curves.easeOut.transform(progress)) * 0.25;

    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => oldDelegate.progress != progress;
}
