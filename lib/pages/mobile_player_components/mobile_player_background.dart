import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../services/player_service.dart';
import '../../services/player_background_service.dart';
import '../../models/track.dart';
import '../../models/song_detail.dart';
import '../../widgets/video_background_player.dart';
import '../../widgets/mesh_gradient_background.dart';

/// 动态背景颜色缓存管理器（移动端）
class _MobileDynamicColorCache {
  static final _MobileDynamicColorCache _instance = _MobileDynamicColorCache._internal();
  factory _MobileDynamicColorCache() => _instance;
  _MobileDynamicColorCache._internal();

  final Map<String, List<Color>> _cache = {};
  String? _currentExtractingUrl;

  List<Color>? getColors(String imageUrl) => _cache[imageUrl];
  
  void setColors(String imageUrl, List<Color> colors) {
    _cache[imageUrl] = colors;
    if (_cache.length > 20) {
      _cache.remove(_cache.keys.first);
    }
  }

  bool isExtracting(String imageUrl) => _currentExtractingUrl == imageUrl;
  void setExtracting(String? imageUrl) => _currentExtractingUrl = imageUrl;
}

/// 移动端播放器背景组件
/// 根据设置显示不同类型的背景（自适应、纯色、图片、视频、动态）
/// 动态模式下使用 Apple Music 风格的 Mesh Gradient 背景
class MobilePlayerBackground extends StatefulWidget {
  const MobilePlayerBackground({super.key});

  @override
  State<MobilePlayerBackground> createState() => _MobilePlayerBackgroundState();
}

class _MobilePlayerBackgroundState extends State<MobilePlayerBackground> {
  // 动态背景颜色
  List<Color> _dynamicColors = [Colors.grey[900]!, Colors.grey[800]!, Colors.grey[700]!];
  String? _currentImageUrl;
  bool _isFirstBuild = true;
  int _pendingExtractionId = 0;
  String? _lastScheduledImageUrl;

