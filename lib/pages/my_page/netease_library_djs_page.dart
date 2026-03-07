import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/netease_recommend_service.dart';
import '../../utils/theme_manager.dart';

class NeteaseLibraryDjsPage extends StatefulWidget {
  const NeteaseLibraryDjsPage({super.key});

  @override
  State<NeteaseLibraryDjsPage> createState() => _NeteaseLibraryDjsPageState();
}

class _NeteaseLibraryDjsPageState extends State<NeteaseLibraryDjsPage> {
  List<Map<String, dynamic>>? _djs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDjs();
  }

  Future<void> _loadDjs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final djs = await NeteaseRecommendService().fetchSubscribedDjs();
      if (mounted) {
        setState(() {
          _djs = djs;
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
        title: const Text('收藏的电台'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDjs),
        ],
      ),
      body: _buildMaterialBody(context),
    );
  }

  Widget _buildMaterialBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败: $_error'));
    if (_djs == null || _djs!.isEmpty) return const Center(child: Text('暂无收藏电台'));

    return ListView.builder(
      itemCount: _djs!.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final dj = _djs![index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: dj['picUrl'] ?? '',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[300]),
            ),
          ),
          title: Text(dj['name'] ?? ''),
          subtitle: Text('${dj['programCount'] ?? 0} 个节目 · by ${dj['dj']?['nickname'] ?? ''}'),
          onTap: () {
            // TODO: Navigate to DJ detail
          },
        );
      },
    );
  }

  Widget _buildCupertino(BuildContext context, bool isDark) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('收藏的电台'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh),
          onPressed: _loadDjs,
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? Center(child: Text('加载失败: $_error'))
                : _djs == null || _djs!.isEmpty
                    ? const Center(child: Text('暂无收藏电台'))
                    : ListView.separated(
                        itemCount: _djs!.length,
                        separatorBuilder: (context, index) => const Divider(indent: 84, height: 1),
                        itemBuilder: (context, index) {
                          final dj = _djs![index];
                          return CupertinoButton(
                            padding: const EdgeInsets.all(12),
                            onPressed: () {
                              // TODO: Navigate to DJ detail
                            },
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: dj['picUrl'] ?? '',
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
                                        dj['name'] ?? '',
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
                                        '${dj['programCount'] ?? 0} 个节目 · by ${dj['dj']?['nickname'] ?? ''}',
                                        style: const TextStyle(
                                          color: CupertinoColors.systemGrey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey4),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
