import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/netease_recommend_service.dart';
import '../../utils/theme_manager.dart';

class NeteaseLibraryAlbumsPage extends StatefulWidget {
  const NeteaseLibraryAlbumsPage({super.key});

  @override
  State<NeteaseLibraryAlbumsPage> createState() => _NeteaseLibraryAlbumsPageState();
}

class _NeteaseLibraryAlbumsPageState extends State<NeteaseLibraryAlbumsPage> {
  List<Map<String, dynamic>>? _albums;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final albums = await NeteaseRecommendService().fetchSubscribedAlbums();
      if (mounted) {
        setState(() {
          _albums = albums;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (ThemeManager().isCupertinoFramework) {
      return _buildCupertino(context, isDark);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏的专辑'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAlbums),
        ],
      ),
      body: _buildMaterialBody(context),
    );
  }

  Widget _buildMaterialBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败: $_error'));
    if (_albums == null || _albums!.isEmpty) return const Center(child: Text('暂无收藏专辑'));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _albums!.length,
      itemBuilder: (context, index) {
        final album = _albums![index];
        return InkWell(
          onTap: () {
            // TODO: Navigate to album detail
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: album['picUrl'] ?? album['picUrl'] ?? '',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(color: Colors.grey[300]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                (album['artists'] as List?)?.map((a) => a['name']).join('/') ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCupertino(BuildContext context, bool isDark) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('收藏的专辑'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh),
          onPressed: _loadAlbums,
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? Center(child: Text('加载失败: $_error'))
                : _albums == null || _albums!.isEmpty
                    ? const Center(child: Text('暂无收藏专辑'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _albums!.length,
                        itemBuilder: (context, index) {
                          final album = _albums![index];
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              // TODO: Navigate to album detail
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: album['picUrl'] ?? '',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  album['name'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  (album['artists'] as List?)?.map((a) => a['name']).join('/') ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