  @override
  void initState() {
    super.initState();
    PlayerBackgroundService().addListener(_onBackgroundChanged);
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
    if (backgroundService.backgroundType != PlayerBackgroundType.dynamic) return;

    final song = PlayerService().currentSong;
    final track = PlayerService().currentTrack;
    final imageUrl = song?.pic ?? track?.picUrl ?? '';

    if (imageUrl.isEmpty || imageUrl == _currentImageUrl) return;
    if (imageUrl == _lastScheduledImageUrl) return;

    _lastScheduledImageUrl = imageUrl;

    final cachedColors = _MobileDynamicColorCache().getColors(imageUrl);
    if (cachedColors != null) {
      _currentImageUrl = imageUrl;
      if (mounted) {
        setState(() => _dynamicColors = cachedColors);
      }
      return;
    }

    _pendingExtractionId++;
    final currentId = _pendingExtractionId;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (currentId != _pendingExtractionId || !mounted) return;
      _extractColorsFromImage(imageUrl);
    });
  }

  /// 从图片中提取颜色
  Future<void> _extractColorsFromImage(String imageUrl) async {
    if (_MobileDynamicColorCache().isExtracting(imageUrl)) return;
    
    final cachedColors = _MobileDynamicColorCache().getColors(imageUrl);
    if (cachedColors != null) {
      _currentImageUrl = imageUrl;
      if (mounted) setState(() => _dynamicColors = cachedColors);
      return;
    }
    
    _MobileDynamicColorCache().setExtracting(imageUrl);
    _currentImageUrl = imageUrl;

    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(32, 32),
        maximumColorCount: 6,
        timeout: const Duration(seconds: 1),
      );

      final colors = _extractColors(
        vibrantColor: paletteGenerator.vibrantColor?.color,
        mutedColor: paletteGenerator.mutedColor?.color,
        dominantColor: paletteGenerator.dominantColor?.color,
        lightVibrantColor: paletteGenerator.lightVibrantColor?.color,
        darkVibrantColor: paletteGenerator.darkVibrantColor?.color,
      );

      _MobileDynamicColorCache().setColors(imageUrl, colors);

      if (mounted && _currentImageUrl == imageUrl) {
        setState(() => _dynamicColors = colors);
      }
    } catch (e) {
      // 静默失败
    } finally {
      _MobileDynamicColorCache().setExtracting(null);
    }
  }

  /// 提取颜色
  List<Color> _extractColors({
    Color? vibrantColor,
    Color? mutedColor,
    Color? dominantColor,
    Color? lightVibrantColor,
    Color? darkVibrantColor,
  }) {
    final colors = <Color>[];
    
    if (vibrantColor != null) colors.add(vibrantColor);
    if (mutedColor != null) colors.add(mutedColor);
    if (dominantColor != null) colors.add(dominantColor);
    if (lightVibrantColor != null) colors.add(lightVibrantColor);
    if (darkVibrantColor != null) colors.add(darkVibrantColor);
    
    while (colors.length < 3) {
      colors.add(Colors.grey[800]!);
    }
    
    return colors.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstBuild) {
      _isFirstBuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleColorExtraction();
      });
    }
    return _buildBackground();
  }

  /// 构建背景
  Widget _buildBackground() {
    final backgroundService = PlayerBackgroundService();
    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;
    
    switch (backgroundService.backgroundType) {
      case PlayerBackgroundType.adaptive:
        // 自适应背景 - 检查是否启用封面渐变效果
        if (backgroundService.enableGradient) {
          return _buildCoverGradientBackground(song, track);
        } else {
          return _buildColorGradientBackground();
        }
        
      case PlayerBackgroundType.dynamic:
        // 动态背景 - Apple Music 风格的 Mesh Gradient
        return _buildDynamicMeshBackground(song, track);
        
      case PlayerBackgroundType.solidColor:
        // 纯色背景
        return _buildSolidColorBackground(backgroundService);
        
      case PlayerBackgroundType.image:
        // 图片背景
        return _buildImageBackground(backgroundService);
        
      case PlayerBackgroundType.video:
        // 视频背景
        return _buildVideoBackground(backgroundService);
    }
  }

  /// 构建动态 Mesh Gradient 背景（Apple Music 风格）
  Widget _buildDynamicMeshBackground(SongDetail? song, Track? track) {
    final greyColor = Colors.grey[900] ?? const Color(0xFF212121);
    
    return RepaintBoundary(
      child: MeshGradientBackground(
        colors: _dynamicColors,
        speed: 0.3,
        backgroundColor: _dynamicColors.isNotEmpty ? _dynamicColors[0] : greyColor,
        animate: true,
      ),
    );
  }

  /// 构建封面渐变背景（新样式：移动端顶部封面，向下渐变）
  Widget _buildCoverGradientBackground(SongDetail? song, Track? track) {
    final imageUrl = song?.pic ?? track?.picUrl ?? '';
    
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        // 确保总是有颜色显示，优先使用提取的主题色，回退到深紫色
        final color = themeColor ?? Colors.grey[700]!;
        
         return Stack(
           children: [
             // 底层纯主题色背景
             Positioned.fill(
               child: AnimatedContainer(
                 duration: const Duration(milliseconds: 500),
                 color: color,  // 整个背景使用主题色
               ),
             ),
             
             // 专辑封面层 - 等比例放大至占满宽度，位于顶部，带渐变融合效果
             if (imageUrl.isNotEmpty)
               Positioned(
                 left: 0,
                 right: 0,
                 top: 0,
                 child: AspectRatio(
                   aspectRatio: 1.0, // 保持正方形比例
                   child: Stack(
                     children: [
                       // 封面图片
                       CachedNetworkImage(
                         imageUrl: imageUrl,
                         fit: BoxFit.cover,
                         placeholder: (context, url) => Container(
                           color: Colors.grey[900],
                         ),
                         errorWidget: (context, url, error) => Container(
                           color: Colors.grey[900],
                         ),
                       ),
                       // 封面底部渐变遮罩 - 提前开始渐变，避免突兀过渡
                       Positioned.fill(
                         child: AnimatedContainer(
                           duration: const Duration(milliseconds: 500),
                           decoration: BoxDecoration(
                             gradient: LinearGradient(
                               begin: Alignment.topCenter,
                               end: Alignment.bottomCenter,
                               colors: [
                                 Colors.transparent,           // 顶部完全透明，显示原封面
                                 Colors.transparent,           // 上1/4保持透明
                                 color.withOpacity(0.05),     // 提前开始轻微融合
                                 color.withOpacity(0.12),     // 渐进增加透明度
                                 color.withOpacity(0.25),     // 四分之一透明度
                                 color.withOpacity(0.45),     // 接近一半透明度
                                 color.withOpacity(0.65),     // 较强融合
                                 color.withOpacity(0.85),     // 非常强的融合
                                 color,                       // 最底部完全融入主题色
                               ],
                               stops: const [0.0, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.90, 1.0],
                             ),
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
           ],
         );
      },
    );
  }

  /// 构建颜色渐变背景（原有样式）
  Widget _buildColorGradientBackground() {
    return ValueListenableBuilder<Color?>(
      valueListenable: PlayerService().themeColorNotifier,
      builder: (context, themeColor, child) {
        // 使用提取的主题色，回退到深紫色
        final color = themeColor ?? Colors.grey[700]!;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.3),
                Colors.black,
                Colors.black,
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建纯色背景
  Widget _buildSolidColorBackground(PlayerBackgroundService backgroundService) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            backgroundService.solidColor,
            Colors.grey[900]!,
            Colors.black,
          ],
        ),
      ),
    );
  }

  /// 构建图片背景
  Widget _buildImageBackground(PlayerBackgroundService backgroundService) {
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!,
            Colors.black,
            Colors.black,
          ],
        ),
      ),
    );
  }
  
  /// 构建视频背景
  Widget _buildVideoBackground(PlayerBackgroundService backgroundService) {
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!,
            Colors.black,
            Colors.black,
          ],
        ),
      ),
    );
  }
}
