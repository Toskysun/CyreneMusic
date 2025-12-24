import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/player_service.dart';
import '../../services/playlist_service.dart';
import '../../services/download_service.dart';
import '../../services/music_service.dart';
import '../../models/lyric_line.dart';
import '../../models/track.dart';
import '../player_components/player_fluid_cloud_lyrics_panel.dart';
import 'mobile_player_dialogs.dart';
import 'mobile_player_settings_sheet.dart';

/// 移动端流体云播放器布局
/// 参考 HTML 设计：统一在同一页面显示歌曲信息、歌词、控制按钮
/// 歌词样式参考桌面端流体云歌词，显示3行
class MobilePlayerFluidCloudLayout extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final bool showTranslation;
  final VoidCallback onBackPressed;
  final VoidCallback? onPlaylistPressed;
  final VoidCallback? onTranslationToggle;

  const MobilePlayerFluidCloudLayout({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.showTranslation,
    required this.onBackPressed,
    this.onPlaylistPressed,
    this.onTranslationToggle,
  });

  @override
  State<MobilePlayerFluidCloudLayout> createState() => _MobilePlayerFluidCloudLayoutState();
}

class _MobilePlayerFluidCloudLayoutState extends State<MobilePlayerFluidCloudLayout> {
  @override
  Widget build(BuildContext context) {
    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;
    final imageUrl = song?.pic ?? track?.picUrl ?? '';

    // 不再创建自己的背景，背景由 MobilePlayerBackground 统一处理
    // 这里只负责内容布局
    return Column(
      children: [
        // 顶部歌曲信息区域
        _buildSongInfoSection(context, song, track, imageUrl),

        // 中间歌词区域（3行歌词）
        Expanded(
          child: _buildLyricsSection(),
        ),

        // 底部进度条和控制按钮（上移）
        Transform.translate(
          offset: const Offset(0, -24),
          child: _buildControlsSection(player),
        ),
        
        // 底部导航按钮
        _buildBottomNavigation(context, track),
        
        const SizedBox(height: 8),
      ],
    );
  }

  /// 构建歌曲信息区域（参考 HTML section#song-info）
  Widget _buildSongInfoSection(BuildContext context, dynamic song, dynamic track, String imageUrl) {
    final name = song?.name ?? track?.name ?? '未知歌曲';
    final artists = song?.arName ?? track?.artists ?? '未知艺术家';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          // 专辑封面（小尺寸）
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? _buildCoverImage(imageUrl)
                : Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
          ),
          const SizedBox(width: 12),

          // 歌曲标题和歌手
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Microsoft YaHei',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  artists,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontFamily: 'Microsoft YaHei',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 右侧操作按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 收藏按钮
              if (track != null)
                _FavoriteButton(track: track),
              // 更多选项 - 弹出设置侧边栏
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: Colors.white.withOpacity(0.8),
                ),
                onPressed: () {
                  MobilePlayerSettingsSheet.show(context, currentTrack: track);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建歌词区域 - 复用桌面端流体云歌词组件，通过遮罩限制只显示3行
  Widget _buildLyricsSection() {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        // 上下渐变遮罩，只显示中间约3行歌词的区域
        // 扩大上方不透明区域50%：从 0.25-0.35 调整为 0.125-0.225
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.black,
            Colors.transparent,
            Colors.transparent,
          ],
          stops: const [
            0.0,    // 顶部完全透明
            0.25,  // 更早开始可见（原来是0.35）
            0.5,    // 中心
            0.65,   // 完全可见
            0.75,   // 开始渐变
            1.0,    // 底部完全透明
          ],
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

  /// 构建控制区域（进度条 + 播放按钮）
  Widget _buildControlsSection(PlayerService player) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        children: [
          // 进度条
          AnimatedBuilder(
            animation: player,
            builder: (context, _) {
              final position = player.position.inMilliseconds.toDouble();
              final duration = player.duration.inMilliseconds.toDouble();
              final value = (duration > 0) ? (position / duration).clamp(0.0, 1.0) : 0.0;

              return Column(
                children: [
                  // 进度条 - 与桌面端流体云样式一致：无滑块，圆角轨道
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
                  // 时间显示
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(player.position),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontFamily: 'Consolas',
                          ),
                        ),
                        Text(
                          _formatDuration(player.duration),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // 播放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一首
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white.withOpacity(0.8),
                iconSize: 36,
                onPressed: player.hasPrevious ? player.playPrevious : null,
              ),
              const SizedBox(width: 24),

              // 播放/暂停（大按钮）
              AnimatedBuilder(
                animation: player,
                builder: (context, _) {
                  return IconButton(
                    icon: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    iconSize: 48,
                    onPressed: player.togglePlayPause,
                  );
                },
              ),
              const SizedBox(width: 24),

              // 下一首
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white.withOpacity(0.8),
                iconSize: 36,
                onPressed: player.hasNext ? player.playNext : null,
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// 构建底部导航（参考 HTML footer#bottom-nav）
  Widget _buildBottomNavigation(BuildContext context, Track? track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：下载按钮
          if (track != null)
            _DownloadButton(track: track)
          else
            const SizedBox(width: 48),

          // 中间区域：译文按钮 + 返回按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 译文按钮（如果有译文）
              if (_shouldShowTranslationButton())
                _buildTranslationButton(),
              
              // 返回按钮
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                color: Colors.white.withOpacity(0.8),
                iconSize: 32,
                onPressed: widget.onBackPressed,
              ),
            ],
          ),

          // 右侧：播放列表按钮
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            color: Colors.white.withOpacity(0.8),
            iconSize: 28,
            onPressed: widget.onPlaylistPressed,
          ),
        ],
      ),
    );
  }

  /// 构建译文切换按钮
  Widget _buildTranslationButton() {
    return GestureDetector(
      onTap: widget.onTranslationToggle,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: widget.showTranslation
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text(
            '译',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Microsoft YaHei',
            ),
          ),
        ),
      ),
    );
  }

  /// 判断是否应该显示译文按钮
  bool _shouldShowTranslationButton() {
    if (widget.lyrics.isEmpty) return false;

    final hasTranslation = widget.lyrics.any((lyric) =>
        lyric.translation != null && lyric.translation!.isNotEmpty);

    if (!hasTranslation) return false;

    final sampleLyrics = widget.lyrics
        .where((lyric) => lyric.text.trim().isNotEmpty)
        .take(5)
        .map((lyric) => lyric.text)
        .join('');

    if (sampleLyrics.isEmpty) return false;

    final chineseCount = sampleLyrics.runes.where((rune) {
      return (rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0x3400 && rune <= 0x4DBF) ||
          (rune >= 0x20000 && rune <= 0x2A6DF);
    }).length;

    final totalCount = sampleLyrics.runes.length;
    final chineseRatio = totalCount > 0 ? chineseCount / totalCount : 0;

    return chineseRatio < 0.3;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 构建封面图片（支持网络 URL 和本地文件路径）
  Widget _buildCoverImage(String imageUrl) {
    // 判断是网络 URL 还是本地文件路径
    final isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[900]),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[900],
          child: const Icon(Icons.music_note, color: Colors.white54),
        ),
      );
    } else {
      // 本地文件
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[900],
          child: const Icon(Icons.music_note, color: Colors.white54),
        ),
      );
    }
  }
}

