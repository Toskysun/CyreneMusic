import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../../services/player_service.dart';
import '../../services/playlist_service.dart';
import '../../services/netease_artist_service.dart';
import '../../utils/theme_manager.dart';
import '../../models/lyric_line.dart';
import '../../models/track.dart';
import '../../models/song_detail.dart';
import '../../widgets/search_widget.dart';
import '../artist_detail_page.dart';
import 'player_fluid_cloud_background.dart';
import 'player_window_controls.dart';
import 'player_fluid_cloud_lyrics_panel.dart';
import 'player_dialogs.dart';

/// 流体云全屏布局
/// 模仿 Apple Music 的左右分栏设计
/// 左侧：封面、信息、控制
/// 右侧：沉浸式歌词
class PlayerFluidCloudLayout extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;
  final bool isMaximized;
  final VoidCallback onBackPressed;
  final VoidCallback onPlaylistPressed;
  final VoidCallback onVolumeControlPressed;
  final VoidCallback? onSleepTimerPressed;
  final VoidCallback? onTranslationToggle;

  const PlayerFluidCloudLayout({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.showTranslation,
    required this.isMaximized,
    required this.onBackPressed,
    required this.onPlaylistPressed,
    required this.onVolumeControlPressed,
    this.onSleepTimerPressed,
    this.onTranslationToggle,
  });

  @override
  State<PlayerFluidCloudLayout> createState() => _PlayerFluidCloudLayoutState();
}

class _PlayerFluidCloudLayoutState extends State<PlayerFluidCloudLayout> {
  // 缓存当前歌曲的封面 URL，用于检测歌曲变化
  String? _currentImageUrl;
  
  @override
  void initState() {
    super.initState();
    PlayerService().addListener(_onPlayerChanged);
    _updateCurrentImageUrl();
  }
  
  @override
  void dispose() {
    PlayerService().removeListener(_onPlayerChanged);
    super.dispose();
  }
  
  void _onPlayerChanged() {
    // 检查封面 URL 是否变化
    final player = PlayerService();
    final newImageUrl = player.currentSong?.pic ?? player.currentTrack?.picUrl ?? '';
    
    if (_currentImageUrl != newImageUrl) {
      setState(() {
        _currentImageUrl = newImageUrl;
      });
    }
  }
  
