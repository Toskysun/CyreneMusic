import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../services/player_background_service.dart';
import '../../services/player_service.dart';
import '../../widgets/video_background_player.dart';
import '../../widgets/mesh_gradient_background.dart';

/// 动态背景颜色缓存管理器（全局单例）
/// 避免每次进入播放器页面都重新提取颜色
class _DynamicColorCache {
  static final _DynamicColorCache _instance = _DynamicColorCache._internal();
  factory _DynamicColorCache() => _instance;
  _DynamicColorCache._internal();

  final Map<String, List<Color>> _cache = {};
  String? _currentExtractingUrl;

  List<Color>? getColors(String imageUrl) => _cache[imageUrl];
  
  void setColors(String imageUrl, List<Color> colors) {
    _cache[imageUrl] = colors;
    // 限制缓存大小
    if (_cache.length > 20) {
      _cache.remove(_cache.keys.first);
    }
  }

  bool isExtracting(String imageUrl) => _currentExtractingUrl == imageUrl;
  void setExtracting(String? imageUrl) => _currentExtractingUrl = imageUrl;
}

/// 流体云播放器专用背景组件
/// 
/// 自适应模式下的行为：
/// - 开启封面渐变：显示专辑封面到主题色的渐变效果
/// - 关闭封面渐变：显示专辑封面 100% 填充（保持长宽比）
/// - 动态背景：基于封面提取3个颜色的动态渐变动画
/// - 用户仍可自定义纯色、视频或图片背景
class PlayerFluidCloudBackground extends StatefulWidget {
  const PlayerFluidCloudBackground({super.key});

  @override
  State<PlayerFluidCloudBackground> createState() => _PlayerFluidCloudBackgroundState();
}

class _PlayerFluidCloudBackgroundState extends State<PlayerFluidCloudBackground> {
  // 动态背景颜色
  List<Color> _dynamicColors = DynamicBackgroundColorExtractor.getDefaultColors();
  String? _currentImageUrl;
  bool _isFirstBuild = true;
  
  // 防抖计时器
  int _pendingExtractionId = 0;
  
  // 记录最后一次调度的图片URL，防止PlayerService频繁通知（如进度更新）导致防抖计时器不断重置
  String? _lastScheduledImageUrl;

  @override
  void initState() {
    super.initState();
    // 只监听背景设置变化，不监听 PlayerService（避免频繁触发）
    PlayerBackgroundService().addListener(_onBackgroundChanged);
    
    // 监听 PlayerService 以获取歌曲变化
    // 注意：PlayerService 会发送进度更新等频繁通知，所以在处理时必须进行过滤
    PlayerService().addListener(_onPlayerServiceChanged);
  }

  @override
  void dispose() {
    PlayerBackgroundService().removeListener(_onBackgroundChanged);
    PlayerService().removeListener(_onPlayerServiceChanged);
    super.dispose();
  }

  void _onPlayerServiceChanged() {
    if (mounted && PlayerBackgroundService().backgroundType == PlayerBackgroundType.dynamic) {
      // 尝试调度颜色提取
      // _scheduleColorExtraction 内部会处理去重，避免频繁的进度更新导致重复计算
      _scheduleColorExtraction();
    }
  }

  void _onBackgroundChanged() {
    if (mounted) {
      setState(() {});
      if (PlayerBackgroundService().backgroundType == PlayerBackgroundType.dynamic) {
        _scheduleColorExtraction();
      }
    }
  }

  /// 延迟调度颜色提取（带防抖）
  void _scheduleColorExtraction() {
    final backgroundService = PlayerBackgroundService();
    if (backgroundService.backgroundType != PlayerBackgroundType.dynamic) {
      return;
    }

    final song = PlayerService().currentSong;
    final track = PlayerService().currentTrack;
    final imageUrl = song?.pic ?? track?.picUrl ?? '';

    // 1. 如果没有图片，或者当前已经在显示这张图片的颜色，直接返回
    if (imageUrl.isEmpty || imageUrl == _currentImageUrl) return;

    // 2. 如果已经调度了这张图片的提取任务（正在防抖等待中），直接返回
    // 这一步至关重要，因为PlayerService的进度更新频率很高（每秒多次）
    // 如果不加这个检查，每次进度更新都会重置防抖计时器，导致永远无法触发提取
    if (imageUrl == _lastScheduledImageUrl) return;

    // 记录这次调度的URL
    _lastScheduledImageUrl = imageUrl;

    // 检查缓存 - 如果有缓存立即使用
    final cachedColors = _DynamicColorCache().getColors(imageUrl);
    if (cachedColors != null) {
      _currentImageUrl = imageUrl;
      if (mounted) {
        setState(() {
          _dynamicColors = cachedColors;
        });
      }
      return;
    }

    // 防抖：取消之前的提取请求
    _pendingExtractionId++;
    final currentId = _pendingExtractionId;

    // 延迟300ms后提取（减少延迟时间，但使用防抖避免重复）
    Future.delayed(const Duration(milliseconds: 300), () {
      // 如果ID不匹配，说明有新的请求，取消当前请求
      if (currentId != _pendingExtractionId || !mounted) return;
      _extractColorsFromImage(imageUrl);
    });
  }