/// 收藏按钮组件
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
    if (oldWidget.track.id != widget.track.id ||
        oldWidget.track.source != widget.track.source) {
      _checkIfInPlaylist();
    }
  }

  Future<void> _checkIfInPlaylist() async {
    setState(() => _isLoading = true);

    final playlistService = PlaylistService();
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
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10.0),
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
        color: _isInPlaylist ? Colors.redAccent : Colors.white.withOpacity(0.8),
      ),
      onPressed: () {
        MobilePlayerDialogs.showAddToPlaylist(context, widget.track);
      },
      tooltip: tooltip,
    );
  }
}

/// 下载按钮组件
class _DownloadButton extends StatefulWidget {
  final Track track;

  const _DownloadButton({required this.track});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _isLoading = true;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
    DownloadService().addListener(_onDownloadChanged);
  }

  @override
  void dispose() {
    DownloadService().removeListener(_onDownloadChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(_DownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id ||
        oldWidget.track.source != widget.track.source) {
      _checkDownloadStatus();
    }
  }

  void _onDownloadChanged() {
    if (!mounted) return;
    
    final downloadService = DownloadService();
    final trackId = '${widget.track.source.name}_${widget.track.id}';
    final tasks = downloadService.downloadTasks;
    final task = tasks[trackId];
    
    if (task != null) {
      setState(() {
        _isDownloading = !task.isCompleted && !task.isFailed;
        _progress = task.progress;
        if (task.isCompleted) {
          _isDownloaded = true;
          _isDownloading = false;
        }
      });
    }
  }

  Future<void> _checkDownloadStatus() async {
    setState(() => _isLoading = true);
    
    final isDownloaded = await DownloadService().isDownloaded(widget.track);
    
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
        _isLoading = false;
      });
    }
  }

  Future<void> _startDownload() async {
    if (_isDownloading || _isDownloaded) return;
    
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });
    
    try {
      // 获取歌曲详情
      final songDetail = PlayerService().currentSong;
      if (songDetail == null) {
        // 如果当前没有歌曲详情，尝试获取
        final detail = await MusicService().fetchSongDetail(
          songId: widget.track.id.toString(),
          source: widget.track.source,
        );
        
        if (detail == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('获取歌曲信息失败')),
            );
            setState(() => _isDownloading = false);
          }
          return;
        }
        
        final success = await DownloadService().downloadSong(
          widget.track,
          detail,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
        );
        
        if (mounted) {
          if (success) {
            setState(() {
              _isDownloaded = true;
              _isDownloading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${widget.track.name} 下载完成')),
            );
          } else {
            setState(() => _isDownloading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('下载失败')),
            );
          }
        }
      } else {
        final success = await DownloadService().downloadSong(
          widget.track,
          songDetail,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
        );
        
        if (mounted) {
          if (success) {
            setState(() {
              _isDownloaded = true;
              _isDownloading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${widget.track.name} 下载完成')),
            );
          } else {
            setState(() => _isDownloading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('下载失败或文件已存在')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }

    if (_isDownloading) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: _progress,
              strokeWidth: 2,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return IconButton(
      icon: Icon(
        _isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
        color: _isDownloaded ? Colors.green : Colors.white.withOpacity(0.8),
      ),
      onPressed: _isDownloaded ? null : _startDownload,
      tooltip: _isDownloaded ? '已下载' : '下载',
    );
  }
}