  void _updateCurrentImageUrl() {
    final player = PlayerService();
    _currentImageUrl = player.currentSong?.pic ?? player.currentTrack?.picUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 全局背景（流体云专用背景：自适应模式下始终显示专辑封面 100% 填充）
        const PlayerFluidCloudBackground(),
        
        // 2. 玻璃拟态遮罩 (整个容器)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.black.withOpacity(0.2), // 降低亮度以突出内容
            ),
          ),
        ),

        // 3. 主要内容区域
        SafeArea(
          child: Column(
            children: [
              // 顶部窗口控制
              Builder(
                builder: (context) {
                  final player = PlayerService();
                  return PlayerWindowControls(
                    isMaximized: widget.isMaximized,
                    onBackPressed: widget.onBackPressed,
                    onPlaylistPressed: widget.onPlaylistPressed,
                    onSleepTimerPressed: widget.onSleepTimerPressed,
                    // 译文按钮相关
                    showTranslationButton: _shouldShowTranslationButton(),
                    showTranslation: widget.showTranslation,
                    onTranslationToggle: widget.onTranslationToggle,
                    // 下载按钮相关
                    currentTrack: player.currentTrack,
                    currentSong: player.currentSong,
                  );
                },
              ),
              
              // 主体布局 (左右分栏) - 参考 Vue 项目 42%/58% 比例
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 60, right: 40, top: 20, bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左侧：控制面板 (42% 宽度) - 使用 AnimatedBuilder 监听 PlayerService 变化
                      Expanded(
                        flex: 42,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 60),
                          child: AnimatedBuilder(
                            animation: PlayerService(),
                            builder: (context, _) => _buildLeftPanel(context),
                          ),
                        ),
                      ),
                      
                      // 右侧：歌词面板 (58% 宽度)
                      Expanded(
                        flex: 58,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: _buildRightPanel(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建左侧面板
  Widget _buildLeftPanel(BuildContext context) {
    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;
    final imageUrl = song?.pic ?? track?.picUrl ?? '';

    // 缩放到 90%
    return Transform.scale(
      scale: 0.9,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center, // 居中对齐
        children: [
          // 1. 专辑封面
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      key: ValueKey(imageUrl), // 使用 imageUrl 作为 key，确保 URL 变化时重建
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                    ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // 2. 歌曲信息（歌曲名 + 收藏按钮）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  track?.name ?? '未知歌曲',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    fontFamily: 'Microsoft YaHei',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (track != null) ...[
                const SizedBox(width: 8),
                _FavoriteButton(track: track),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // 歌手名（可点击）
          _buildArtistsRow(context, track?.artists ?? '未知歌手', player.currentSong),
          
          const SizedBox(height: 30),
          
          // 3. 进度条
          AnimatedBuilder(
            animation: player,
            builder: (context, _) {
              final position = player.position.inMilliseconds.toDouble();
              final duration = player.duration.inMilliseconds.toDouble();
              final value = (duration > 0) ? (position / duration).clamp(0.0, 1.0) : 0.0;
              
              return Column(
                children: [
                  // 自定义半透明进度条
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: SliderComponentShape.noThumb,
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: Colors.white.withOpacity(0.9),
                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      value: value,
                      onChanged: (v) {
                        final pos = Duration(milliseconds: (v * duration).round());
                        player.seek(pos);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(player.position),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5), 
                            fontSize: 12,
                            fontFamily: 'Consolas',
                          ),
                        ),
                        Text(
                          _formatDuration(player.duration),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5), 
                            fontSize: 12,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
          
          const SizedBox(height: 16),
          
          // 4. 控制按钮 (居中，作为一个整体) - 只保留上一首、播放/暂停、下一首
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 上一首
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  color: Colors.white,
                  iconSize: 36,
                  onPressed: player.hasPrevious ? player.playPrevious : null,
                ),
                const SizedBox(width: 20),
                
                // 播放/暂停
                AnimatedBuilder(
                  animation: player,
                  builder: (context, _) {
                    return IconButton(
                      icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      color: Colors.white,
                      iconSize: 48, 
                      onPressed: player.togglePlayPause,
                    );
                  }
                ),
                const SizedBox(width: 20),
                
                // 下一首
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  color: Colors.white,
                  iconSize: 36,
                  onPressed: player.hasNext ? player.playNext : null,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 5. 音量控制 (与进度条样式一致)
          _buildVolumeSlider(player),
          
        ],
      ),
    );
  }
  
  /// 构建音量滑条 (与进度条样式一致)
  Widget _buildVolumeSlider(PlayerService player) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        return Row(
          children: [
            // 静音图标
            Icon(
              Icons.volume_off_rounded,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
            const SizedBox(width: 8),
            
            // 音量滑条 - 与进度条样式一致
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  // 无滑块，与进度条一致
                  thumbShape: SliderComponentShape.noThumb,
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.white.withOpacity(0.9),
                  inactiveTrackColor: Colors.white.withOpacity(0.2),
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  value: player.volume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (v) {
                    player.setVolume(v);
                  },
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            // 最大音量图标
            Icon(
              Icons.volume_up_rounded,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        );
      },
    );
  }

  /// 构建右侧面板 (歌词)
  Widget _buildRightPanel() {
    // 使用 ShaderMask 实现上下淡入淡出
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.15, 0.85, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: PlayerFluidCloudLyricsPanel(
        lyrics: widget.lyrics,
        currentLyricIndex: widget.currentLyricIndex,
        showTranslation: widget.showTranslation,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 判断是否应该显示译文按钮
  /// 只有当歌词非中文且存在翻译时才显示
  bool _shouldShowTranslationButton() {
    if (widget.lyrics.isEmpty) return false;
    
    // 检查是否有翻译
    final hasTranslation = widget.lyrics.any((lyric) => 
      lyric.translation != null && lyric.translation!.isNotEmpty
    );
    
    if (!hasTranslation) return false;
    
    // 检查原文是否为中文（检查前几行非空歌词）
    final sampleLyrics = widget.lyrics
        .where((lyric) => lyric.text.trim().isNotEmpty)
        .take(5)
        .map((lyric) => lyric.text)
        .join('');
    
    if (sampleLyrics.isEmpty) return false;
    
    // 判断是否主要为中文（中文字符占比）
    final chineseCount = sampleLyrics.runes.where((rune) {
      return (rune >= 0x4E00 && rune <= 0x9FFF) || // 基本汉字
             (rune >= 0x3400 && rune <= 0x4DBF) || // 扩展A
             (rune >= 0x20000 && rune <= 0x2A6DF); // 扩展B
    }).length;
    
    final totalCount = sampleLyrics.runes.length;
    final chineseRatio = totalCount > 0 ? chineseCount / totalCount : 0;
    
    // 如果中文字符占比小于30%，认为是非中文歌词
    return chineseRatio < 0.3;
  }

  /// 构建歌手行（支持多歌手点击）
  Widget _buildArtistsRow(BuildContext context, String artistsStr, SongDetail? song) {
    final artists = _splitArtists(artistsStr);
    
    return Wrap(
      alignment: WrapAlignment.center,
      children: artists.asMap().entries.map((entry) {
        final index = entry.key;
        final artist = entry.value;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _onArtistTap(context, artist, song),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  artist,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.6),
                    fontFamily: 'Microsoft YaHei',
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            if (index < artists.length - 1)
              Text(
                ' / ',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.6),
                  fontFamily: 'Microsoft YaHei',
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  /// 分割歌手字符串（支持多种分隔符）
  List<String> _splitArtists(String artistsStr) {
    final separators = ['/', ',', '、'];
    
    for (final separator in separators) {
      if (artistsStr.contains(separator)) {
        return artistsStr
            .split(separator)
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList();
      }
    }
    
    return [artistsStr];
  }

  /// 歌手点击处理
  Future<void> _onArtistTap(BuildContext context, String artistName, SongDetail? song) async {
    // 仅在网易云音乐来源时跳转歌手详情，否则沿用搜索
    if (song?.source != MusicSource.netease) {
      _searchInDialog(context, artistName);
      return;
    }
    // 解析歌手ID（后端无返回ID时，通过搜索解析）
    final id = await NeteaseArtistDetailService().resolveArtistIdByName(artistName);
    if (id == null) {
      _searchInDialog(context, artistName);
      return;
    }
    if (!context.mounted) return;
    
    final isFluent = ThemeManager().isFluentFramework;
    
    if (isFluent) {
      // Fluent UI 样式对话框
      final fluentTheme = fluent.FluentTheme.of(context);
      final backgroundColor = fluentTheme.micaBackgroundColor ?? 
          fluentTheme.scaffoldBackgroundColor;
      
      fluent.showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        builder: (context) => fluent.ContentDialog(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          style: fluent.ContentDialogThemeData(
            padding: EdgeInsets.zero,
            bodyPadding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: fluentTheme.resources.surfaceStrokeColorDefault,
                width: 1,
              ),
            ),
          ),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 800,
              height: 700,
              child: ArtistDetailContent(artistId: id),
            ),
          ),
        ),
      );
    } else {
      // Material 样式对话框
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: ArtistDetailContent(artistId: id),
            ),
          ),
        ),
      );
    }
  }

  /// 在对话框中打开搜索
  void _searchInDialog(BuildContext context, String keyword) {
    final isFluent = ThemeManager().isFluentFramework;
    
    if (isFluent) {
      // Fluent UI 样式对话框
      final fluentTheme = fluent.FluentTheme.of(context);
      final backgroundColor = fluentTheme.micaBackgroundColor ?? 
          fluentTheme.scaffoldBackgroundColor;
      
      fluent.showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        builder: (context) => fluent.ContentDialog(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          style: fluent.ContentDialogThemeData(
            padding: EdgeInsets.zero,
            bodyPadding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: fluentTheme.resources.surfaceStrokeColorDefault,
                width: 1,
              ),
            ),
          ),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 800,
              height: 700,
              child: SearchWidget(
                onClose: () => Navigator.pop(context),
                initialKeyword: keyword,
              ),
            ),
          ),
        ),
      );
    } else {
      // Material 样式对话框
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 800,
              maxHeight: 700,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SearchWidget(
                onClose: () => Navigator.pop(context),
                initialKeyword: keyword,
              ),
            ),
          ),
        ),
      );
    }
  }
}

