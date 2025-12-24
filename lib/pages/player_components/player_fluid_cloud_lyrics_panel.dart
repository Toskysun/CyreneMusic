import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../services/player_service.dart';
import '../../services/lyric_font_service.dart';
import '../../models/lyric_line.dart';


/// 核心：弹性间距动画 + 波浪式延迟
class PlayerFluidCloudLyricsPanel extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;

  const PlayerFluidCloudLyricsPanel({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.showTranslation,
  });

  @override
  State<PlayerFluidCloudLyricsPanel> createState() => _PlayerFluidCloudLyricsPanelState();
}

class _PlayerFluidCloudLyricsPanelState extends State<PlayerFluidCloudLyricsPanel> 
    with TickerProviderStateMixin {
  
  // ===== 滚动控制 =====
  final ScrollController _scrollController = ScrollController();
  int? _selectedLyricIndex;
  bool _isUserScrolling = false;
  Timer? _scrollResetTimer;
  
  // ===== 动画控制 =====
  late AnimationController _timeCapsuleController;
  late Animation<double> _timeCapsuleFade;
  
  // ===== 弹性间距动画 =====
  late AnimationController _spacingController;
  int _previousIndex = -1;
  
  // ===== 布局缓存 =====
  double _itemHeight = 100.0;
  double _viewportHeight = 0.0;
  bool _hasInitialScrolled = false; // 是否已完成首次滚动
  
  // ===== 倒计时点动画 =====
  static const double _countdownThreshold = 5.0; // 倒计时开始阈值（秒）

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _previousIndex = widget.currentLyricIndex;
    // 监听字体变化，实时刷新
    LyricFontService().addListener(_onFontChanged);
  }

  @override
  void dispose() {
    LyricFontService().removeListener(_onFontChanged);
    _scrollResetTimer?.cancel();
    _timeCapsuleController.dispose();
    _spacingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 字体变化回调
  void _onFontChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initAnimations() {
    _timeCapsuleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _timeCapsuleFade = CurvedAnimation(
      parent: _timeCapsuleController,
      curve: Curves.easeInOut,
    );
    
    // 弹性间距动画控制器
    _spacingController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(PlayerFluidCloudLyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 歌词索引变化且非手动滚动模式时
    if (widget.currentLyricIndex != oldWidget.currentLyricIndex && !_isUserScrolling) {
      _previousIndex = oldWidget.currentLyricIndex;
      // 触发弹性动画
      _spacingController.forward(from: 0.0);
      _scrollToIndex(widget.currentLyricIndex);
    }
  }

  /// 滚动到指定索引（带动画）
  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || _viewportHeight <= 0) return;
    
    // 如果有译文，增加行高30%
    final hasTranslation = _hasTranslation();
    final effectiveItemHeight = hasTranslation ? _itemHeight * 1.3 : _itemHeight;
    final targetOffset = index * effectiveItemHeight;
    
    // 使用弹性曲线滚动
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 700),
      curve: const _ElasticOutCurve(),
    );
  }
  
  /// 立即滚动到指定索引（无动画，用于首次进入）
  void _scrollToIndexImmediate(int index) {
    if (!_scrollController.hasClients || _viewportHeight <= 0) return;
    
    // 如果有译文，增加行高30%
    final hasTranslation = _hasTranslation();
    final effectiveItemHeight = hasTranslation ? _itemHeight * 1.3 : _itemHeight;
    final targetOffset = index * effectiveItemHeight;
    _scrollController.jumpTo(targetOffset);
  }

  /// 激活手动滚动模式
  void _activateManualScroll() {
    if (!_isUserScrolling) {
      setState(() {
        _isUserScrolling = true;
      });
      _timeCapsuleController.forward();
    }
    _resetScrollTimer();
  }

  /// 重置滚动定时器
  void _resetScrollTimer() {
    _scrollResetTimer?.cancel();
    _scrollResetTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _isUserScrolling = false;
          _selectedLyricIndex = null;
        });
        _timeCapsuleController.reverse();
        // 回到当前播放位置
        _scrollToIndex(widget.currentLyricIndex);
      }
    });
  }

  /// 跳转到选中的歌词
  void _seekToSelectedLyric() {
    if (_selectedLyricIndex != null && 
        _selectedLyricIndex! >= 0 && 
        _selectedLyricIndex! < widget.lyrics.length) {
      final lyric = widget.lyrics[_selectedLyricIndex!];
      PlayerService().seek(lyric.startTime);
    }
    
    setState(() {
      _isUserScrolling = false;
      _selectedLyricIndex = null;
    });
    _timeCapsuleController.reverse();
    _scrollResetTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return _buildNoLyric();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        // 可视区域显示约 7 行歌词
        _itemHeight = _viewportHeight / 7;
        
        // 首次布局完成后，立即滚动到当前歌词位置
        if (!_hasInitialScrolled && _viewportHeight > 0) {
          _hasInitialScrolled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollToIndexImmediate(widget.currentLyricIndex);
            }
          });
        }

        return Stack(
          children: [
            // 歌词列表（内含倒计时点动画）
            _buildLyricList(),
            
            // 时间胶囊 (手动滚动时显示)
            if (_isUserScrolling && _selectedLyricIndex != null)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(child: _buildTimeCapsule()),
              ),
          ],
        );
      },
    );
  }

  /// 构建无歌词提示
  Widget _buildNoLyric() {
    final fontFamily = LyricFontService().currentFontFamily ?? 'Microsoft YaHei';
    return Center(
      child: Text(
        '纯音乐 / 暂无歌词',
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 42,
          fontWeight: FontWeight.w800,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  /// 检查歌词是否包含译文
  bool _hasTranslation() {
    if (!widget.showTranslation) return false;
    return widget.lyrics.any((lyric) => 
        lyric.translation != null && lyric.translation!.isNotEmpty);
  }

  /// 构建歌词列表
  Widget _buildLyricList() {
    // 如果有译文，增加行高30%
    final hasTranslation = _hasTranslation();
    final effectiveItemHeight = hasTranslation ? _itemHeight * 1.3 : _itemHeight;
    final topPadding = (_viewportHeight - effectiveItemHeight) / 2;
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification && 
            notification.dragDetails != null) {
          // 用户开始拖动
          _activateManualScroll();
        } else if (notification is ScrollUpdateNotification && _isUserScrolling) {
          // 更新选中的歌词索引
          final centerOffset = _scrollController.offset + (_viewportHeight / 2);
          final index = (centerOffset / effectiveItemHeight).floor();
          if (index >= 0 && index < widget.lyrics.length && index != _selectedLyricIndex) {
            setState(() {
              _selectedLyricIndex = index;
            });
          }
          _resetScrollTimer();
        }
        return false;
      },
      child: AnimatedBuilder(
        animation: _spacingController,
        builder: (context, child) {
          return ListView.builder(
            controller: _scrollController,
            itemCount: widget.lyrics.length,
            itemExtent: effectiveItemHeight,
            padding: EdgeInsets.symmetric(vertical: topPadding),
            physics: const BouncingScrollPhysics(),
            cacheExtent: _viewportHeight,
            itemBuilder: (context, index) {
              return _buildLyricLine(index, effectiveItemHeight);
            },
          );
        },
      ),
    );
  }

  /// 获取弹性偏移量 
  double _getElasticOffset(int index) {
    if (_isUserScrolling) return 0.0;
    
    final currentIndex = widget.currentLyricIndex;
    final diff = index - currentIndex;
    
    // 只对当前行附近的几行应用弹性效果
    if (diff.abs() > 5) return 0.0;
    
    // 计算延迟：距离越远延迟越大
    // 模拟波浪效果
    final delay = (diff.abs() * 0.08).clamp(0.0, 0.4);
    
    // 调整动画进度，考虑延迟
    final adjustedProgress = ((_spacingController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    
    // 弹性曲线：先过冲再回弹
    final elasticValue = const _ElasticOutCurve().transform(adjustedProgress);
    
    // 间距变化量：模拟滚动时的间距拉伸
    // 初始时刻(progress=0)间距最大，然后弹回正常
    final spacingChange = 24.0 * (1.0 - elasticValue);
    
    // diff > 0 (下方): 向下偏移 (+)
    // diff < 0 (上方): 向上偏移 (-)
    // 这样中间就被拉开了
    return spacingChange * diff;
  }

  /// 构建单行歌词 - Apple Music 风格
  Widget _buildLyricLine(int index, double effectiveItemHeight) {
    final lyric = widget.lyrics[index];
    final isActive = index == widget.currentLyricIndex;
    final isSelected = _isUserScrolling && _selectedLyricIndex == index;
    final distance = (index - widget.currentLyricIndex).abs();
    
    // ===== 视觉参数计算 
    // 透明度：当前行 1.0，距离越远越透明
    final opacity = isActive ? 1.0 : (1.0 - distance * 0.15).clamp(0.3, 0.8);
    
    // 模糊度：当前行清晰，距离越远越模糊 
    final blur = isActive ? 0.0 : (distance * 1.0).clamp(0.0, 2.0);
    
    // ===== 弹性偏移 =====
    final elasticOffset = _getElasticOffset(index);
    
    // 译文的弹性偏移 (仅对当前行生效，使其与原文之间也有弹性效果)
    // 延迟稍大一点，产生波浪感
    double translationOffset = 0.0;
    if (isActive && !_isUserScrolling) {
      final progress = _spacingController.value;
      // 弹性曲线
      final elasticValue = const _ElasticOutCurve().transform(progress);
      // 间距变化量：初始间距较大，然后弹回
      translationOffset = 4.0 * (1.0 - elasticValue);
    }
    
    final bottomPadding = isActive ? 16.0 : 8.0;

    // 构建歌词内容
    Widget lyricContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 原文歌词
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: isSelected 
                ? Colors.orange 
                : (isActive ? Colors.white : Colors.white.withOpacity(0.45)),
            fontSize: isActive ? 32 : 26,
            fontWeight: FontWeight.w900,
            fontFamily: LyricFontService().currentFontFamily ?? 'Microsoft YaHei',
            height: 1.25,
            letterSpacing: -0.5,
          ),
          child: Builder(
            builder: (context) {
              final textWidget = Text(
                lyric.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
              
              // 只有当前行且非手动滚动时才启用卡拉OK效果
              if (isActive && !_isUserScrolling) {
                return _KaraokeText(
                  text: lyric.text,
                  lyric: lyric,
                  lyrics: widget.lyrics,
                  index: index,
                );
              }
              
              return textWidget;
            },
          ),
        ),
        
        // 翻译歌词
        if (widget.showTranslation && 
            lyric.translation != null && 
            lyric.translation!.isNotEmpty)
          Transform.translate(
            offset: Offset(0, translationOffset),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: isActive 
                      ? Colors.white.withOpacity(0.9) 
                      : Colors.white.withOpacity(0.6),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: LyricFontService().currentFontFamily ?? 'Microsoft YaHei',
                  height: 1.3,
                ),
                child: Text(
                  lyric.translation!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );

    // 如果是第一行，在歌词上方添加倒计时点
    if (index == 0 && !_isUserScrolling) {
      lyricContent = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 倒计时点（在歌词上方）
          _CountdownDots(
            lyrics: widget.lyrics,
            countdownThreshold: _countdownThreshold,
          ),
          const SizedBox(height: 8), // 点与歌词之间的间距
          // 歌词内容
          lyricContent,
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        // 点击歌词跳转
        PlayerService().seek(lyric.startTime);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Transform.translate(
          // 弹性 Y 轴偏移
          offset: Offset(0, elasticOffset),
          child: SizedBox(
            height: effectiveItemHeight,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxHeight: effectiveItemHeight * 1.5, // 允许内容超出50%高度
              child: Padding(
                padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomPadding),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: opacity,
                  // 性能优化：仅在需要模糊时应用 ImageFiltered
                  child: _OptionalBlur(
                    blur: blur,
                    child: lyricContent,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建时间胶囊
  Widget _buildTimeCapsule() {
    if (_selectedLyricIndex == null || 
        _selectedLyricIndex! < 0 || 
        _selectedLyricIndex! >= widget.lyrics.length) {
      return const SizedBox.shrink();
    }

    final lyric = widget.lyrics[_selectedLyricIndex!];
    final timeText = _formatDuration(lyric.startTime);

    return FadeTransition(
      opacity: _timeCapsuleFade,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _seekToSelectedLyric,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Consolas',
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '点击跳转',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 弹性曲线
/// 这是一个过冲曲线，值会超过 1.0 然后回弹
class _ElasticOutCurve extends Curve {
  const _ElasticOutCurve();

  @override
  double transformInternal(double t) {
    // 使用简化的弹性公式
    final t2 = t - 1.0;
    // 过冲系数 1.56 产生弹性效果
    return 1.0 + t2 * t2 * ((1.56 + 1) * t2 + 1.56);
  }
}

/// 性能优化：条件应用模糊滤镜
/// blur=0 时直接返回子组件，避免不必要的滤镜开销
class _OptionalBlur extends StatelessWidget {
  final double blur;
  final Widget child;

  const _OptionalBlur({
    required this.blur,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 当 blur 接近 0 时，跳过滤镜操作
    if (blur < 0.1) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: child,
    );
  }
}

/// 卡拉OK文本组件 - 实现逐字填充效果
/// 支持两种模式：
/// 1. 有逐字歌词数据时：每个字单独渲染并高亮
/// 2. 无逐字歌词数据时：回退到整行渐变填充
class _KaraokeText extends StatefulWidget {
  final String text;
  final LyricLine lyric;
  final List<LyricLine> lyrics;
  final int index;

  const _KaraokeText({
    required this.text,
    required this.lyric,
    required this.lyrics,
    required this.index,
  });

  @override
  State<_KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<_KaraokeText> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  
  // ===== 逐字模式状态 =====
  // 每个字的填充进度 (0.0 - 1.0)
  List<double> _wordProgresses = [];
  
  // ===== 整行模式状态（回退） =====
  double _lineProgress = 0.0;
  
  // 布局测量缓存（用于整行模式）
  double _cachedMaxWidth = 0.0;
  TextStyle? _cachedStyle;
  List<LineMetrics>? _cachedLineMetrics;
  int _cachedLineCount = 1;
  double _line1Width = 0.0;
  double _line2Width = 0.0;
  double _line1Height = 0.0;
  double _line2Height = 0.0;
  double _line1Ratio = 0.5;
  
  // 计算歌词持续时间（缓存，用于整行模式）
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _calculateDuration();
    _initWordProgresses();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
  
  /// 初始化每个字的进度列表
  void _initWordProgresses() {
    if (widget.lyric.hasWordByWord && widget.lyric.words != null) {
      _wordProgresses = List.filled(widget.lyric.words!.length, 0.0);
    }
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
    final currentPos = PlayerService().position;

    // 检查是否有逐字歌词
    if (widget.lyric.hasWordByWord && widget.lyric.words != null) {
      // ===== 逐字模式：计算每个字的填充进度 =====
      _updateWordProgresses(currentPos);
    } else {
      // ===== 整行模式（回退）：使用平均计算 =====
      final elapsedFromStart = currentPos - widget.lyric.startTime;
      final newProgress = (elapsedFromStart.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

      if ((newProgress - _lineProgress).abs() > 0.005) {
        setState(() {
          _lineProgress = newProgress;
        });
      }
    }
  }

  /// 更新每个字的填充进度
  void _updateWordProgresses(Duration currentPos) {
    final words = widget.lyric.words!;
    if (words.isEmpty) return;

    bool needsUpdate = false;
    final newProgresses = List<double>.filled(words.length, 0.0);

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      double wordProgress;

      if (currentPos < word.startTime) {
        // 还没开始唱这个字
        wordProgress = 0.0;
      } else if (currentPos >= word.endTime) {
        // 这个字已经唱完
        wordProgress = 1.0;
      } else {
        // 正在唱这个字，计算内部进度
        final wordElapsed = currentPos - word.startTime;
        wordProgress = (wordElapsed.inMilliseconds / word.duration.inMilliseconds).clamp(0.0, 1.0);
      }

      newProgresses[i] = wordProgress;
      
      // 检查是否有变化
      if (i < _wordProgresses.length && (newProgresses[i] - _wordProgresses[i]).abs() > 0.01) {
        needsUpdate = true;
      }
    }

    if (needsUpdate || _wordProgresses.length != newProgresses.length) {
      setState(() {
        _wordProgresses = newProgresses;
      });
    }
  }
  
  /// 更新布局测量缓存（用于整行模式回退）
  void _updateLayoutCache(BoxConstraints constraints, TextStyle style) {
    if (_cachedMaxWidth == constraints.maxWidth && _cachedStyle == style) {
      return; // 缓存有效，无需重新测量
    }
    
    _cachedMaxWidth = constraints.maxWidth;
    _cachedStyle = style;
    
    final textSpan = TextSpan(text: widget.text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      maxLines: 2,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: constraints.maxWidth);
    
    _cachedLineMetrics = textPainter.computeLineMetrics();
    _cachedLineCount = _cachedLineMetrics!.length.clamp(1, 2);
    
    _line1Width = _cachedLineMetrics![0].width;
    _line2Width = _cachedLineMetrics!.length > 1 ? _cachedLineMetrics![1].width : 0.0;
    _line1Height = _cachedLineMetrics![0].height;
    _line2Height = _cachedLineMetrics!.length > 1 ? _cachedLineMetrics![1].height : 0.0;
    
    final totalWidth = _line1Width + _line2Width;
    _line1Ratio = totalWidth > 0 ? _line1Width / totalWidth : 0.5;
    
    textPainter.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    
    // 有逐字歌词数据时，使用逐字填充模式
    if (widget.lyric.hasWordByWord && widget.lyric.words != null && _wordProgresses.isNotEmpty) {
      return _buildWordByWordEffect(style);
    }
    
    // 无逐字歌词数据时，回退到整行模式
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateLayoutCache(constraints, style);
        return _buildLineGradientEffect(style);
      },
    );
  }
  
  /// 构建逐字填充效果（核心：每个字单独渲染）
  Widget _buildWordByWordEffect(TextStyle style) {
    final words = widget.lyric.words!;
    
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(words.length, (index) {
        final word = words[index];
        final progress = index < _wordProgresses.length ? _wordProgresses[index] : 0.0;
        
        return _WordFillWidget(
          text: word.text,
          progress: progress,
          style: style,
        );
      }),
    );
  }
  
  /// 构建整行渐变效果（回退模式）
  Widget _buildLineGradientEffect(TextStyle style) {
    if (_cachedLineCount == 1) {
      // 单行：使用 ShaderMask 实现高性能渐变
      return RepaintBoundary(
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Colors.white,
                Color(0x99FFFFFF), // Colors.white.withOpacity(0.60)
              ],
              stops: [_lineProgress, _lineProgress],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(widget.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      );
    }
    
    // 多行：计算每行进度
    double line1Progress, line2Progress;
    if (_lineProgress <= _line1Ratio) {
      line1Progress = _lineProgress / _line1Ratio;
      line2Progress = 0.0;
    } else {
      line1Progress = 1.0;
      line2Progress = (_lineProgress - _line1Ratio) / (1.0 - _line1Ratio);
    }
    
    // 底层暗色文本 (使用 const 颜色)
    final dimText = Text(
      widget.text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: const Color(0x99FFFFFF)),
    );
    
    // 上层亮色文本
    final brightText = Text(
      widget.text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: Colors.white),
    );
    
    return RepaintBoundary(
      child: Stack(
        children: [
          dimText,
          ClipRect(
            clipper: _LineClipper(
              lineIndex: 0,
              progress: line1Progress,
              lineHeight: _line1Height,
              lineWidth: _line1Width,
            ),
            child: brightText,
          ),
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

/// 单个字的填充组件
/// 使用 ShaderMask 实现带渐变边缘的从左到右填充效果
/// 同时支持双曲线上浮动画系统：
/// - 上升阶段：使用 cubic-bezier(0.55, 0.05, 0.85, 0.25) - 慢速起步，中间加速
/// - 悬停阶段：使用 cubic-bezier(0.0, 0.6, 0.2, 1.0) - 深度缓出，"无限趋近"感
/// 
/// 完全参考 LyricSphere 的实现：
/// - 渐变淡入区域 (fadeRatio = 0.3)
/// - 上浮距离基于字体大小的 10%
/// - 双阶段曲线系统
/// - 超长悬停保持
class _WordFillWidget extends StatelessWidget {
  final String text;
  final double progress; // 0.0 - 1.0
  final TextStyle style;
  
  // ===== 动画参数（完全参考 LyricSphere）=====
  static const double fadeRatio = 0.3;           // 渐变淡入区域比例
  
  // 上浮距离比例（相对于字体大小）
  static const double floatDistanceRatio = 0.10;  // 字体高度的 10%
  
  // 上升阶段占总进度的比例（LyricSphere 中约占 70%）
  static const double ascendPhaseRatio = 0.65;
  
  // 悬停阶段占总进度的比例
  static const double settlePhaseRatio = 0.35;

  const _WordFillWidget({
    required this.text,
    required this.progress,
    required this.style,
  });
  
  /// 检查文本是否主要由ASCII字符组成（英文/数字/标点）
  bool _isAsciiText() {
    if (text.isEmpty) return false;
    // 如果超过一半的字符是ASCII字母，视为英文文本
    int asciiCount = 0;
    for (final char in text.runes) {
      if ((char >= 65 && char <= 90) || (char >= 97 && char <= 122)) {
        asciiCount++;
      }
    }
    return asciiCount > text.length / 2;
  }
  
  /// LyricSphere 上升阶段曲线：cubic-bezier(0.55, 0.05, 0.85, 0.25)
  /// 特点：慢速起步，中间加速，末尾略减速
  /// 产生"渐入佳境"的感觉
  double _ascendCurve(double t) {
    // cubic-bezier(0.55, 0.05, 0.85, 0.25) 的近似实现
    // 这个曲线前半段很慢，后半段加速
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    
    // 使用三次贝塞尔曲线的简化公式
    // P0 = (0, 0), P1 = (0.55, 0.05), P2 = (0.85, 0.25), P3 = (1, 1)
    // 这里使用近似计算，效果接近原曲线
    final t2 = t * t;
    final t3 = t2 * t;
    
    // 近似 cubic-bezier(0.55, 0.05, 0.85, 0.25)
    // 前 50% 的输入只产生约 10% 的输出
    // 后 50% 的输入产生约 90% 的输出
    return 3 * (1 - t) * (1 - t) * t * 0.05 + 
           3 * (1 - t) * t2 * 0.25 + 
           t3;
  }
  
  /// LyricSphere 悬停阶段曲线：cubic-bezier(0.0, 0.6, 0.2, 1.0)
  /// 特点：快速起步，极度缓出，产生"无限趋近"的感觉
  double _settleCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    
    // cubic-bezier(0.0, 0.6, 0.2, 1.0) 的近似实现
    // 这个曲线一开始就很快，然后极度减速
    final t2 = t * t;
    final t3 = t2 * t;
    
    // 近似 cubic-bezier(0.0, 0.6, 0.2, 1.0)
    // 前 20% 的输入产生约 60% 的输出
    // 后 80% 的输入产生约 40% 的输出
    return 3 * (1 - t) * (1 - t) * t * 0.6 + 
           3 * (1 - t) * t2 * 1.0 + 
           t3;
  }
  
  /// 计算双曲线上浮偏移量
  /// 参考 LyricSphere 的双阶段动画系统：
  /// 1. 上升阶段：使用 ascendCurve，从 0 到最大高度
  /// 2. 悬停阶段：使用 settleCurve，保持在最大高度（几乎不动）
  double _calculateVerticalOffset(double progressValue, double fontSize) {
    // 上浮距离 = 字体大小 * 10%（参考 LyricSphere: spanHeight * 0.1）
    final maxFloatDistance = fontSize * floatDistanceRatio;
    
    if (progressValue <= 0) return 0;
    if (progressValue >= 1) return -maxFloatDistance;
    
    // 上升阶段：占 65% 的进度
    if (progressValue < ascendPhaseRatio) {
      final ascendProgress = progressValue / ascendPhaseRatio;
      // 使用 LyricSphere 风格的上升曲线
      final curvedProgress = _ascendCurve(ascendProgress);
      return -maxFloatDistance * curvedProgress;
    }
    
    // 悬停阶段：占 35% 的进度
    // 在 LyricSphere 中，这个阶段几乎是无限长的，字符保持在顶部
    // 我们用极度缓出的曲线来模拟这种效果
    final settleProgress = (progressValue - ascendPhaseRatio) / settlePhaseRatio;
    final curvedSettleProgress = _settleCurve(settleProgress);
    
    // 悬停阶段只允许极微小的回落（0.1像素），产生"无限趋近"感
    // 这比之前的 0.5 像素更接近 LyricSphere 的效果
    return -maxFloatDistance + (0.1 * curvedSettleProgress);
  }

  @override
  Widget build(BuildContext context) {
    // 英文单词：每个字母单独处理
    if (_isAsciiText() && text.length > 1) {
      return _buildLetterByLetterEffect();
    }
    
    // 中文/日文等：整个字符一起移动
    return _buildWholeWordEffect();
  }
  
  /// 构建整字上浮效果（中文/日文等）
  /// 使用 ShaderMask 实现渐变填充边缘
  Widget _buildWholeWordEffect() {
    // 获取字体大小用于计算上浮距离
    final fontSize = style.fontSize ?? 32.0;
    final verticalOffset = _calculateVerticalOffset(progress, fontSize);
    
    // 边界检查：当进度接近完成时，直接显示纯白色，避免白边问题
    if (progress >= 0.95) {
      return RepaintBoundary(
        child: Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Text(
            text, 
            style: style.copyWith(color: Colors.white),
          ),
        ),
      );
    }
    
    // 边界检查：当进度接近 0 时，直接显示暗色，避免计算误差
    if (progress <= 0.05) {
      return RepaintBoundary(
        child: Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Text(
            text, 
            style: style.copyWith(color: const Color(0x99FFFFFF)),
          ),
        ),
      );
    }
    
    // 计算渐变停止点，实现柔和的边缘
    // fadeStop: 渐变开始的位置（完全填充区域的末端）
    // fillStop: 渐变结束的位置（未填充区域的开始）
    final fadeStop = progress.clamp(0.0, 1.0);
    final fillStop = (progress + fadeRatio).clamp(0.0, 1.0);
    
    return RepaintBoundary(
      child: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Colors.white,                  // 完全填充
                Colors.white,                  // 完全填充（渐变开始前）
                Color(0x99FFFFFF),             // 渐变过渡（渐变结束后）
                Color(0x99FFFFFF),             // 未填充
              ],
              stops: [
                0.0,
                fadeStop,
                fillStop,
                1.0,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            text, 
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
  
  /// 构建逐字母上浮效果（英文单词）
  /// 每个字母独立计算填充进度和上浮偏移
  Widget _buildLetterByLetterEffect() {
    final letters = text.split('');
    final letterCount = letters.length;
    
    // 位移重叠系数：用于上浮动画，高重叠以形成波浪感
    const double displacementOverlapFactor = 3.0;  // 提高重叠系数，让波浪更连续
    
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(letterCount, (index) {
          final letter = letters[index];
          final baseWidth = 1.0 / letterCount;
          
          // ===== 1. 计算位移动画进度 (高重叠，波浪感) =====
          final waveExpandedWidth = baseWidth * (1.0 + displacementOverlapFactor);
          // 调整波浪起始点，让前面的字母更早开始上浮
          final waveStart = (index * baseWidth) - (baseWidth * displacementOverlapFactor * 0.5); 
          final waveEnd = waveStart + waveExpandedWidth;
          
          final rawWaveProgress = ((progress - waveStart) / (waveEnd - waveStart)).clamp(0.0, 1.0);
          // 获取字体大小用于计算上浮距离
          final fontSize = style.fontSize ?? 32.0;
          final verticalOffset = _calculateVerticalOffset(rawWaveProgress, fontSize);
          
          // ===== 2. 计算颜色填充进度 (带边界检查) =====
          final fillStart = index * baseWidth;
          final fillEnd = (index + 1) * baseWidth;
          final fillProgress = ((progress - fillStart) / (fillEnd - fillStart)).clamp(0.0, 1.0);
          
          // 边界检查：接近完成时直接显示白色
          if (fillProgress >= 0.95) {
            return Transform.translate(
              offset: Offset(0, verticalOffset),
              child: Text(
                letter, 
                style: style.copyWith(color: Colors.white),
              ),
            );
          }
          
          // 边界检查：接近开始时直接显示暗色
          if (fillProgress <= 0.05) {
            return Transform.translate(
              offset: Offset(0, verticalOffset),
              child: Text(
                letter, 
                style: style.copyWith(color: const Color(0x99FFFFFF)),
              ),
            );
          }
          
          // 渐变停止点（修正后的逻辑）
          final letterFadeStop = fillProgress.clamp(0.0, 1.0);
          final letterFillStop = (fillProgress + fadeRatio).clamp(0.0, 1.0);
          
          return Transform.translate(
            offset: Offset(0, verticalOffset),
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Colors.white,
                    Colors.white,
                    Color(0x99FFFFFF),
                    Color(0x99FFFFFF),
                  ],
                  stops: [
                    0.0,
                    letterFadeStop,
                    letterFillStop,
                    1.0,
                  ],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Text(
                letter, 
                style: style.copyWith(color: Colors.white),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 单个字的裁剪器
class _WordClipper extends CustomClipper<Rect> {
  final double progress;

  _WordClipper(this.progress);

  @override
  Rect getClip(Size size) {
    // 从左到右裁剪
    return Rect.fromLTRB(0, 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(_WordClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}



/// 自定义裁剪器：用于裁剪单行文本的进度
class _LineClipper extends CustomClipper<Rect> {
  final int lineIndex;
  final double progress;
  final double lineHeight;
  final double lineWidth;
  final double yOffset;

  _LineClipper({
    required this.lineIndex,
    required this.progress,
    required this.lineHeight,
    required this.lineWidth,
    this.yOffset = 0.0,
  });

  @override
  Rect getClip(Size size) {
    // 裁剪该行从左到右的进度部分
    final clipWidth = lineWidth * progress;
    return Rect.fromLTWH(0, yOffset, clipWidth, lineHeight);
  }

  @override
  bool shouldReclip(_LineClipper oldClipper) {
    return oldClipper.progress != progress ||
           oldClipper.lineIndex != lineIndex ||
           oldClipper.lineHeight != lineHeight ||
           oldClipper.lineWidth != lineWidth ||
           oldClipper.yOffset != yOffset;
  }
}

/// 倒计时点组件 - Apple Music 风格
/// 在第一句歌词开始前显示 3 个带填充动画的点
/// 特点：
/// - 弹出动画：三个点依次从小到大出现，带弹性过冲
/// - 弹入动画：三个点依次从大到小消失
/// - 交错延迟：每个点有不同延迟，产生波浪效果
class _CountdownDots extends StatefulWidget {
  final List<LyricLine> lyrics;
  final double countdownThreshold; // 倒计时开始阈值（秒）

  const _CountdownDots({
    required this.lyrics,
    required this.countdownThreshold,
  });

  @override
  State<_CountdownDots> createState() => _CountdownDotsState();
}

class _CountdownDotsState extends State<_CountdownDots> with TickerProviderStateMixin {
  late Ticker _ticker;
  double _progress = 0.0; // 0.0 - 1.0，表示整个倒计时的进度
  bool _isVisible = false;
  bool _wasVisible = false; // 用于检测可见性变化
  
  // 入场/出场动画控制器
  late AnimationController _appearController;
  late Animation<double> _appearAnimation;
  
  // 动画参数
  static const double _dotSize = 12.0;
  static const double _dotSpacing = 16.0;
  static const int _dotCount = 3;
  
  // 每个点的交错延迟（毫秒）
  static const int _staggerDelayMs = 80;

  @override
  void initState() {
    super.initState();
    
    // 入场/出场动画
    _appearController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _appearAnimation = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    
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
    if (widget.lyrics.isEmpty) {
      if (_isVisible) {
        setState(() {
          _isVisible = false;
        });
        _appearController.reverse();
      }
      return;
    }

    final firstLyricTime = widget.lyrics.first.startTime;
    final currentPos = PlayerService().position;
    final timeUntilFirstLyric = (firstLyricTime - currentPos).inMilliseconds / 1000.0;

    // 判断是否在倒计时窗口内
    final isPlaying = PlayerService().isPlaying;
    final shouldShow = isPlaying &&
        currentPos.inMilliseconds > 0 &&
        timeUntilFirstLyric > 0 &&
        timeUntilFirstLyric <= widget.countdownThreshold;

    if (shouldShow) {
      final newProgress = 1.0 - (timeUntilFirstLyric / widget.countdownThreshold);
      
      // 检测可见性变化 - 触发弹出动画
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
      // 触发弹入（消失）动画
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
        // 当动画完全结束且不可见时，返回空
        if (_appearAnimation.value <= 0.01 && !_isVisible) {
          return const SizedBox(height: 20); // 保持高度占位
        }
        
        return RepaintBoundary(
          child: SizedBox(
            height: 20, // 固定高度
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_dotCount, (index) {
                  // 计算每个点的填充进度
                  final dotStartProgress = index / _dotCount;
                  final dotEndProgress = (index + 1) / _dotCount;
                  
                  double dotProgress;
                  if (_progress <= dotStartProgress) {
                    dotProgress = 0.0;
                  } else if (_progress >= dotEndProgress) {
                    dotProgress = 1.0;
                  } else {
                    dotProgress = (_progress - dotStartProgress) / (dotEndProgress - dotStartProgress);
                  }
                  
                  // 计算每个点的交错延迟缩放
                  // 第一个点最先出现/最后消失
                  final staggerDelay = index * 0.15;
                  double appearScale;
                  if (_appearAnimation.value >= staggerDelay) {
                    appearScale = ((_appearAnimation.value - staggerDelay) / (1.0 - staggerDelay)).clamp(0.0, 1.0);
                  } else {
                    appearScale = 0.0;
                  }
                  // 应用弹性曲线
                  appearScale = _easeOutBack(appearScale);

                  return Padding(
                    padding: EdgeInsets.only(right: _dotSpacing),
                    child: Transform.scale(
                      scale: appearScale,
                      child: _CountdownDot(
                        size: _dotSize,
                        fillProgress: dotProgress,
                        appearProgress: appearScale,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// easeOutBack 曲线
  double _easeOutBack(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    
    const c1 = 1.70158;
    const c3 = c1 + 1;
    
    return 1 + c3 * (t - 1) * (t - 1) * (t - 1) + c1 * (t - 1) * (t - 1);
  }
}

/// 单个倒计时点 - Apple Music 风格
/// 特点：
/// - 外圈始终可见（半透明白色边框）
/// - 内圈根据填充进度从中心向外扩展
/// - 填充时有发光效果
class _CountdownDot extends StatelessWidget {
  final double size;
  final double fillProgress; // 0.0 - 1.0，填充进度
  final double appearProgress; // 0.0 - 1.0，出现动画进度

  const _CountdownDot({
    required this.size,
    required this.fillProgress,
    required this.appearProgress,
  });

  @override
  Widget build(BuildContext context) {
    // 内部填充圆的大小
    final innerSize = (size - 4) * _easeOutQuart(fillProgress);
    
    // 边框透明度随出现动画渐变
    final borderOpacity = 0.4 + (0.2 * appearProgress);
    
    // 填充圆的透明度
    final fillOpacity = 0.9;
    
    // 发光效果强度
    final glowIntensity = fillProgress > 0.3 ? (fillProgress - 0.3) / 0.7 : 0.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(borderOpacity),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(fillOpacity),
            boxShadow: glowIntensity > 0
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.4 * glowIntensity),
                      blurRadius: 8 * glowIntensity,
                      spreadRadius: 2 * glowIntensity,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
  
  /// easeOutQuart 曲线：平滑的减速曲线
  double _easeOutQuart(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return 1 - (1 - t) * (1 - t) * (1 - t) * (1 - t);
  }
}