  /// 从图片中提取颜色
  Future<void> _extractColorsFromImage(String imageUrl) async {
    // 检查是否正在提取同一张图片
    if (_DynamicColorCache().isExtracting(imageUrl)) return;
    // 再次检查缓存（可能在等待期间已经被其他地方提取）
    final cachedColors = _DynamicColorCache().getColors(imageUrl);
    if (cachedColors != null) {
      _currentImageUrl = imageUrl;
      if (mounted) {
        setState(() => _dynamicColors = cachedColors);
      }
      return;
    }
    
    _DynamicColorCache().setExtracting(imageUrl);
    _currentImageUrl = imageUrl;

    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      
      // 使用较小的图片尺寸和较少的颜色数量来提高性能
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(32, 32), // 更小的尺寸进一步提升性能
        maximumColorCount: 6,     // 更少的颜色
        timeout: const Duration(seconds: 1),
      );

      final colors = DynamicBackgroundColorExtractor.extractColors(
        vibrantColor: paletteGenerator.vibrantColor?.color,
        mutedColor: paletteGenerator.mutedColor?.color,
        dominantColor: paletteGenerator.dominantColor?.color,
        lightVibrantColor: paletteGenerator.lightVibrantColor?.color,
        darkVibrantColor: paletteGenerator.darkVibrantColor?.color,
        lightMutedColor: paletteGenerator.lightMutedColor?.color,
        darkMutedColor: paletteGenerator.darkMutedColor?.color,
      );

      // 缓存结果
      _DynamicColorCache().setColors(imageUrl, colors);

