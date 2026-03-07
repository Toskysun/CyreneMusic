import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../../services/netease_login_service.dart';
import '../../utils/theme_manager.dart';
import '../discover_playlist_detail_page.dart';

class NeteaseLibraryPlaylistsPage extends StatefulWidget {
  const NeteaseLibraryPlaylistsPage({super.key});

  @override
  State<NeteaseLibraryPlaylistsPage> createState() => _NeteaseLibraryPlaylistsPageState();
}

class _NeteaseLibraryPlaylistsState extends State<NeteaseLibraryPlaylistsPage> {
  List<NeteasePlaylistInfo>? _playlists;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final playlists = await NeteaseLoginService().fetchUserPlaylists(limit: 100);
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (themeManager.isFluentFramework) {
      return _buildFluent(context);
    }
    if (themeManager.isCupertinoFramework) {
      return _buildCupertino(context, isDark);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的网易云歌单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlaylists,
          ),
        ],
      ),
      body: _buildMaterialBody(context),
    );
  }

  Widget _buildMaterialBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败: $_error'));
    if (_playlists == null || _playlists!.isEmpty) return const Center(child: Text('暂无歌单'));

    return ListView.builder(
      itemCount: _playlists!.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final playlist = _playlists![index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: playlist.coverImgUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[300]),
              errorWidget: (context, url, error) => const Icon(Icons.music_note),
            ),
          ),
          title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${playlist.trackCount} 首歌曲 · ${playlist.creator}'),
          trailing: playlist.subscribed ? const Icon(Icons.favorite, color: Colors.red, size: 16) : null,
          onTap: () => _navigateToDetail(playlist.id),
        );
      },
    );
  }

  Widget _buildCupertino(BuildContext context, bool isDark) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('我的网易云歌单'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh),
          onPressed: _loadPlaylists,
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? Center(child: Text('加载失败: $_error'))
                : _playlists == null || _playlists!.isEmpty
                    ? const Center(child: Text('暂无歌单'))
                    : ListView.separated(
                        itemCount: _playlists!.length,
                        separatorBuilder: (context, index) => const Divider(indent: 84, height: 1),
                        itemBuilder: (context, index) {
                          final playlist = _playlists![index];
                          return CupertinoButton(
                            padding: const EdgeInsets.all(12),
                            onPressed: () => _navigateToDetail(playlist.id),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: playlist.coverImgUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playlist.name,
                                        style: TextStyle(
                                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${playlist.trackCount} 首歌曲 · ${playlist.creator}',
                                        style: const TextStyle(
                                          color: CupertinoColors.systemGrey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (playlist.subscribed)
                                  const Icon(CupertinoIcons.heart_fill, color: CupertinoColors.systemRed, size: 14),
                                const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey4),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildFluent(BuildContext context) {
    return fluent.ScaffoldPage(
      header: fluent.PageHeader(
        title: const Text('我的网易云歌单'),
        commandBar: fluent.CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            fluent.CommandBarButton(
              icon: const fluent.Icon(fluent.FluentIcons.refresh),
              onPressed: _loadPlaylists,
            ),
          ],
        ),
      ),
      content: _loading
          ? const Center(child: fluent.ProgressBar())
          : _error != null
              ? Center(child: Text('加载失败: $_error'))
              : _playlists == null || _playlists!.isEmpty
                  ? const Center(child: Text('暂无歌单'))
                  : ListView.builder(
                      itemCount: _playlists!.length,
                      itemBuilder: (context, index) {
                        final playlist = _playlists![index];
                        return fluent.ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: playlist.coverImgUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(playlist.name),
                          subtitle: Text('${playlist.trackCount} 首歌曲'),
                          onPressed: () => _navigateToDetail(playlist.id),
                        );
                      },
                    ),
    );
  }

  void _navigateToDetail(String playlistId) {
    final pid = int.tryParse(playlistId);
    if (pid != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DiscoverPlaylistDetailPage(playlistId: pid),
        ),
      );
    }
  }
}

class _NeteaseLibraryPlaylistsPageState extends _NeteaseLibraryPlaylistsState {}
