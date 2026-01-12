import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../services/play_history_service.dart';
import '../services/player_service.dart';
import '../models/track.dart';
import '../utils/theme_manager.dart';

/// 播放历史页面
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with AutomaticKeepAliveClientMixin {
  final PlayHistoryService _historyService = PlayHistoryService();
  final ThemeManager _themeManager = ThemeManager();
  String? _fluentInfoText;
  fluent.InfoBarSeverity _fluentInfoSeverity = fluent.InfoBarSeverity.info;
  Timer? _infoBarTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _historyService.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _historyService.removeListener(_onHistoryChanged);
    _infoBarTimer?.cancel();
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isCupertino => _themeManager.isCupertinoFramework;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final history = _historyService.history;

    if (_themeManager.isFluentFramework) {
      return _buildFluentPage(context, history);
    }

    if (_isCupertino) {
      return _buildCupertinoPage(context, history);
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 顶部标题栏
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: colorScheme.surface,
            title: Text(
              '播放历史',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _showClearConfirmDialog,
                  tooltip: '清空历史',
                ),
            ],
          ),

          // 统计信息卡片
          if (history.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildStatisticsCard(colorScheme),
              ),
            ),

          // 历史记录列表
          if (history.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(colorScheme),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = history[index];
                    return _buildHistoryItem(item, index, colorScheme);
                  },
                  childCount: history.length,
                ),
              ),
            ),

          // 底部留白
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFluentPage(BuildContext context, List<PlayHistoryItem> history) {
    return fluent.ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                const Text(
                  '播放历史',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (history.isNotEmpty)
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.delete),
                    onPressed: _showFluentClearConfirmDialog,
                  ),
              ],
            ),
          ),
          // Removed Divider to avoid white line between header and content under acrylic/mica
          if (_fluentInfoText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: fluent.InfoBar(
                title: Text(_fluentInfoText!),
                severity: _fluentInfoSeverity,
                isLong: false,
              ),
            ),
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildFluentStatisticsCard(context),
            ),
          Expanded(
            child: history.isEmpty
                ? _buildFluentEmptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemBuilder: (context, index) => RepaintBoundary(
                      child: _FluentHistoryTile(
                        item: history[index],
                        index: index,
                        onDelete: () {
                          _historyService.removeHistoryItem(history[index]);
                          _showFluentInfo('已删除');
                        },
                        onPlay: () {
                          PlayerService().playTrack(history[index].toTrack());
                          _showFluentInfo('正在播放: ${history[index].name}');
                        },
                      ),
                    ),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: history.length,
                  ),
          ),
        ],
      ),
    );
  }

  /// iOS Cupertino 风格页面
  Widget _buildCupertinoPage(BuildContext context, List<PlayHistoryItem> history) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: CupertinoPageScaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          middle: const Text('播放历史'),
          backgroundColor: (isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white).withOpacity(0.9),
          border: null,
          trailing: history.isNotEmpty
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.trash, size: 22),
                  onPressed: _showCupertinoClearConfirmDialog,
                )
              : null,
        ),
        child: SafeArea(
          child: history.isEmpty
              ? _buildCupertinoEmptyState(isDark)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 统计卡片
                    _buildCupertinoStatisticsCard(isDark),
                    const SizedBox(height: 16),
                    // 历史记录列表
                    ...history.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildCupertinoHistoryItem(entry.value, entry.key, isDark),
                      );
                    }),
                    // 底部留白给迷你播放器
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCupertinoStatisticsCard(bool isDark) {
    final todayCount = _historyService.getTodayPlayCount();
    final weekCount = _historyService.getWeekPlayCount();
    final totalCount = _historyService.history.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.chart_bar_fill, size: 18, color: CupertinoColors.activeBlue),
              const SizedBox(width: 8),
              Text(
                '播放统计',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCupertinoStatItem('今日', todayCount, isDark),
              _buildCupertinoStatItem('本周', weekCount, isDark),
              _buildCupertinoStatItem('总计', totalCount, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoStatItem(String label, int count, bool isDark) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.activeBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildCupertinoHistoryItem(PlayHistoryItem item, int index, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          PlayerService().playTrack(item.toTrack());
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 封面
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: item.picUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5,
                        child: const CupertinoActivityIndicator(radius: 10),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 50,
                        color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5,
                        child: Icon(CupertinoIcons.music_note, color: CupertinoColors.systemGrey),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4)),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? CupertinoColors.white : CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.artists} • ${item.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _getSourceIcon(item.source),
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(item.playedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 操作按钮
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minSize: 0,
                    onPressed: () {
                      PlayerService().playTrack(item.toTrack());
                    },
                    child: Icon(CupertinoIcons.play_fill, size: 20, color: CupertinoColors.activeBlue),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minSize: 0,
                    onPressed: () {
                      _historyService.removeHistoryItem(item);
                    },
                    child: Icon(CupertinoIcons.trash, size: 18, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCupertinoEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.time,
            size: 80,
            color: CupertinoColors.systemGrey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放历史',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '播放歌曲后会自动记录',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  void _showCupertinoClearConfirmDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('清空播放历史'),
        content: const Text('确定要清空所有播放历史吗？此操作无法撤销。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('清空'),
            onPressed: () {
              _historyService.clearHistory();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard(ColorScheme colorScheme) {
    final todayCount = _historyService.getTodayPlayCount();
    final weekCount = _historyService.getWeekPlayCount();
    final totalCount = _historyService.history.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '播放统计',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('今日', todayCount, colorScheme),
                _buildStatItem('本周', weekCount, colorScheme),
                _buildStatItem('总计', totalCount, colorScheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个统计项
  Widget _buildStatItem(String label, int count, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  /// 构建历史记录项
  Widget _buildHistoryItem(PlayHistoryItem item, int index, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
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
            // 播放序号标记
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.artists} • ${item.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  _getSourceIcon(item.source),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(item.playedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                PlayerService().playTrack(item.toTrack());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('正在播放: ${item.name}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: '播放',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                _historyService.removeHistoryItem(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已删除'),
                    duration: const Duration(seconds: 1),
                    action: SnackBarAction(
                      label: '撤销',
                      onPressed: () {
                        // TODO: 实现撤销功能
                      },
                    ),
                  ),
                );
              },
              tooltip: '删除',
            ),
          ],
        ),
        onTap: () {
          PlayerService().playTrack(item.toTrack());
        },
      ),
    );
  }

  /// 获取音乐平台图标
  String _getSourceIcon(MusicSource source) {
    switch (source) {
      case MusicSource.netease:
        return '🎵';
      case MusicSource.apple:
        return '🍎';
      case MusicSource.qq:
        return '🎶';
      case MusicSource.kugou:
        return '🎼';
      case MusicSource.kuwo:
        return '🎸';
      case MusicSource.local:
        return '📁';
    }
  }

  /// 格式化时间显示
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      // 简单格式化：MM月dd日
      return '${time.month}月${time.day}日';
    }
  }

  /// 构建空状态
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放历史',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '播放歌曲后会自动记录',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  /// 显示清空确认对话框
  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放历史'),
        content: const Text('确定要清空所有播放历史吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              _historyService.clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清空播放历史')),
              );
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
  
  void _showFluentClearConfirmDialog() {
    fluent.showDialog(
      context: context,
      builder: (context) => fluent.ContentDialog(
        title: const Text('清空播放历史'),
        content: const Text('确定要清空所有播放历史吗？此操作无法撤销。'),
        actions: [
          fluent.Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          fluent.FilledButton(
            onPressed: () {
              _historyService.clearHistory();
              Navigator.pop(context);
              _showFluentInfo('已清空播放历史');
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _showFluentInfo(String text, [fluent.InfoBarSeverity severity = fluent.InfoBarSeverity.info]) {
    _infoBarTimer?.cancel();
    setState(() {
      _fluentInfoText = text;
      _fluentInfoSeverity = severity;
    });
    _infoBarTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _fluentInfoText = null;
      });
    });
  }

  Widget _buildFluentStatisticsCard(BuildContext context) {
    final todayCount = _historyService.getTodayPlayCount();
    final weekCount = _historyService.getWeekPlayCount();
    final totalCount = _historyService.history.length;
    return fluent.Card(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(fluent.FluentIcons.bulleted_list, size: 20),
              SizedBox(width: 8),
              Text(
                '播放统计',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFluentStatItem(context, '今日', todayCount),
              _buildFluentStatItem(context, '本周', weekCount),
              _buildFluentStatItem(context, '总计', totalCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFluentStatItem(BuildContext context, String label, int count) {
    final theme = fluent.FluentTheme.of(context);
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: theme.accentColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildFluentEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(fluent.FluentIcons.history, size: 80),
          SizedBox(height: 16),
          Text('暂无播放历史', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('播放歌曲后会自动记录', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// 独立的播放历史卡片组件，用于性能优化
class _FluentHistoryTile extends StatelessWidget {
  final PlayHistoryItem item;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onPlay;

  const _FluentHistoryTile({
    required this.item,
    required this.index,
    required this.onDelete,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final resources = theme.resources;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: fluent.Card(
        borderRadius: BorderRadius.circular(12),
        padding: EdgeInsets.zero,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: resources.textFillColorSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.picUrl,
                    width: 64,
                    height: 64,
                    memCacheWidth: 128, // 性能优化：限制内存缓存大小
                    memCacheHeight: 128,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 64,
                      height: 64,
                      color: resources.controlAltFillColorSecondary,
                      alignment: Alignment.center,
                      child: const fluent.ProgressRing(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 64,
                      height: 64,
                      color: resources.controlAltFillColorSecondary,
                      alignment: Alignment.center,
                      child: Icon(
                        fluent.FluentIcons.music_in_collection,
                        size: 24,
                        color: resources.textFillColorTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.artists} • ${item.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: resources.textFillColorSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // 移除 emoji，仅显示时间
                        _formatTime(item.playedAt),
                        style: TextStyle(
                          color: resources.textFillColorTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    fluent.IconButton(
                      icon: const Icon(fluent.FluentIcons.play),
                      onPressed: onPlay,
                    ),
                    fluent.IconButton(
                      icon: const Icon(fluent.FluentIcons.delete),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 格式化时间显示 (复制自 HistoryPage 以便独立使用)
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}