      if (mounted && _currentImageUrl == imageUrl) {
        setState(() {
          _dynamicColors = colors;
        });
      }
    } catch (e) {
      // 静默失败，保持当前颜色
    } finally {
      _DynamicColorCache().setExtracting(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 首次构建时，延迟调度颜色提取
    if (_isFirstBuild) {
      _isFirstBuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleColorExtraction();
      });
    }
    return _buildBackground();
  }

  /// 构建背景（根据设置选择背景类型）
  Widget _buildBackground() {
    final backgroundService = PlayerBackgroundService();
    final greyColor = Colors.grey[900] ?? const Color(0xFF212121);
    
    switch (backgroundService.backgroundType) {
      case PlayerBackgroundType.adaptive:
        // 自适应模式：根据封面渐变开关决定背景样式
        if (backgroundService.enableGradient) {
          return _buildCoverGradientBackground(greyColor);
        } else {
          return _buildAlbumCoverBackground(greyColor);
        }
        
      case PlayerBackgroundType.solidColor:
        // 纯色背景
        return _buildSolidColorBackground(backgroundService, greyColor);
        
      case PlayerBackgroundType.image:
        // 图片背景
        return _buildImageBackground(backgroundService, greyColor);
        
      case PlayerBackgroundType.video:
        // 视频背景
        return _buildVideoBackground(backgroundService, greyColor);
        
      case PlayerBackgroundType.dynamic:
        // 动态背景
        return _buildDynamicBackground(greyColor);
    }
  }

  /// 构建动态背景
  Widget _buildDynamicBackground(Color greyColor) {
    return RepaintBoundary(
      child: MeshGradientBackground(
        colors: _dynamicColors,
        speed: 0.3,
        backgroundColor: _dynamicColors.isNotEmpty ? _dynamicColors[0] : greyColor,
        animate: true,
      ),
    );
  }

  /// 构建封面渐变背景（开启封面渐变时使用）
  /// 专辑封面在左侧，渐变过渡到右侧的主题色
  Widget _buildCoverGradientBackground(Color greyColor) {
    // 使用 ListenableBuilder 监听 PlayerService，确保歌曲切换时封面也会更新
    return ListenableBuilder(
      listenable: PlayerService(),
      builder: (context, _) {
        final song = PlayerService().currentSong;
        final track = PlayerService().currentTrack;
        final imageUrl = song?.pic ?? track?.picUrl ?? '';
        
        return ValueListenableBuilder<Color?>(
          valueListenable: PlayerService().themeColorNotifier,
          builder: (context, themeColor, child) {
            final color = themeColor ?? Colors.grey[700]!;
            
            return RepaintBoundary(
              child: Stack(
                children: [
                  // 底层纯主题色背景
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      color: color,
                    ),
                  ),
                  
                  // 专辑封面层 - 等比例放大至占满高度，位于左侧
                  if (imageUrl.isNotEmpty)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: AspectRatio(
                        aspectRatio: 1.1, // 横向宽度增加10%（1.0 -> 1.1）
                        child: Stack(
                          children: [
                            // 封面图片
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: greyColor,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: greyColor,
                              ),
                            ),
                            // 封面右侧渐变遮罩 - 让封面边缘自然融入背景
                            Positioned.fill(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,  // 左侧和中间保持透明，显示封面
                                      Colors.transparent,
                                      color.withOpacity(0.3),  // 右侧开始融合主题色
                                      color.withOpacity(0.7),  // 最右侧更多主题色
                                    ],
                                    stops: const [0.0, 0.6, 0.85, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // 渐变遮罩层 - 从封面到主题色的丝滑渐变
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,        // 左侧完全透明，显示封面原貌
                            color.withOpacity(0.5),    // 左中部开始融合主题色
                            color.withOpacity(0.85),   // 中部主题色更明显
                            color,                      // 右侧完全不透明的主题色
                          ],
                          stops: const [0.0, 0.25, 0.5, 0.7],  // 更自然的渐变分布
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 构建专辑封面背景（关闭封面渐变时使用）
  /// 专辑封面 100% 填充，保持长宽比，居中裁剪
  Widget _buildAlbumCoverBackground(Color greyColor) {
    // 使用 ListenableBuilder 监听 PlayerService，确保歌曲切换时封面也会更新
    return ListenableBuilder(
      listenable: PlayerService(),
      builder: (context, _) {
        final song = PlayerService().currentSong;
        final track = PlayerService().currentTrack;
        final imageUrl = song?.pic ?? track?.picUrl ?? '';
        
        if (imageUrl.isEmpty) {
          // 没有封面时显示默认背景
          return _buildDefaultBackground(greyColor);
        }
        
        return RepaintBoundary(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover, // 100% 填充，保持长宽比，居中裁剪
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => _buildDefaultBackground(greyColor),
            errorWidget: (context, url, error) => _buildDefaultBackground(greyColor),
          ),
        );
      },
    );
  }

  /// 构建默认背景（无封面时使用）
  Widget _buildDefaultBackground(Color greyColor) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              greyColor,
              Color.lerp(greyColor, Colors.black, 0.5)!,
              Colors.black,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  /// 构建纯色背景
  Widget _buildSolidColorBackground(PlayerBackgroundService backgroundService, Color greyColor) {
    final topColor = backgroundService.solidColor;
    
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // 增加插值点以提高精度
            colors: [
              topColor,
              Color.lerp(topColor, greyColor, 0.25)!,
              Color.lerp(topColor, greyColor, 0.5)!,
              Color.lerp(topColor, greyColor, 0.75)!,
              greyColor,
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  /// 构建图片背景
  Widget _buildImageBackground(PlayerBackgroundService backgroundService, Color greyColor) {
    if (backgroundService.mediaPath != null) {
      final mediaFile = File(backgroundService.mediaPath!);
      if (mediaFile.existsSync()) {
        // 性能优化：RepaintBoundary 隔离重绘区域
        return RepaintBoundary(
          child: Stack(
            children: [
              // 图片层
              Positioned.fill(
                child: Image.file(
                  mediaFile,
                  fit: BoxFit.cover,
                  // 性能优化：限制解码尺寸，避免大图片阻塞主线程
                  cacheWidth: 1920,
                  cacheHeight: 1080,
                  isAntiAlias: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              // 模糊层（性能优化：限制模糊程度避免GPU过载）
              if (backgroundService.blurAmount > 0 && backgroundService.blurAmount <= 40)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: backgroundService.blurAmount,
                      sigmaY: backgroundService.blurAmount,
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(0.3), // 添加半透明遮罩
                    ),
                  ),
                )
              else if (backgroundService.blurAmount == 0)
                // 无模糊时也添加浅色遮罩以确保文字可读
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                  ),
                ),
            ],
          ),
        );
      }
    }
    
    // 如果没有设置图片，使用默认背景
    return _buildDefaultBackground(greyColor);
  }
  
  /// 构建视频背景
  Widget _buildVideoBackground(PlayerBackgroundService backgroundService, Color greyColor) {
    if (backgroundService.mediaPath != null) {
      final mediaFile = File(backgroundService.mediaPath!);
      if (mediaFile.existsSync()) {
        return Stack(
          children: [
            // 视频层
            Positioned.fill(
              child: VideoBackgroundPlayer(
                videoPath: backgroundService.mediaPath!,
                blurAmount: backgroundService.blurAmount,
                opacity: 1.0,
              ),
            ),
            // 半透明遮罩确保文字可读
            if (backgroundService.blurAmount == 0)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                ),
              ),
          ],
        );
      }
    }
    
    // 如果没有设置视频，使用默认背景
    return _buildDefaultBackground(greyColor);
  }
}
