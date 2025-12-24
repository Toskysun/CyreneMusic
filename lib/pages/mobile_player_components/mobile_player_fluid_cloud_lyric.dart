import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../services/player_service.dart';
import '../../services/lyric_font_service.dart';
import '../../models/lyric_line.dart';

/// 移动端流体云样式歌词组件
/// 适配移动端的触摸交互和屏幕尺寸
class MobilePlayerFluidCloudLyric extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;
  final VoidCallback? onTap;

  const MobilePlayerFluidCloudLyric({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    this.showTranslation = true,
    this.onTap,
  });

  @override
  State<MobilePlayerFluidCloudLyric> createState() => _MobilePlayerFluidCloudLyricState();
}

class _MobilePlayerFluidCloudLyricState extends State<MobilePlayerFluidCloudLyric> 
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  int? _selectedLyricIndex; // 手动选择的歌词索引
  bool _isManualMode = false; // 是否处于手动模式
  Timer? _autoResetTimer; // 自动回退定时器
  AnimationController? _timeCapsuleAnimationController;
  Animation<double>? _timeCapsuleFadeAnimation;
  
  // 流体动画控制器
  late AnimationController _fluidAnimationController;
  late Animation<double> _fluidAnimation;
  
  // QQ弹弹效果动画控制器
  late AnimationController _bounceAnimationController;
  late Animation<double> _bounceAnimation;
  
  // 滚动速度追踪
  double _scrollVelocity = 0.0;
  int _lastLyricIndex = -1;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    _timeCapsuleAnimationController?.dispose();
    _fluidAnimationController.dispose();
    _bounceAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 初始化动画
  void _initializeAnimations() {
    // 时间胶囊动画
    _timeCapsuleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _timeCapsuleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _timeCapsuleAnimationController!,
      curve: Curves.easeInOut,
    ));
    
    // 流体动画（持续循环）- 使用更柔和的曲线
    _fluidAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    
    _fluidAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fluidAnimationController,
      curve: Curves.easeInOutSine, // 更柔和的正弦曲线
    ));
    
    // QQ弹弹效果动画
    _bounceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceAnimationController,
      curve: Curves.elasticOut, // 弹性曲线
    ));
  }

  @override
  void didUpdateWidget(MobilePlayerFluidCloudLyric oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果当前播放索引变化且不处于手动模式，则滚动
    if (widget.currentLyricIndex != oldWidget.currentLyricIndex && !_isManualMode) {
      // 触发QQ弹弹效果
      if (_lastLyricIndex != widget.currentLyricIndex) {
        _lastLyricIndex = widget.currentLyricIndex;
        _bounceAnimationController.forward(from: 0.0);
      }
      _scrollToCurrentLyric();
    }
  }

  /// 滚动到当前歌词
  void _scrollToCurrentLyric() {
    if (!_scrollController.hasClients) return;
    setState(() {}); // 触发 build 以重新计算滚动位置
  }

  /// 开始手动模式
  void _startManualMode() {
    if (_isManualMode) {
      _resetAutoTimer();
      return;
    }

    setState(() {
      _isManualMode = true;
    });
    
    _timeCapsuleAnimationController?.forward();
    _resetAutoTimer();
  }

  /// 重置自动回退定时器
  void _resetAutoTimer() {
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(seconds: 4), _exitManualMode);
  }

  /// 退出手动模式
  void _exitManualMode() {
    if (!mounted) return;
    
    setState(() {
      _isManualMode = false;
      _selectedLyricIndex = null;
    });
    
    _timeCapsuleAnimationController?.reverse();
    _autoResetTimer?.cancel();
    
    // 退出手动模式后，立即滚回当前歌词
    _scrollToCurrentLyric();
  }

  /// 跳转到选中的歌词时间
  void _seekToSelectedLyric() {
    if (_selectedLyricIndex != null && 
        _selectedLyricIndex! >= 0 && 
        _selectedLyricIndex! < widget.lyrics.length) {
      
      final selectedLyric = widget.lyrics[_selectedLyricIndex!];
      if (selectedLyric.startTime != null) {
        PlayerService().seek(selectedLyric.startTime!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已跳转到: ${selectedLyric.text}'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          ),
        );
      }
    }
    
    _exitManualMode();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap, // 支持点击进入全屏歌词页（如果需要）
      child: Container(
        padding: EdgeInsets.zero, 
        child: Stack(
          children: [
            // 主要歌词区域
            widget.lyrics.isEmpty
                ? _buildNoLyric()
                : _buildFluidCloudLyricList(),
            
            // 时间胶囊组件 (当手动模式开启且选中的索引有效时显示)
            if (_isManualMode && _selectedLyricIndex != null)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(child: _buildTimeCapsule()),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建无歌词提示
  Widget _buildNoLyric() {
    final fontFamily = LyricFontService().currentFontFamily ?? 'Microsoft YaHei';
    return Center(
      child: Text(
        '暂无歌词',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 16,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  /// 构建流体云样式歌词列表
  Widget _buildFluidCloudLyricList() {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 移动端可视行数 - 动态调整以实现弹性间距
          const int baseVisibleLines = 6;
          // 根据滚动速度动态调整间距（速度越快，间距稍微增大，产生拉伸效果）
          final velocityFactor = (1.0 + (_scrollVelocity.abs() * 0.0001)).clamp(1.0, 1.15);
          final itemHeight = (constraints.maxHeight / baseVisibleLines) * velocityFactor;
          final viewportHeight = constraints.maxHeight;
          
          // 确保在非手动模式下滚动到正确位置
          if (!_isManualMode && _scrollController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (_scrollController.hasClients && mounted) {
                 final targetOffset = widget.currentLyricIndex * itemHeight;
                 if ((_scrollController.offset - targetOffset).abs() > viewportHeight * 2) {
                    _scrollController.jumpTo(targetOffset);
                 } else {
                    // 使用弹性曲线，让滚动更丝滑
                    _scrollController.animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 800), // 增加动画时间
                      curve: Curves.easeOutCubic, // 使用平滑的缓出曲线
                    );
                 }
               }
            });
          }
          
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification && 
                  notification.dragDetails != null) {
                _startManualMode();
              } else if (notification is ScrollUpdateNotification) {
                // 追踪滚动速度用于动态间距
                if (notification.scrollDelta != null) {
                  setState(() {
                    _scrollVelocity = notification.scrollDelta!;
                  });
                }
                
                if (_isManualMode) {
                  final centerOffset = _scrollController.offset + (viewportHeight / 2);
                  final index = (centerOffset / itemHeight).floor();
                  
                  if (index >= 0 && index < widget.lyrics.length && index != _selectedLyricIndex) {
                    setState(() {
                      _selectedLyricIndex = index;
                    });
                  }
                  _resetAutoTimer();
                }
              } else if (notification is ScrollEndNotification) {
                // 滚动结束，重置速度
                setState(() {
                  _scrollVelocity = 0.0;
                });
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.lyrics.length,
              itemExtent: itemHeight,
              padding: EdgeInsets.symmetric(
                vertical: (viewportHeight - itemHeight) / 2
              ),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final lyric = widget.lyrics[index];
                final isActuallyPlaying = index == widget.currentLyricIndex;
                
                final displayIndex = _isManualMode && _selectedLyricIndex != null 
                    ? _selectedLyricIndex! 
                    : widget.currentLyricIndex;
                
                final distance = (index - displayIndex).abs();
                
                // 视觉参数调整 - 更柔和的过渡
                final opacity = (1.0 - (distance * 0.18)).clamp(0.15, 1.0); // 更柔和的不透明度衰减
                final scale = (1.0 - (distance * 0.04)).clamp(0.90, 1.0); // 更柔和的缩放衰减
                final blur = distance == 0 ? 0.0 : (distance * 0.5).clamp(0.0, 1.2); // 渐进式模糊
                
                return Center(
                  child: AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      // 只对当前播放的歌词应用弹跳效果
                      final bounceScale = isActuallyPlaying ? _bounceAnimation.value : 1.0;
                      
                      return Transform.scale(
                        scale: scale * bounceScale,
                        child: Opacity(
                          opacity: opacity,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                            child: isActuallyPlaying
                                ? _buildFluidCloudLyricLine(
                                    lyric, 
                                    itemHeight, 
                                    true
                                  )
                                : _buildNormalLyricLine(
                                    lyric, 
                                    itemHeight
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// 构建流体云样式的歌词行（当前歌词）
  Widget _buildFluidCloudLyricLine(
    LyricLine lyric, 
    double itemHeight, 
    bool isActuallyPlaying
  ) {
    final isSelected = _isManualMode && !isActuallyPlaying; 
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 如果是正在播放且有逐字歌词，使用精确填充动画
          if (isActuallyPlaying && lyric.hasWordByWord)
            _MobileKaraokeText(
              lyric: lyric,
              lyrics: widget.lyrics,
              index: widget.currentLyricIndex,
              isSelected: isSelected,
            )
          else
            // 否则使用简单的流体动画
            AnimatedBuilder(
              animation: _fluidAnimation,
              builder: (context, child) {
                return _buildFluidCloudText(
                  text: lyric.text,
                  fontSize: 22,
                  isSelected: isSelected,
                  isPlaying: isActuallyPlaying,
                );
              },
            ),
          
          if (widget.showTranslation && 
              lyric.translation != null && 
              lyric.translation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                lyric.translation!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontFamily: LyricFontService().currentFontFamily ?? 'Microsoft YaHei',
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建普通歌词行（非当前歌词）
  Widget _buildNormalLyricLine(LyricLine lyric, double itemHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            lyric.text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18, // 普通行字体
              fontWeight: FontWeight.w600,
              height: 1.2,
              fontFamily: LyricFontService().currentFontFamily ?? 'Microsoft YaHei',
            ),
          ),
          if (widget.showTranslation && 
              lyric.translation != null && 
              lyric.translation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                lyric.translation!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontFamily: LyricFontService().currentFontFamily ?? 'Microsoft YaHei',
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建流体云文字效果
  Widget _buildFluidCloudText({
    required String text,
    required double fontSize,
    required bool isSelected,
    required bool isPlaying,
  }) {
    final fluidValue = _fluidAnimation.value;
    final actualFontSize = fontSize * 1.2; 
    
    // 移动端使用更鲜艳的渐变
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: isSelected 
        ? [
            Colors.orange.withOpacity(0.6),
            Colors.orange,
            Colors.deepOrange,
            Colors.orange,
            Colors.orange.withOpacity(0.6),
          ]
        : [
            Colors.white,
            Colors.white, 
            Colors.white.withOpacity(0.9), // 高亮部分略有不同
            Colors.white,
            Colors.white,
          ],
      stops: [
        0.0,
        math.max(0.0, fluidValue - 0.4),
        fluidValue,
        math.min(1.0, fluidValue + 0.4),
        1.0,
      ],
    );
    
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: actualFontSize,
          fontWeight: FontWeight.w800,
          fontFamily: LyricFontService().currentFontFamily ?? 'Microsoft YaHei',
          height: 1.2,
          shadows: isSelected 
            ? [
                Shadow(
                  color: Colors.orange.withOpacity(0.6),
                  blurRadius: 12,
                  offset: const Offset(0, 0),
                ),
              ]
            : [
                Shadow(
                  color: Colors.white.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 0),
                ),
              ],
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建时间胶囊组件
  Widget _buildTimeCapsule() {
    if (_selectedLyricIndex == null || 
        _selectedLyricIndex! < 0 || 
        _selectedLyricIndex! >= widget.lyrics.length) {
      return const SizedBox.shrink();
    }

    final selectedLyric = widget.lyrics[_selectedLyricIndex!];
    final timeText = selectedLyric.startTime != null 
        ? _formatDuration(selectedLyric.startTime!)
        : '00:00';

    return FadeTransition(
      opacity: _timeCapsuleFadeAnimation!,
      child: GestureDetector(
        onTap: _seekToSelectedLyric,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                timeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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

/// 移动端卡拉OK文本组件 - 实现逐字填充效果
/// 支持两种模式：
/// 1. 有逐字歌词数据时：每个字单独渲染并高亮
/// 2. 无逐字歌词数据时：回退到整行渐变填充
class _MobileKaraokeText extends StatefulWidget {
  final LyricLine lyric;
  final List<LyricLine> lyrics;
  final int index;
  final bool isSelected;

  const _MobileKaraokeText({
    required this.lyric,
    required this.lyrics,
    required this.index,
    required this.isSelected,
  });

  @override
  State<_MobileKaraokeText> createState() => _MobileKaraokeTextState();
}

class _MobileKaraokeTextState extends State<_MobileKaraokeText> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  
  // ===== 逐字模式状态 =====
  List<double> _wordProgresses = [];
  
  // ===== 整行模式状态（回退） =====
  double _lineProgress = 0.0;
  
  // 行持续时间
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

  void _updateWordProgresses(Duration currentPos) {
    final words = widget.lyric.words!;
    if (words.isEmpty) return;

    bool needsUpdate = false;
    final newProgresses = List<double>.filled(words.length, 0.0);

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      double wordProgress;

      if (currentPos < word.startTime) {
        wordProgress = 0.0;
      } else if (currentPos >= word.endTime) {
        wordProgress = 1.0;
      } else {
        final wordElapsed = currentPos - word.startTime;
        wordProgress = (wordElapsed.inMilliseconds / word.duration.inMilliseconds).clamp(0.0, 1.0);
      }

      newProgresses[i] = wordProgress;
      
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

  @override
  Widget build(BuildContext context) {
    final actualFontSize = 22.0 * 1.2;
    final style = TextStyle(
      color: Colors.white,
      fontSize: actualFontSize,
      fontWeight: FontWeight.w800,
      fontFamily: LyricFontService().currentFontFamily ?? 'Microsoft YaHei',
      height: 1.2,
      shadows: widget.isSelected
          ? [
              Shadow(
                color: Colors.orange.withOpacity(0.6),
                blurRadius: 12,
                offset: const Offset(0, 0),
              ),
            ]
          : [
              Shadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 0),
              ),
            ],
    );
    
    // 有逐字歌词数据时，使用逐字填充模式
    if (widget.lyric.hasWordByWord && widget.lyric.words != null && _wordProgresses.isNotEmpty) {
      return _buildWordByWordEffect(style);
    }
    
    // 无逐字歌词数据时，回退到整行渐变模式
    return _buildLineGradientEffect(style);
  }
  
  /// 构建逐字填充效果
  Widget _buildWordByWordEffect(TextStyle style) {
    final words = widget.lyric.words!;
    
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(words.length, (index) {
        final word = words[index];
        final progress = index < _wordProgresses.length ? _wordProgresses[index] : 0.0;
        
        return _MobileWordFillWidget(
          text: word.text,
          progress: progress,
          style: style,
          isSelected: widget.isSelected,
        );
      }),
    );
  }
  
  /// 构建整行渐变效果（回退模式）
  Widget _buildLineGradientEffect(TextStyle style) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: widget.isSelected
              ? [
                  Colors.orange,
                  Colors.orange.withOpacity(0.5),
                ]
              : [
                  Colors.white,
                  Colors.white.withOpacity(0.45),
                ],
          stops: [_lineProgress, _lineProgress],
          tileMode: TileMode.clamp,
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        widget.lyric.text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// 移动端单个字的填充组件
/// 使用 ShaderMask 实现带渐变边缘的从左到右填充效果
/// 同时支持双曲线上浮动画系统：
/// - 上升阶段：使用 cubic-bezier(0.55, 0.05, 0.85, 0.25) - 慢速起步，中间加速
/// - 悬停阶段：使用 cubic-bezier(0.0, 0.6, 0.2, 1.0) - 深度缓出，"无限趋近"感
/// 
/// 完全参考 LyricSphere 的实现：
/// - 渐变淡入区域 (fadeRatio = 0.3)
/// - 上浮距离基于字体大小的 8%（移动端略小）
/// - 双阶段曲线系统
/// - 超长悬停保持
class _MobileWordFillWidget extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle style;
  final bool isSelected;
  
  // ===== 动画参数（完全参考 LyricSphere，移动端微调）=====
  static const double fadeRatio = 0.3;           // 渐变淡入区域比例
  
  // 上浮距离比例（相对于字体大小，移动端略小）
  static const double floatDistanceRatio = 0.08;  // 字体高度的 8%
  
  // 上升阶段占总进度的比例
  static const double ascendPhaseRatio = 0.65;
  
  // 悬停阶段占总进度的比例
  static const double settlePhaseRatio = 0.35;

  const _MobileWordFillWidget({
    required this.text,
    required this.progress,
    required this.style,
    required this.isSelected,
  });
  
  /// LyricSphere 上升阶段曲线：cubic-bezier(0.55, 0.05, 0.85, 0.25)
  /// 特点：慢速起步，中间加速，末尾略减速
  double _ascendCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    
    final t2 = t * t;
    final t3 = t2 * t;
    
    // 近似 cubic-bezier(0.55, 0.05, 0.85, 0.25)
    return 3 * (1 - t) * (1 - t) * t * 0.05 + 
           3 * (1 - t) * t2 * 0.25 + 
           t3;
  }
  
  /// LyricSphere 悬停阶段曲线：cubic-bezier(0.0, 0.6, 0.2, 1.0)
  /// 特点：快速起步，极度缓出，产生"无限趋近"的感觉
  double _settleCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    
    final t2 = t * t;
    final t3 = t2 * t;
    
    // 近似 cubic-bezier(0.0, 0.6, 0.2, 1.0)
    return 3 * (1 - t) * (1 - t) * t * 0.6 + 
           3 * (1 - t) * t2 * 1.0 + 
           t3;
  }
  
  /// 计算双曲线上浮偏移量
  double _calculateVerticalOffset(double progressValue, double fontSize) {
    // 上浮距离 = 字体大小 * 8%（移动端略小）
    final maxFloatDistance = fontSize * floatDistanceRatio;
    
    if (progressValue <= 0) return 0;
    if (progressValue >= 1) return -maxFloatDistance;
    
    // 上升阶段：占 65% 的进度
    if (progressValue < ascendPhaseRatio) {
      final ascendProgress = progressValue / ascendPhaseRatio;
      final curvedProgress = _ascendCurve(ascendProgress);
      return -maxFloatDistance * curvedProgress;
    }
    
    // 悬停阶段：占 35% 的进度
    final settleProgress = (progressValue - ascendPhaseRatio) / settlePhaseRatio;
    final curvedSettleProgress = _settleCurve(settleProgress);
    
    // 悬停阶段只允许极微小的回落，产生"无限趋近"感
    return -maxFloatDistance + (0.05 * curvedSettleProgress);
  }

  @override
  Widget build(BuildContext context) {
    // 获取字体大小用于计算上浮距离
    final fontSize = style.fontSize ?? 26.0;
    final verticalOffset = _calculateVerticalOffset(progress, fontSize);
    
    // 选中状态使用橙色，否则使用白色
    final fillColor = isSelected ? Colors.orange : Colors.white;
    final dimColor = isSelected 
        ? Colors.orange.withOpacity(0.60)
        : Colors.white.withOpacity(0.60);
    
    // 边界检查：当进度接近完成时，直接显示纯填充色，避免白边问题
    if (progress >= 0.95) {
      return RepaintBoundary(
        child: Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Text(
            text, 
            style: style.copyWith(color: fillColor),
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
            style: style.copyWith(color: dimColor),
          ),
        ),
      );
    }
    
    // 计算渐变停止点（修正后的逻辑）
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
              colors: [
                fillColor,              // 完全填充
                fillColor,              // 完全填充（渐变开始前）
                dimColor,               // 渐变过渡（渐变结束后）
                dimColor,               // 未填充
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
}

/// 移动端单个字的裁剪器（保留用于回退模式）
class _MobileWordClipper extends CustomClipper<Rect> {
  final double progress;

  _MobileWordClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(_MobileWordClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

