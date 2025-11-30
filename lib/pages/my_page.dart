import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../utils/theme_manager.dart';
import '../services/auth_service.dart';
import '../services/playlist_service.dart';
import '../services/listening_stats_service.dart';
import '../services/player_service.dart';
import '../services/playlist_queue_service.dart';
import '../services/track_source_switch_service.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../widgets/import_playlist_dialog.dart';
import '../widgets/source_switch_dialog.dart';
import 'auth/auth_page.dart';

/// 我的页面 - 包含歌单和听歌统计
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final PlaylistService _playlistService = PlaylistService();
  final ThemeManager _themeManager = ThemeManager();
  ListeningStatsData? _statsData;
  bool _isLoadingStats = true;
  Playlist? _selectedPlaylist; // 当前选中的歌单
  bool _isEditMode = false; // 是否处于编辑模式
  final Set<String> _selectedTrackIds = {}; // 选中的歌曲ID集合
  
  // 搜索相关状态
  bool _isSearchMode = false; // 是否处于搜索模式
  String _searchQuery = ''; // 搜索关键词
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _playlistService.addListener(_onPlaylistsChanged);
    
    if (AuthService().isLoggedIn) {
      _playlistService.loadPlaylists();
      _loadStats();
    }
  }

  @override
  void dispose() {
    _playlistService.removeListener(_onPlaylistsChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onPlaylistsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      await ListeningStatsService().syncNow();
      final stats = await ListeningStatsService().fetchStats();
      setState(() {
        _statsData = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  void _showUserNotification(
    String message, {
    fluent.InfoBarSeverity severity = fluent.InfoBarSeverity.info,
    Duration duration = const Duration(seconds: 2),
    Color? materialBackground,
  }) {
    if (!mounted) return;
    if (_themeManager.isFluentFramework) {
      fluent.displayInfoBar(
        context,
        builder: (context, close) => fluent.InfoBar(
          title: const Text('提示'),
          content: Text(message),
          severity: severity,
          action: fluent.IconButton(
            icon: const Icon(fluent.FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          backgroundColor: materialBackground,
        ),
      );
    }
  }

  bool _hasImportConfig(Playlist playlist) {
    return (playlist.source?.isNotEmpty ?? false) &&
        (playlist.sourcePlaylistId?.isNotEmpty ?? false);
  }

  String _formatSyncResultMessage(PlaylistSyncResult result) {
    if (result.insertedCount <= 0) {
      return '同步完成，暂无新增歌曲';
    }
    final preview = result.newTracks
        .map((t) => t.name)
        .where((name) => name.isNotEmpty)
        .take(3)
        .toList();
    final suffix = result.insertedCount > preview.length ? '…' : '';
    final details = preview.isEmpty ? '' : '：${preview.join('、')}$suffix';
    return '同步完成，新增 ${result.insertedCount} 首$details';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoggedIn = AuthService().isLoggedIn;

    // Fluent 框架下的渲染
    if (_themeManager.isFluentFramework) {
      return _buildFluentPage(context, isLoggedIn);
    }

    // 如果未登录，显示登录提示
    if (!isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '登录后查看更多',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '登录即可管理歌单和查看听歌统计',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                showAuthDialog(context).then((_) {
                  if (mounted) setState(() {});
                });
              },
              icon: const Icon(Icons.login),
              label: const Text('立即登录'),
            ),
          ],
        ),
      );
    }

    // 如果选中了歌单，显示歌单详情
    if (_selectedPlaylist != null) {
      return _buildPlaylistDetail(_selectedPlaylist!, colorScheme);
    }

    // 已登录，显示完整内容
    return RefreshIndicator(
      onRefresh: () async {
        await _playlistService.loadPlaylists();
        await _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户信息卡片
          _buildUserCard(colorScheme),
          
          const SizedBox(height: 16),
          
          // 听歌统计卡片
          _buildStatsCard(colorScheme),
          
          const SizedBox(height: 24),
          
          // 我的歌单标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '我的歌单',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Microsoft YaHei',
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cloud_download),
                    onPressed: _showImportPlaylistDialog,
                    tooltip: '从网易云导入歌单',
                  ),
                  TextButton.icon(
                    onPressed: _showCreatePlaylistDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('新建'),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 歌单列表
          _buildPlaylistsList(colorScheme),
          
          const SizedBox(height: 24),
          
          // 播放排行榜
          if (_statsData != null && _statsData!.playCounts.isNotEmpty) ...[
            const Text(
              '播放排行榜 Top 10',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Microsoft YaHei',
              ),
            ),
            const SizedBox(height: 8),
            _buildTopPlaysList(colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildFluentPlaylistDetailPage(Playlist playlist) {
    final allTracks = _playlistService.currentPlaylistId == playlist.id
        ? _playlistService.currentTracks
        : <PlaylistTrack>[];
    final isLoading = _playlistService.isLoadingTracks;
    
    // 根据搜索关键词过滤歌曲
    final filteredTracks = _filterTracks(allTracks);

    return fluent.ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题与操作
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                fluent.IconButton(
                  icon: const Icon(fluent.FluentIcons.back),
                  onPressed: _backToList,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditMode
                            ? '已选择 ${_selectedTrackIds.length} 首'
                            : playlist.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!_isEditMode && playlist.isDefault)
                        const Text(
                          '默认歌单',
                          style: TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_isEditMode) ...[
                  fluent.Button(
                    onPressed: allTracks.isNotEmpty ? _toggleSelectAll : null,
                    child: Text(
                      _selectedTrackIds.length == allTracks.length ? '取消全选' : '全选',
                    ),
                  ),
                  const SizedBox(width: 8),
                  fluent.FilledButton(
                    onPressed: _selectedTrackIds.isNotEmpty ? _batchRemoveTracks : null,
                    child: const Text('删除选中'),
                  ),
                  const SizedBox(width: 8),
                  fluent.Button(
                    onPressed: _toggleEditMode,
                    child: const Text('取消'),
                  ),
                ] else ...[
                  // 搜索按钮
                  if (allTracks.isNotEmpty) ...[
                    fluent.IconButton(
                      icon: Icon(_isSearchMode ? fluent.FluentIcons.search_and_apps : fluent.FluentIcons.search),
                      onPressed: _toggleSearchMode,
                    ),
                    const SizedBox(width: 4),
                  ],
                  // 换源按钮
                  if (allTracks.isNotEmpty) ...[
                    fluent.IconButton(
                      icon: const Icon(fluent.FluentIcons.switch_widget),
                      onPressed: () => _showSourceSwitchDialog(playlist, allTracks),
                    ),
                    const SizedBox(width: 4),
                  ],
                  // 编辑按钮
                  if (allTracks.isNotEmpty) ...[
                    fluent.IconButton(
                      icon: const Icon(fluent.FluentIcons.edit),
                      onPressed: _toggleEditMode,
                    ),
                    const SizedBox(width: 4),
                  ],
                  // 同步按钮
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.sync),
                    onPressed: () async {
                      if (!_hasImportConfig(playlist)) {
                        fluent.displayInfoBar(
                          context,
                          builder: (context, close) => fluent.InfoBar(
                            title: const Text('同步'),
                            content: const Text('请先在"导入管理"中绑定来源后再同步'),
                            severity: fluent.InfoBarSeverity.warning,
                            action: fluent.IconButton(
                              icon: const Icon(fluent.FluentIcons.clear),
                              onPressed: close,
                            ),
                          ),
                        );
                        return;
                      }
                      print('🔘 [MyPage] 开始同步(Fluent): playlistId=${playlist.id}');
                      fluent.displayInfoBar(
                        context,
                        builder: (context, close) => fluent.InfoBar(
                          title: const Text('同步'),
                          content: const Text('正在同步...'),
                          severity: fluent.InfoBarSeverity.info,
                          action: fluent.IconButton(
                            icon: const Icon(fluent.FluentIcons.clear),
                            onPressed: close,
                          ),
                        ),
                      );
                      final result = await _playlistService.syncPlaylist(playlist.id);
                      if (!mounted) return;
                      fluent.displayInfoBar(
                        context,
                        builder: (context, close) => fluent.InfoBar(
                          title: const Text('同步完成'),
                          content: Text(_formatSyncResultMessage(result)),
                          severity: fluent.InfoBarSeverity.success,
                          action: fluent.IconButton(
                            icon: const Icon(fluent.FluentIcons.clear),
                            onPressed: close,
                          ),
                        ),
                      );
                      await _playlistService.loadPlaylistTracks(playlist.id);
                    },
                  ),
                ],
              ],
            ),
          ),
          
          // 搜索框（搜索模式时显示）
          if (_isSearchMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: fluent.TextBox(
                controller: _searchController,
                placeholder: '搜索歌曲、歌手、专辑...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(fluent.FluentIcons.search, size: 16),
                ),
                suffix: _searchQuery.isNotEmpty
                    ? fluent.IconButton(
                        icon: const Icon(fluent.FluentIcons.clear, size: 12),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                onChanged: _onSearchChanged,
                autofocus: true,
              ),
            ),

          // 内容
          if (isLoading && allTracks.isEmpty)
            const Expanded(
              child: Center(child: fluent.ProgressRing()),
            )
          else if (allTracks.isEmpty)
            Expanded(child: _buildFluentDetailEmptyState())
          // 搜索无结果
          else if (filteredTracks.isEmpty && _searchQuery.isNotEmpty)
            Expanded(child: _buildFluentSearchEmptyState())
          else ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildFluentDetailStatisticsCard(
                filteredTracks.length,
                totalCount: allTracks.length,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  final track = filteredTracks[index];
                  // 获取原始索引用于播放
                  final originalIndex = allTracks.indexOf(track);
                  return _buildFluentTrackItem(track, originalIndex);
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: filteredTracks.length,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Fluent UI 搜索无结果状态
  Widget _buildFluentSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(fluent.FluentIcons.search, size: 64),
          SizedBox(height: 16),
          Text('未找到匹配的歌曲'),
          SizedBox(height: 8),
          Text('尝试其他关键词', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFluentDetailStatisticsCard(int count, {int? totalCount}) {
    // 如果有搜索过滤，显示 "筛选出 X / 共 Y 首"
    final String countText = (totalCount != null && totalCount != count)
        ? '筛选出 $count / 共 $totalCount 首'
        : '共 $count 首';
    
    return fluent.Card(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(fluent.FluentIcons.music_in_collection, size: 20),
          const SizedBox(width: 12),
          const Text(
            '歌曲',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(countText),
          const Spacer(),
          if (count > 0)
            fluent.FilledButton(
              onPressed: _playAll,
              child: const Text('播放全部'),
            ),
        ],
      ),
    );
  }

  Widget _buildFluentTrackItem(PlaylistTrack item, int index) {
    final theme = fluent.FluentTheme.of(context);
    final trackKey = _getTrackKey(item);
    final isSelected = _selectedTrackIds.contains(trackKey);

    return fluent.Card(
      padding: EdgeInsets.zero,
      child: fluent.ListTile(
        leading: _isEditMode
            ? fluent.Checkbox(
                checked: isSelected,
                onChanged: (_) => _toggleTrackSelection(item),
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: item.picUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: theme.resources.controlAltFillColorSecondary,
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 50,
                        color: theme.resources.controlAltFillColorSecondary,
                        child: Icon(
                          fluent.FluentIcons.music_in_collection,
                          color: theme.resources.textFillColorTertiary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.resources.controlFillColorTertiary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          color: theme.resources.textFillColorSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                '${item.artists} • ${item.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getSourceIcon(item.source),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: _isEditMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.play),
                    onPressed: () => _playDetailTrack(index),
                  ),
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.delete),
                    onPressed: () => _confirmRemoveTrack(item),
                  ),
                ],
              ),
        onPressed: _isEditMode
            ? () => _toggleTrackSelection(item)
            : () => _playDetailTrack(index),
      ),
    );
  }

  Widget _buildFluentDetailEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(fluent.FluentIcons.music_in_collection, size: 64),
          SizedBox(height: 16),
          Text('歌单为空'),
          SizedBox(height: 8),
          Text('快去添加一些喜欢的歌曲吧', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFluentPage(BuildContext context, bool isLoggedIn) {
    // 未登录：提示登录
    if (!isLoggedIn) {
      return fluent.ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(fluent.FluentIcons.contact, size: 80),
              const SizedBox(height: 24),
              const Text('登录后查看更多', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('登录即可管理歌单和查看听歌统计'),
              const SizedBox(height: 24),
              fluent.FilledButton(
                onPressed: () {
                  showAuthDialog(context).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                child: const Text('立即登录'),
              ),
            ],
          ),
        ),
      );
    }

    // 详情视图：Fluent 组件实现
    if (_selectedPlaylist != null) {
      return _buildFluentPlaylistDetailPage(_selectedPlaylist!);
    }

    // 主视图：标题 + 内容（复用原有卡片和列表）
    final brightness = switch (_themeManager.themeMode) {
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
      ThemeMode.dark => Brightness.dark,
      _ => Brightness.light,
    };
    final materialTheme = _themeManager.buildThemeData(brightness);

    return fluent.ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: const [
                Text('我的', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Removed Divider to avoid white line between header and content under acrylic/mica
          Expanded(
            child: Theme(
              data: materialTheme,
              child: Material(
                color: Colors.transparent,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _playlistService.loadPlaylists();
                    await _loadStats();
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildUserCard(materialTheme.colorScheme),
                        const SizedBox(height: 16),
                        // 听歌统计（Fluent 组件版本）
                        if (_isLoadingStats)
                          const fluent.Card(
                            padding: EdgeInsets.all(16),
                            child: Center(child: fluent.ProgressRing()),
                          )
                        else if (_statsData == null)
                          fluent.InfoBar(
                            title: const Text('暂无统计数据'),
                            severity: fluent.InfoBarSeverity.info,
                          )
                        else
                          _buildFluentStatsCard(),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '我的歌单',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Microsoft YaHei',
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                fluent.IconButton(
                                  icon: const Icon(fluent.FluentIcons.cloud_download),
                                  onPressed: _showImportPlaylistDialog,
                                ),
                                const SizedBox(width: 8),
                                fluent.FilledButton(
                                  onPressed: _showCreatePlaylistDialog,
                                  child: const Text('新建'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildFluentPlaylistsList(),
                        const SizedBox(height: 24),
                        if (_statsData != null && _statsData!.playCounts.isNotEmpty) ...[
                          const Text(
                            '播放排行榜 Top 10',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Microsoft YaHei',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildFluentTopPlaysList(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluentStatsCard() {
    final stats = _statsData!;
    return fluent.Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('听歌统计', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFluentStatTile(
                  icon: fluent.FluentIcons.time_picker,
                  label: '累计时长',
                  value: ListeningStatsService.formatDuration(stats.totalListeningTime),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFluentStatTile(
                  icon: fluent.FluentIcons.play,
                  label: '播放次数',
                  value: '${stats.totalPlayCount} 次',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFluentStatTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = fluent.FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.resources.controlAltFillColorSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: theme.resources.textFillColorSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Fluent UI 歌单列表
  Widget _buildFluentPlaylistsList() {
    final playlists = _playlistService.playlists;
    final theme = fluent.FluentTheme.of(context);

    if (playlists.isEmpty) {
      return fluent.Card(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                fluent.FluentIcons.music_in_collection,
                size: 48,
                color: theme.resources.textFillColorTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无歌单',
                style: TextStyle(
                  color: theme.resources.textFillColorSecondary,
                  fontFamily: 'Microsoft YaHei',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: playlists.map((playlist) {
        final canSync = _hasImportConfig(playlist);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: fluent.Card(
            padding: EdgeInsets.zero,
            child: fluent.ListTile(
              leading: _buildFluentPlaylistCover(playlist),
              title: Text(
                playlist.name,
                style: const TextStyle(fontFamily: 'Microsoft YaHei'),
              ),
              subtitle: Text(
                '${playlist.trackCount} 首歌曲',
                style: TextStyle(
                  color: theme.resources.textFillColorSecondary,
                  fontFamily: 'Microsoft YaHei',
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!playlist.isDefault) ...[
                    fluent.IconButton(
                      icon: Icon(
                        fluent.FluentIcons.sync,
                        color: canSync ? theme.accentColor : theme.resources.textFillColorDisabled,
                      ),
                      onPressed: canSync ? () => _syncPlaylistFromList(playlist) : null,
                    ),
                    fluent.IconButton(
                      icon: const Icon(fluent.FluentIcons.delete, color: Colors.redAccent),
                      onPressed: () => _confirmDeletePlaylist(playlist),
                    ),
                  ],
                  const Icon(fluent.FluentIcons.chevron_right),
                ],
              ),
              onPressed: () => _openPlaylistDetail(playlist),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Fluent UI 歌单封面
  Widget _buildFluentPlaylistCover(Playlist playlist) {
    final theme = fluent.FluentTheme.of(context);
    
    if (playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: playlist.coverUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.resources.controlAltFillColorSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              playlist.isDefault ? fluent.FluentIcons.heart_fill : fluent.FluentIcons.music_in_collection,
              color: playlist.isDefault ? Colors.red : theme.accentColor,
              size: 20,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.resources.controlAltFillColorSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              playlist.isDefault ? fluent.FluentIcons.heart_fill : fluent.FluentIcons.music_in_collection,
              color: playlist.isDefault ? Colors.red : theme.accentColor,
              size: 20,
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.resources.controlAltFillColorSecondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        playlist.isDefault ? fluent.FluentIcons.heart_fill : fluent.FluentIcons.music_in_collection,
        color: playlist.isDefault ? Colors.red : theme.accentColor,
        size: 20,
      ),
    );
  }

  /// Fluent UI 播放排行榜
  Widget _buildFluentTopPlaysList() {
    final topPlays = _statsData!.playCounts.take(10).toList();
    final theme = fluent.FluentTheme.of(context);

    return fluent.Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: topPlays.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final rank = index + 1;
          
          Color? rankColor;
          if (rank == 1) {
            rankColor = Colors.amber;
          } else if (rank == 2) {
            rankColor = Colors.grey[400];
          } else if (rank == 3) {
            rankColor = Colors.orange[300];
          }

          return Column(
            children: [
              fluent.ListTile(
                leading: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: item.picUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.resources.controlAltFillColorSecondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            fluent.FluentIcons.music_in_collection,
                            color: theme.resources.textFillColorTertiary,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.resources.controlAltFillColorSecondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            fluent.FluentIcons.music_in_collection,
                            color: theme.resources.textFillColorTertiary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rankColor ?? theme.accentColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Microsoft YaHei',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  item.trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Microsoft YaHei'),
                ),
                subtitle: Text(
                  item.artists,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.resources.textFillColorSecondary,
                    fontFamily: 'Microsoft YaHei',
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      fluent.FluentIcons.play,
                      size: 14,
                      color: theme.resources.textFillColorSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.playCount}',
                      style: TextStyle(
                        color: theme.resources.textFillColorSecondary,
                        fontFamily: 'Microsoft YaHei',
                      ),
                    ),
                  ],
                ),
                onPressed: () => _playTrack(item),
              ),
              if (index < topPlays.length - 1)
                Divider(
                  height: 1,
                  color: theme.resources.dividerStrokeColorDefault,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 构建用户信息卡片
  Widget _buildUserCard(ColorScheme colorScheme) {
    final user = AuthService().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: user.avatarUrl != null
                  ? CachedNetworkImageProvider(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatsCard(ColorScheme colorScheme) {
    if (_isLoadingStats) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_statsData == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '暂无统计数据',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '听歌统计',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.access_time,
                    label: '累计时长',
                    value: ListeningStatsService.formatDuration(
                      _statsData!.totalListeningTime,
                    ),
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.play_circle_outline,
                    label: '播放次数',
                    value: '${_statsData!.totalPlayCount} 次',
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncPlaylistFromList(Playlist playlist) async {
    if (!_hasImportConfig(playlist)) {
      _showUserNotification(
        '请先在“导入管理”中绑定歌单来源后再同步',
        severity: fluent.InfoBarSeverity.warning,
      );
      return;
    }

    _showUserNotification(
      '正在同步...',
      duration: const Duration(seconds: 1),
    );
    final result = await _playlistService.syncPlaylist(playlist.id);
    _showUserNotification(
      _formatSyncResultMessage(result),
      severity: result.insertedCount > 0
          ? fluent.InfoBarSeverity.success
          : fluent.InfoBarSeverity.info,
    );
    if (_selectedPlaylist?.id == playlist.id) {
      await _playlistService.loadPlaylistTracks(playlist.id);
    }
  }

  /// 构建歌单列表
  Widget _buildPlaylistsList(ColorScheme colorScheme) {
    final playlists = _playlistService.playlists;

    if (playlists.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.library_music_outlined,
                  size: 48,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无歌单',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: playlists.map((playlist) {
        final canSync = _hasImportConfig(playlist);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _buildPlaylistCover(playlist, colorScheme),
            title: Text(playlist.name),
            subtitle: Text('${playlist.trackCount} 首歌曲'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 只有非默认歌单才显示删除按钮
                if (!playlist.isDefault) ...[
                  IconButton(
                    icon: const Icon(Icons.sync, size: 20),
                    color: canSync ? colorScheme.primary : null,
                    onPressed: canSync ? () => _syncPlaylistFromList(playlist) : null,
                    tooltip: canSync ? '同步歌单' : '请先设置导入来源',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.redAccent,
                    onPressed: () => _confirmDeletePlaylist(playlist),
                    tooltip: '删除歌单',
                  ),
                ],
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _openPlaylistDetail(playlist),
          ),
        );
      }).toList(),
    );
  }

  /// 构建歌单封面
  Widget _buildPlaylistCover(Playlist playlist, ColorScheme colorScheme) {
    // 如果有封面图片，显示封面
    if (playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: playlist.coverUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: playlist.isDefault
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              playlist.isDefault ? Icons.favorite : Icons.library_music,
              color: playlist.isDefault ? Colors.red : colorScheme.primary,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: playlist.isDefault
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              playlist.isDefault ? Icons.favorite : Icons.library_music,
              color: playlist.isDefault ? Colors.red : colorScheme.primary,
            ),
          ),
        ),
      );
    }
    
    // 没有封面时显示默认图标
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: playlist.isDefault
            ? colorScheme.primaryContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        playlist.isDefault ? Icons.favorite : Icons.library_music,
        color: playlist.isDefault ? Colors.red : colorScheme.primary,
      ),
    );
  }

  /// 构建播放排行榜
  Widget _buildTopPlaysList(ColorScheme colorScheme) {
    final topPlays = _statsData!.playCounts.take(10).toList();

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topPlays.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = topPlays[index];
          return _buildPlayCountItem(item, index + 1, colorScheme);
        },
      ),
    );
  }

  /// 构建播放次数列表项
  Widget _buildPlayCountItem(
    PlayCountItem item,
    int rank,
    ColorScheme colorScheme,
  ) {
    Color? rankColor;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey.shade400;
    } else if (rank == 3) {
      rankColor = Colors.brown.shade300;
    }

    return ListTile(
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: item.picUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 48,
                height: 48,
                color: colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.music_note, size: 24),
              ),
              errorWidget: (context, url, error) => Container(
                width: 48,
                height: 48,
                color: colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.music_note, size: 24),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: rankColor ?? colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: rankColor != null
                      ? Colors.white
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        item.trackName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.artists.isNotEmpty ? item.artists : '未知艺术家',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${item.playCount} 次',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            item.toTrack().getSourceName(),
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
      onTap: () => _playTrack(item),
    );
  }

  /// 播放歌曲
  Future<void> _playTrack(PlayCountItem item) async {
    try {
      print('🎵 [MyPage] 播放排行榜歌曲: ${item.trackName}');
      print('   原始 source 字符串: "${item.source}"');
      final track = item.toTrack();
      print('   转换后 Track.source: ${track.source}');
      await PlayerService().playTrack(track);

      _showUserNotification(
        '开始播放: ${item.trackName}',
        severity: fluent.InfoBarSeverity.success,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      _showUserNotification(
        '播放失败: $e',
        severity: fluent.InfoBarSeverity.error,
        materialBackground: Colors.red,
      );
    }
  }

  /// 打开歌单详情
  void _openPlaylistDetail(Playlist playlist) {
    setState(() {
      _selectedPlaylist = playlist;
    });
    // 加载歌单歌曲
    _playlistService.loadPlaylistTracks(playlist.id);
  }

  /// 返回歌单列表
  void _backToList() {
    setState(() {
      _selectedPlaylist = null;
      _isEditMode = false;
      _selectedTrackIds.clear();
      // 清除搜索状态
      _isSearchMode = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }
  
  /// 切换搜索模式
  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }
  
  /// 更新搜索关键词
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }
  
  /// 根据搜索关键词过滤歌曲列表
  List<PlaylistTrack> _filterTracks(List<PlaylistTrack> tracks) {
    if (_searchQuery.isEmpty) {
      return tracks;
    }
    final query = _searchQuery.toLowerCase();
    return tracks.where((track) {
      return track.name.toLowerCase().contains(query) ||
          track.artists.toLowerCase().contains(query) ||
          track.album.toLowerCase().contains(query);
    }).toList();
  }

  /// 生成歌曲唯一标识
  String _getTrackKey(PlaylistTrack track) {
    return '${track.trackId}_${track.source.toString().split('.').last}';
  }

  /// 切换编辑模式
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _selectedTrackIds.clear();
      }
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (_selectedTrackIds.length == _playlistService.currentTracks.length) {
        _selectedTrackIds.clear();
      } else {
        _selectedTrackIds.clear();
        for (var track in _playlistService.currentTracks) {
          _selectedTrackIds.add(_getTrackKey(track));
        }
      }
    });
  }

  /// 切换单个歌曲的选中状态
  void _toggleTrackSelection(PlaylistTrack track) {
    setState(() {
      final key = _getTrackKey(track);
      if (_selectedTrackIds.contains(key)) {
        _selectedTrackIds.remove(key);
      } else {
        _selectedTrackIds.add(key);
      }
    });
  }

  /// 批量删除选中的歌曲
  Future<void> _batchRemoveTracks() async {
    if (_selectedPlaylist == null || _selectedTrackIds.isEmpty) return;

    bool? confirmed;
    if (_themeManager.isFluentFramework) {
      confirmed = await fluent.showDialog<bool>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('批量删除'),
          content: Text('确定要删除选中的 ${_selectedTrackIds.length} 首歌曲吗？'),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            fluent.FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('批量删除'),
          content: Text('确定要删除选中的 ${_selectedTrackIds.length} 首歌曲吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }

    if (confirmed != true) return;

    final tracksToDelete = _playlistService.currentTracks
        .where((track) => _selectedTrackIds.contains(_getTrackKey(track)))
        .toList();

    final deletedCount = await _playlistService.removeTracksFromPlaylist(
      _selectedPlaylist!.id,
      tracksToDelete,
    );

    if (!mounted) return;

    _showUserNotification(
      '已删除 $deletedCount 首歌曲',
      severity: fluent.InfoBarSeverity.success,
      duration: const Duration(seconds: 2),
    );

    setState(() {
      _isEditMode = false;
      _selectedTrackIds.clear();
    });
  }

  /// 显示导入歌单对话框
  void _showImportPlaylistDialog() {
    ImportPlaylistDialog.show(context).then((_) {
      // 导入完成后刷新歌单列表
      if (mounted) {
        _playlistService.loadPlaylists();
      }
    });
  }

  /// 显示创建歌单对话框
  void _showCreatePlaylistDialog() {
    if (_themeManager.isFluentFramework) {
      fluent.showDialog(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          String? err;
          return fluent.ContentDialog(
            title: const Text('新建歌单'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                fluent.TextBox(
                  controller: controller,
                  placeholder: '请输入歌单名称',
                  autofocus: true,
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  fluent.InfoBar(title: Text(err!), severity: fluent.InfoBarSeverity.warning),
                ],
              ],
            ),
            actions: [
              fluent.Button(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              fluent.FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    err = '歌单名称不能为空';
                    (context as Element).markNeedsBuild();
                    return;
                  }
                  Navigator.pop(context);
                  await _playlistService.createPlaylist(name);
                  _showUserNotification(
                    '歌单「$name」创建成功',
                    severity: fluent.InfoBarSeverity.success,
                  );
                },
                child: const Text('创建'),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          String playlistName = '';
          return AlertDialog(
            title: const Text('新建歌单'),
            content: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '请输入歌单名称',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                playlistName = value;
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  if (playlistName.trim().isEmpty) {
                    _showUserNotification(
                      '歌单名称不能为空',
                      severity: fluent.InfoBarSeverity.warning,
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _playlistService.createPlaylist(playlistName.trim());

                  _showUserNotification(
                    '歌单「$playlistName」创建成功',
                    severity: fluent.InfoBarSeverity.success,
                  );
                },
                child: const Text('创建'),
              ),
            ],
          );
        },
      );
    }
  }

  /// 构建歌单详情
  Widget _buildPlaylistDetail(Playlist playlist, ColorScheme colorScheme) {
    final allTracks = _playlistService.currentPlaylistId == playlist.id
        ? _playlistService.currentTracks
        : <PlaylistTrack>[];
    final isLoading = _playlistService.isLoadingTracks;
    
    // 根据搜索关键词过滤歌曲
    final filteredTracks = _filterTracks(allTracks);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 顶部标题栏
          _buildDetailAppBar(playlist, colorScheme, allTracks),
          
          // 搜索框（搜索模式时显示）
          if (_isSearchMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildSearchField(colorScheme),
              ),
            ),

          // 加载状态
          if (isLoading && allTracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          // 歌曲列表
          else if (allTracks.isEmpty)
            SliverFillRemaining(
              child: _buildDetailEmptyState(colorScheme),
            )
          // 搜索无结果
          else if (filteredTracks.isEmpty && _searchQuery.isNotEmpty)
            SliverFillRemaining(
              child: _buildSearchEmptyState(colorScheme),
            )
          else ...[
            // 统计信息和播放按钮
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildDetailStatisticsCard(
                  colorScheme, 
                  filteredTracks.length,
                  totalCount: allTracks.length,
                ),
              ),
            ),

            // 歌曲列表
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = filteredTracks[index];
                    // 获取原始索引用于播放
                    final originalIndex = allTracks.indexOf(track);
                    return _buildTrackItem(track, originalIndex, colorScheme);
                  },
                  childCount: filteredTracks.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ],
      ),
    );
  }
  
  /// 构建搜索框
  Widget _buildSearchField(ColorScheme colorScheme) {
    if (_themeManager.isFluentFramework) {
      return fluent.TextBox(
        controller: _searchController,
        placeholder: '搜索歌曲、歌手、专辑...',
        prefix: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(fluent.FluentIcons.search, size: 16),
        ),
        suffix: _searchQuery.isNotEmpty
            ? fluent.IconButton(
                icon: const Icon(fluent.FluentIcons.clear, size: 12),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        onChanged: _onSearchChanged,
        autofocus: true,
      );
    }
    
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '搜索歌曲、歌手、专辑...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: _onSearchChanged,
      autofocus: true,
    );
  }
  
  /// 构建搜索无结果状态
  Widget _buildSearchEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '未找到匹配的歌曲',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试其他关键词',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建歌单详情顶部栏
  Widget _buildDetailAppBar(Playlist playlist, ColorScheme colorScheme, List<PlaylistTrack> tracks) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _backToList,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditMode ? '已选择 ${_selectedTrackIds.length} 首' : playlist.name,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!_isEditMode && playlist.isDefault)
            Text(
              '默认歌单',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
        ],
      ),
      actions: [
        if (_isEditMode) ...[
          // 全选按钮
          IconButton(
            icon: Icon(
              _selectedTrackIds.length == tracks.length
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: tracks.isNotEmpty ? _toggleSelectAll : null,
            tooltip: _selectedTrackIds.length == tracks.length ? '取消全选' : '全选',
          ),
          // 批量删除按钮
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _selectedTrackIds.isNotEmpty ? _batchRemoveTracks : null,
            tooltip: '删除选中',
          ),
          // 取消按钮
          TextButton(
            onPressed: _toggleEditMode,
            child: const Text('取消'),
          ),
        ] else ...[
          // 搜索按钮
          if (tracks.isNotEmpty)
            IconButton(
              icon: Icon(_isSearchMode ? Icons.search_off : Icons.search),
              onPressed: _toggleSearchMode,
              tooltip: _isSearchMode ? '关闭搜索' : '搜索歌曲',
            ),
          // 换源按钮
          if (tracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _showSourceSwitchDialog(playlist, tracks),
              tooltip: '换源',
            ),
          // 编辑按钮
          if (tracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: '批量管理',
            ),
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              if (!_hasImportConfig(playlist)) {
                _showUserNotification(
                  '请先在"导入管理"中绑定来源后再同步',
                  severity: fluent.InfoBarSeverity.warning,
                );
                return;
              }
              _showUserNotification(
                '正在同步...',
                duration: const Duration(seconds: 1),
              );
              final result = await _playlistService.syncPlaylist(playlist.id);
              _showUserNotification(
                _formatSyncResultMessage(result),
                severity: result.insertedCount > 0
                    ? fluent.InfoBarSeverity.success
                    : fluent.InfoBarSeverity.info,
              );
              await _playlistService.loadPlaylistTracks(playlist.id);
            },
            tooltip: '同步',
          ),
        ],
      ],
    );
  }

  /// 构建详情页统计信息卡片
  Widget _buildDetailStatisticsCard(ColorScheme colorScheme, int count, {int? totalCount}) {
    // 如果有搜索过滤，显示 "筛选出 X / 共 Y 首歌曲"
    final String countText = (totalCount != null && totalCount != count)
        ? '筛选出 $count / 共 $totalCount 首歌曲'
        : '共 $count 首歌曲';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.music_note,
              size: 24,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              countText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            if (count > 0)
              FilledButton.icon(
                onPressed: _playAll,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('播放全部'),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建详情页空状态
  Widget _buildDetailEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '歌单为空',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '快去添加一些喜欢的歌曲吧',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建歌曲项
  Widget _buildTrackItem(PlaylistTrack item, int index, ColorScheme colorScheme) {
    final trackKey = _getTrackKey(item);
    final isSelected = _selectedTrackIds.contains(trackKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected && _isEditMode
          ? colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: ListTile(
        leading: _isEditMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleTrackSelection(item),
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: item.picUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 50,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.music_note,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                '${item.artists} • ${item.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getSourceIcon(item.source),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: _isEditMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playDetailTrack(index),
                    tooltip: '播放',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    color: Colors.redAccent,
                    onPressed: () => _confirmRemoveTrack(item),
                    tooltip: '从歌单移除',
                  ),
                ],
              ),
        onTap: _isEditMode
            ? () => _toggleTrackSelection(item)
            : () => _playDetailTrack(index),
      ),
    );
  }

  /// 获取音乐平台图标
  String _getSourceIcon(source) {
    switch (source.toString()) {
      case 'MusicSource.netease':
        return '🎵';
      case 'MusicSource.qq':
        return '🎶';
      case 'MusicSource.kugou':
        return '🎼';
      default:
        return '🎵';
    }
  }

  /// 播放歌单中的指定歌曲
  void _playDetailTrack(int index) {
    final tracks = _playlistService.currentTracks;
    if (tracks.isEmpty) return;

    final trackList = tracks.map((t) => t.toTrack()).toList();

    PlaylistQueueService().setQueue(
      trackList,
      index,
      QueueSource.playlist,
    );

    PlayerService().playTrack(trackList[index]);

    _showUserNotification(
      '正在播放: ${tracks[index].name}',
      severity: fluent.InfoBarSeverity.success,
      duration: const Duration(seconds: 1),
    );
  }

  /// 播放歌单全部歌曲
  void _playAll() {
    final tracks = _playlistService.currentTracks;
    if (tracks.isEmpty) return;

    final trackList = tracks.map((t) => t.toTrack()).toList();

    PlaylistQueueService().setQueue(
      trackList,
      0,
      QueueSource.playlist,
    );

    PlayerService().playTrack(trackList[0]);

    _showUserNotification(
      '开始播放: ${_selectedPlaylist?.name ?? "歌单"}',
      severity: fluent.InfoBarSeverity.success,
      duration: const Duration(seconds: 2),
    );
  }

  /// 确认移除歌曲
  Future<void> _confirmRemoveTrack(PlaylistTrack track) async {
    if (_selectedPlaylist == null) return;

    bool? confirmed;
    if (_themeManager.isFluentFramework) {
      confirmed = await fluent.showDialog<bool>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('移除歌曲'),
          content: Text('确定要从歌单中移除「${track.name}」吗？'),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            fluent.FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('移除'),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('移除歌曲'),
          content: Text('确定要从歌单中移除「${track.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('移除'),
            ),
          ],
        ),
      );
    }

    if (confirmed != true) return;

    final success = await _playlistService.removeTrackFromPlaylist(
      _selectedPlaylist!.id,
      track,
    );

    _showUserNotification(
      success ? '已从歌单移除' : '移除失败',
      severity: success ? fluent.InfoBarSeverity.success : fluent.InfoBarSeverity.error,
      materialBackground: success ? null : Colors.red,
      duration: const Duration(seconds: 2),
    );
  }

  /// 确认删除歌单
  Future<void> _confirmDeletePlaylist(Playlist playlist) async {
    // 防止删除默认歌单
    if (playlist.isDefault) {
      _showUserNotification(
        '默认歌单不能删除',
        severity: fluent.InfoBarSeverity.warning,
        materialBackground: Colors.orange,
      );
      return;
    }

    bool? confirmed;
    if (_themeManager.isFluentFramework) {
      confirmed = await fluent.showDialog<bool>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('删除歌单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要删除歌单「${playlist.name}」吗？'),
              const SizedBox(height: 8),
              if (playlist.trackCount > 0)
                Text(
                  '该歌单包含 ${playlist.trackCount} 首歌曲，删除后将无法恢复。',
                  style: TextStyle(
                    fontSize: 12,
                    color: fluent.FluentTheme.of(context).resources.textFillColorSecondary,
                  ),
                ),
            ],
          ),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            fluent.FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除歌单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要删除歌单「${playlist.name}」吗？'),
              const SizedBox(height: 8),
              if (playlist.trackCount > 0)
                Text(
                  '该歌单包含 ${playlist.trackCount} 首歌曲，删除后将无法恢复。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }

    if (confirmed != true) return;

    // 执行删除操作
    final success = await _playlistService.deletePlaylist(playlist.id);

    if (!mounted) return;

    _showUserNotification(
      success ? '歌单「${playlist.name}」已删除' : '删除失败',
      severity: success ? fluent.InfoBarSeverity.success : fluent.InfoBarSeverity.error,
      materialBackground: success ? null : Colors.red,
      duration: const Duration(seconds: 2),
    );

    if (success && _selectedPlaylist?.id == playlist.id) {
      _backToList();
    }
  }

  /// 显示换源对话框
  Future<void> _showSourceSwitchDialog(Playlist playlist, List<PlaylistTrack> tracks) async {
    if (tracks.isEmpty) {
      _showUserNotification(
        '歌单为空，无法换源',
        severity: fluent.InfoBarSeverity.warning,
      );
      return;
    }

    // 获取当前歌单中最常见的来源
    final sourceCounts = <MusicSource, int>{};
    for (final track in tracks) {
      sourceCounts[track.source] = (sourceCounts[track.source] ?? 0) + 1;
    }
    final currentSource = sourceCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // 第一步：选择平台和歌曲
    Map<String, dynamic>? selectResult;
    if (_themeManager.isFluentFramework) {
      selectResult = await fluent.showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SourceSwitchSelectDialog(
          tracks: tracks,
          currentSource: currentSource,
        ),
      );
    } else {
      selectResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SourceSwitchSelectDialog(
          tracks: tracks,
          currentSource: currentSource,
        ),
      );
    }

    if (selectResult == null || !mounted) return;

    final targetSource = selectResult['targetSource'] as MusicSource;
    final selectedTracks = selectResult['selectedTracks'] as List<PlaylistTrack>;

    // 第二步：显示处理进度
    bool? progressResult;
    if (_themeManager.isFluentFramework) {
      progressResult = await fluent.showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => SourceSwitchProgressDialog(
          tracks: selectedTracks,
          targetSource: targetSource,
        ),
      );
    } else {
      progressResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => SourceSwitchProgressDialog(
          tracks: selectedTracks,
          targetSource: targetSource,
        ),
      );
    }

    if (progressResult != true || !mounted) {
      TrackSourceSwitchService().clear();
      return;
    }

    // 第三步：选择匹配结果
    List<MapEntry<PlaylistTrack, Track>>? confirmResult;
    if (_themeManager.isFluentFramework) {
      confirmResult = await fluent.showDialog<List<MapEntry<PlaylistTrack, Track>>>(
        context: context,
        builder: (context) => const SourceSwitchResultDialog(),
      );
    } else {
      confirmResult = await showDialog<List<MapEntry<PlaylistTrack, Track>>>(
        context: context,
        builder: (context) => const SourceSwitchResultDialog(),
      );
    }

    if (confirmResult == null || confirmResult.isEmpty || !mounted) {
      TrackSourceSwitchService().clear();
      return;
    }

    // 执行换源操作
    await _executeSourceSwitch(playlist, confirmResult);
    TrackSourceSwitchService().clear();
  }

  /// 执行换源操作
  Future<void> _executeSourceSwitch(
    Playlist playlist,
    List<MapEntry<PlaylistTrack, Track>> switchPairs,
  ) async {
    _showUserNotification(
      '正在更新歌单...',
      duration: const Duration(seconds: 1),
    );

    int successCount = 0;
    int failCount = 0;

    for (final pair in switchPairs) {
      final oldTrack = pair.key;
      final newTrack = pair.value;

      try {
        // 先移除旧歌曲
        final removeSuccess = await _playlistService.removeTrackFromPlaylist(
          playlist.id,
          oldTrack,
        );

        if (removeSuccess) {
          // 添加新歌曲
          final addSuccess = await _playlistService.addTrackToPlaylist(
            playlist.id,
            newTrack,
          );

          if (addSuccess) {
            successCount++;
          } else {
            failCount++;
          }
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
        print('❌ [MyPage] 换源失败: $e');
      }
    }

    // 刷新歌单
    await _playlistService.loadPlaylistTracks(playlist.id);

    if (!mounted) return;

    if (failCount == 0) {
      _showUserNotification(
        '换源完成，成功更新 $successCount 首歌曲',
        severity: fluent.InfoBarSeverity.success,
      );
    } else {
      _showUserNotification(
        '换源完成，成功 $successCount 首，失败 $failCount 首',
        severity: fluent.InfoBarSeverity.warning,
      );
    }
  }
}

