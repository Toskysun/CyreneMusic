import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../services/player_service.dart';
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

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _previousIndex = widget.currentLyricIndex;
  }

  @override
  void dispose() {
    _scrollResetTimer?.cancel();
    _timeCapsuleController.dispose();
    _spacingController.dispose();
    _scrollController.dispose();
    super.dispose();
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
            // 歌词列表
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
    return Center(
      child: Text(
        '纯音乐 / 暂无歌词',
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 42,
          fontWeight: FontWeight.w800,
          fontFamily: 'Microsoft YaHei',
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
            padding: EdgeInsets.symmetric(vertical: (_viewportHeight - effectiveItemHeight) / 2),
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
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: Column(
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
                            fontFamily: 'Microsoft YaHei',
                            height: 1.25,
                            letterSpacing: -0.5,
                            shadows: isActive ? [
                              Shadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 20,
                              ),
                            ] : null,
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
                                  fontFamily: 'Microsoft YaHei',
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

/// 卡拉OK文本组件 - 实现逐行填充效果
/// 对于多行文本：先从左到右填充第一行，再从左到右填充第二行
class _KaraokeText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PlayerService(),
      builder: (context, child) {
        final player = PlayerService();
        final currentPos = player.position;
        
        // 计算持续时间
        Duration duration;
        if (index < lyrics.length - 1) {
          duration = lyrics[index + 1].startTime - lyric.startTime;
        } else {
          duration = const Duration(seconds: 5);
        }
        
        if (duration.inMilliseconds == 0) duration = const Duration(seconds: 3);
        
        final elapsed = currentPos - lyric.startTime;
        final progress = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
        
        return LayoutBuilder(
          builder: (context, constraints) {
            return _buildKaraokeEffect(context, constraints, progress);
          },
        );
      },
    );
  }

  Widget _buildKaraokeEffect(BuildContext context, BoxConstraints constraints, double progress) {
    // 获取当前文本样式
    final style = DefaultTextStyle.of(context).style;
    
    // 创建 TextPainter 来测量文本
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      maxLines: 2,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: constraints.maxWidth);
    
    // 获取每行的信息
    final lineMetrics = textPainter.computeLineMetrics();
    final lineCount = lineMetrics.length.clamp(1, 2);
    
    if (lineCount == 1) {
      // 单行：简单的水平渐变
      return ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.45),
            ],
            stops: [progress, progress],
            tileMode: TileMode.clamp,
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcIn,
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      );
    }
    
    // 多行：使用 Stack 叠加实现逐行填充
    // 计算每行的宽度占比，用于分配进度
    final line1Width = lineMetrics[0].width;
    final line2Width = lineMetrics.length > 1 ? lineMetrics[1].width : 0.0;
    final totalWidth = line1Width + line2Width;
    
    // 第一行占总进度的比例
    final line1Ratio = totalWidth > 0 ? line1Width / totalWidth : 0.5;
    
    // 计算每行的进度
    double line1Progress, line2Progress;
    if (progress <= line1Ratio) {
      // 还在填充第一行
      line1Progress = progress / line1Ratio;
      line2Progress = 0.0;
    } else {
      // 第一行已填满，开始填充第二行
      line1Progress = 1.0;
      line2Progress = (progress - line1Ratio) / (1.0 - line1Ratio);
    }
    
    final line1Height = lineMetrics[0].height;
    // 第二行高度：使用实际的行高，并增加一些余量确保完整显示
    final line2Height = lineMetrics.length > 1 ? lineMetrics[1].height : 0.0;
    
    // 底层：暗色文本
    final dimText = Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: Colors.white.withOpacity(0.45)),
    );
    
    // 上层：亮色文本，通过裁剪显示进度
    final brightText = Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: Colors.white),
    );
    
    return Stack(
      children: [
        // 底层暗色文本
        dimText,
        
        // 第一行亮色部分
        ClipRect(
          clipper: _LineClipper(
            lineIndex: 0,
            progress: line1Progress,
            lineHeight: line1Height,
            lineWidth: line1Width,
          ),
          child: brightText,
        ),
        
        // 第二行亮色部分
        if (lineCount > 1)
          ClipRect(
            clipper: _LineClipper(
              lineIndex: 1,
              progress: line2Progress,
              lineHeight: line2Height + 10, // 增加余量确保完整显示
              lineWidth: line2Width,
              yOffset: line1Height, // 第二行起始位置
            ),
            child: brightText,
          ),
      ],
    );
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
