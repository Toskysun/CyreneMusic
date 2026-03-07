import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/netease_recommend_service.dart';
import '../../utils/theme_manager.dart';
import '../artist_detail_page.dart';

class NeteaseLibraryArtistsPage extends StatefulWidget {
  const NeteaseLibraryArtistsPage({super.key});

  @override
  State<NeteaseLibraryArtistsPage> createState() => _NeteaseLibraryArtistsPageState();
}

class _NeteaseLibraryArtistsPageState extends State<NeteaseLibraryArtistsPage> {
  List<Map<String, dynamic>>? _subscribedArtists;
  List<Map<String, dynamic>>? _recommendedArtists;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        NeteaseRecommendService().fetchSubscribedArtists(),
        NeteaseRecommendService().fetchTopArtists(limit: 30),
      ]);
      
      if (mounted) {
        setState(() {
          _subscribedArtists = results[0];
          _recommendedArtists = results[1];
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (ThemeManager().isCupertinoFramework) {
      return _buildCupertino(context, isDark);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null 
              ? Center(child: Text('加载失败: $_error'))
              : _buildModernBody(context, isDark),
    );
  }

  Widget _buildModernBody(BuildContext context, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(context, isDark),
        if (_subscribedArtists != null && _subscribedArtists!.isNotEmpty)
          _buildSubscribedSection(isDark),
        if (_recommendedArtists != null && _recommendedArtists!.isNotEmpty)
          _buildRecommendedSection(isDark),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          '歌手库',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : Colors.black54),
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildSubscribedSection(bool isDark) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('关注的歌手', isDark),
          SizedBox(
            height: 110,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _subscribedArtists!.length,
              itemBuilder: (context, index) {
                final artist = _subscribedArtists![index];
                final picUrl = artist['picUrl'] ?? artist['img1v1Url'] ?? '';
                return GestureDetector(
                  onTap: () => _navigateToArtistDetail(artist['id']),
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        _buildCircleAvatar(picUrl, 60),
                        const SizedBox(height: 8),
                        Text(
                          artist['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection(bool isDark) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _buildSectionHeader('推荐歌手', isDark)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildArtistCard(_recommendedArtists![index], isDark);
              },
              childCount: _recommendedArtists!.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildArtistCard(Map<String, dynamic> artist, bool isDark) {
    final picUrl = artist['picUrl'] ?? artist['img1v1Url'] ?? '';
    return GestureDetector(
      onTap: () => _navigateToArtistDetail(artist['id']),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: picUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[isDark ? 800 : 200]),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.white.withValues(alpha: 0.1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artist['albumSize'] != null)
                          Text(
                            '${artist['albumSize']} 专辑',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToArtistDetail(dynamic id) {
    if (id == null) return;
    final artistId = id is int ? id : int.tryParse(id.toString());
    if (artistId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArtistDetailPage(artistId: artistId)),
      );
    }
  }

  Widget _buildCircleAvatar(String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
              )
            : const Icon(Icons.person, color: Colors.grey),
      ),
    );
  }

  Widget _buildCupertino(BuildContext context, bool isDark) {
    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: isDark 
                ? CupertinoColors.black.withValues(alpha: 0.5) 
                : CupertinoColors.white.withValues(alpha: 0.5),
            border: null,
            largeTitle: const Text('歌手库'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.refresh),
              onPressed: _loadData,
            ),
          ),
          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(child: CupertinoActivityIndicator()),
                  )
                : _error != null
                    ? Center(child: Text('加载失败: $_error'))
                    : _buildCupertinoModernContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoModernContent(bool isDark) {
    final sections = <Widget>[];

    if (_subscribedArtists != null && _subscribedArtists!.isNotEmpty) {
      sections.add(_buildSectionHeader('关注的歌手', isDark));
      sections.add(
        SizedBox(
          height: 110,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _subscribedArtists!.length,
            itemBuilder: (context, index) {
              final artist = _subscribedArtists![index];
              final picUrl = artist['picUrl'] ?? artist['img1v1Url'] ?? '';
              return GestureDetector(
                onTap: () => _navigateToArtistDetail(artist['id']),
                child: Container(
                  width: 75,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      _buildCircleAvatar(picUrl, 65),
                      const SizedBox(height: 6),
                      Text(
                        artist['name'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (_recommendedArtists != null && _recommendedArtists!.isNotEmpty) {
      sections.add(_buildSectionHeader('推荐歌手', isDark));
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: _recommendedArtists!.length,
            itemBuilder: (context, index) => _buildArtistCard(_recommendedArtists![index], isDark),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}