/// 收藏按钮组件
/// 检测歌曲是否在用户歌单中，显示实心或空心爱心
class _FavoriteButton extends StatefulWidget {
  final Track track;

  const _FavoriteButton({required this.track});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _isInPlaylist = false;
  bool _isLoading = true;
  List<String> _playlistNames = [];

  @override
  void initState() {
    super.initState();
    _checkIfInPlaylist();
  }

  @override
  void didUpdateWidget(_FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当歌曲变化时重新检查
    if (oldWidget.track.id != widget.track.id || 
        oldWidget.track.source != widget.track.source) {
      _checkIfInPlaylist();
    }
  }

  Future<void> _checkIfInPlaylist() async {
    setState(() => _isLoading = true);
    
    final playlistService = PlaylistService();
    
    // 调用后端 API 检查歌曲是否在任何歌单中
    final result = await playlistService.isTrackInAnyPlaylist(widget.track);
    
    if (mounted) {
      setState(() {
        _isInPlaylist = result.inPlaylist;
        _playlistNames = result.playlistNames;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }

    final tooltip = _isInPlaylist 
        ? '已收藏到: ${_playlistNames.join(", ")}' 
        : '添加到歌单';

    return IconButton(
      icon: Icon(
        _isInPlaylist ? Icons.favorite : Icons.favorite_border,
        color: _isInPlaylist ? Colors.redAccent : Colors.white.withOpacity(0.7),
        size: 26,
      ),
      onPressed: () {
        PlayerDialogs.showAddToPlaylist(context, widget.track);
      },
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
    );
  }
}

