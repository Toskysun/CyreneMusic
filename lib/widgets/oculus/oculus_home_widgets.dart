import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/theme_manager.dart';
import '../../services/auth_service.dart';
import '../../services/weather_service.dart';
import '../../services/player_service.dart';
import '../../services/playlist_queue_service.dart';
import '../../models/track.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../pages/favorites_page.dart';
import '../../pages/my_page/netease_library_playlists_page.dart';
import '../../pages/my_page/netease_library_albums_page.dart';
import '../../pages/my_page/netease_library_artists_page.dart';
import '../../pages/my_page/netease_library_djs_page.dart';

/// Oculus 风格的首页标签切换组件
class OculusHomeTabs extends StatelessWidget {
  final List<String> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const OculusHomeTabs({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 视觉配置：同步底栏色值
    final Color backgroundColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final Color activeColor = isDark ? Colors.white : Colors.black;
    final Color inactiveColor = isDark ? Colors.white.withOpacity(0.5) : Colors.black45;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final isSelected = index == currentIndex;
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                HapticFeedback.lightImpact();
                onChanged(index);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  letterSpacing: isSelected ? 0 : 0.2,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Oculus 风格的分区标题
class OculusSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMoreTap;
  final String? moreLabel;

  const OculusSectionHeader({
    super.key,
    required this.title,
    this.onMoreTap,
    this.moreLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          if (onMoreTap != null)
            TextButton(
              onPressed: onMoreTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                children: [
                  Text(
                    moreLabel ?? '更多',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Oculus 风格的顶栏（焕新版，支持内容溢出背景）
class OculusSliverAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final SystemUiOverlayStyle? systemOverlayStyle;

  const OculusSliverAppBar({
    super.key,
    required this.title,
    this.actions,
    this.systemOverlayStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      systemOverlayStyle: systemOverlayStyle,
      expandedHeight: 100,
      floating: true,
      pinned: true, // 焕新版设为 pinned 保持可见
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
            padding: const EdgeInsets.only(left: 24, bottom: 12),
            alignment: Alignment.bottomLeft,
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            ),
          ),
        ),
      ),
      actions: actions,
    );
  }
}

/// Oculus 风格的问候语头部
class OculusGreetingHeader extends StatelessWidget {
  const OculusGreetingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final now = DateTime.now();
    final hour = now.hour;
    
    String greeting = '你好';
    if (hour < 6) greeting = '夜深了';
    else if (hour < 12) greeting = '早上好';
    else if (hour < 14) greeting = '中午好';
    else if (hour < 18) greeting = '下午好';
    else greeting = '晚上好';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$greeting, ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      user?.username ?? '音乐旅人',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FutureBuilder<String?>(
                  future: WeatherService().fetchWeatherText(),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? '愿音乐伴你度过美好的一天',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (user?.avatarUrl != null)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(user!.avatarUrl!),
              ),
            )
          else
            const Icon(Icons.account_circle, size: 48, color: Colors.grey),
        ],
      ),
    );
  }
}

/// Oculus 风格的 Hero 区域（横向滚动卡片）
class OculusHeroSection extends StatelessWidget {
  final List<Map<String, dynamic>> dailySongs;
  final List<Map<String, dynamic>> fmList;
  final VoidCallback? onOpenDailyDetail;

  const OculusHeroSection({
    super.key,
    required this.dailySongs,
    required this.fmList,
    this.onOpenDailyDetail,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        physics: const BouncingScrollPhysics(),
        children: [
          _OculusHeroCard(
            title: '每日推荐',
            subtitle: '根据你的品味精选',
            tracks: dailySongs,
            onTap: onOpenDailyDetail,
            gradient: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withBlue(255),
            ],
          ),
          if (fmList.isNotEmpty)
            _OculusHeroCard(
              title: '私人 FM',
              subtitle: '听见未知的惊喜',
              tracks: fmList,
              onTap: () async {
                final tracks = fmList.map((m) => _convertToTrack(m)).toList();
                if (tracks.isEmpty) return;
                PlaylistQueueService().setQueue(tracks, 0, QueueSource.playlist);
                await PlayerService().playTrack(tracks.first);
              },
              gradient: [
                const Color(0xFF6366F1),
                const Color(0xFFA855F7),
              ],
              isFm: true,
            ),
        ],
      ),
    );
  }

  Track _convertToTrack(Map<String, dynamic> song) {
    final album = (song['al'] ?? song['album'] ?? {}) as Map<String, dynamic>;
    final artists = (song['ar'] ?? song['artists'] ?? []) as List<dynamic>;
    return Track(
      id: song['id'] ?? 0,
      name: song['name']?.toString() ?? '',
      artists: artists.map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '').where((e) => e.isNotEmpty).join(' / '),
      album: album['name']?.toString() ?? '',
      picUrl: album['picUrl']?.toString() ?? '',
      source: MusicSource.netease,
    );
  }
}

class _OculusHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> tracks;
  final VoidCallback? onTap;
  final List<Color> gradient;
  final bool isFm;

  const _OculusHeroCard({
    required this.title,
    required this.subtitle,
    required this.tracks,
    this.onTap,
    required this.gradient,
    this.isFm = false,
  });

  @override
  Widget build(BuildContext context) {
    final coverImages = tracks.take(3).map((s) {
      final al = (s['al'] ?? s['album'] ?? {}) as Map<String, dynamic>;
      return (al['picUrl'] ?? '').toString();
    }).where((url) => url.isNotEmpty).toList();

    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                // 封面拼贴背景
                if (coverImages.isNotEmpty)
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Opacity(
                      opacity: 0.2,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Row(
                          children: coverImages.map((url) => Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                // 内容
                Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(
                          isFm ? 'PERSONAL FM' : 'DAILY MIX', // 修复拼写：PEERSONAL -> PERSONAL
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32, // 增大字体
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: gradient.first,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '立即播放',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OculusQuickActions extends StatelessWidget {
  const OculusQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickActionItem(
            icon: Icons.favorite,
            label: '我喜欢',
            color: Colors.red,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NeteaseLibraryPlaylistsPage()),
              );
            },
          ),
          _QuickActionItem(
            icon: Icons.album,
            label: '专辑',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NeteaseLibraryAlbumsPage()),
              );
            },
          ),
          _QuickActionItem(
            icon: Icons.person,
            label: '歌手',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NeteaseLibraryArtistsPage()),
              );
            },
          ),
          _QuickActionItem(
            icon: Icons.radio,
            label: '电台',
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NeteaseLibraryDjsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Oculus 风格的 Bento 网格布局（展示推荐歌单）
class OculusBentoGrid extends StatelessWidget {
  final List<Map<String, dynamic>> list;
  final void Function(int id)? onTap;
  
  const OculusBentoGrid({
    super.key,
    required this.list,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const SizedBox.shrink();

    // 只取前 6 个歌单组成 Bento 布局
    final items = list.take(6).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近精选',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final spacing = 16.0;

              return Column(
                children: [
                  // 第一行：一大一小
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _BentoItem(
                          item: items.isNotEmpty ? items[0] : null,
                          height: 200,
                          onTap: onTap,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        flex: 1,
                        child: _BentoItem(
                          item: items.length > 1 ? items[1] : null,
                          height: 200,
                          onTap: onTap,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing),
                  // 第二行：并排
                  Row(
                    children: [
                      Expanded(
                        child: _BentoItem(
                          item: items.length > 2 ? items[2] : null,
                          height: 140,
                          onTap: onTap,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _BentoItem(
                          item: items.length > 3 ? items[3] : null,
                          height: 140,
                          onTap: onTap,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing),
                  // 第三行：一涵盖两个
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _BentoItem(
                          item: items.length > 4 ? items[4] : null,
                          height: 160,
                          onTap: onTap,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        flex: 2,
                        child: _BentoItem(
                          item: items.length > 5 ? items[5] : null,
                          height: 160,
                          onTap: onTap,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BentoItem extends StatelessWidget {
  final Map<String, dynamic>? item;
  final double height;
  final void Function(int id)? onTap;

  const _BentoItem({this.item, required this.height, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (item == null) return const SizedBox.shrink();

    final pic = (item!['picUrl'] ?? item!['coverImgUrl'] ?? '').toString();
    final name = item!['name']?.toString() ?? '';
    final idVal = item!['id'];
    final id = int.tryParse(idVal?.toString() ?? '');

    return GestureDetector(
      onTap: id != null ? () => onTap?.call(id) : null,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surfaceContainer,
          image: pic.isNotEmpty 
              ? DecorationImage(
                  image: CachedNetworkImageProvider(pic),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.2),
                    BlendMode.darken,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.bottomLeft,
        child: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oculus 风格的新歌推荐组件（横向滚动卡片）
class OculusNewSongsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> list;

  const OculusNewSongsWidget({
    super.key,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final song = list[index];
          // 数据解析兼容
          final s = song['song'] ?? song;
          final al = (s['al'] ?? s['album'] ?? {}) as Map<String, dynamic>;
          final ar = (s['ar'] ?? s['artists'] ?? []) as List<dynamic>;
          final pic = (al['picUrl'] ?? '').toString();
          final name = s['name']?.toString() ?? '';
          final artists = ar.map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '').where((e) => e.isNotEmpty).join(' / ');

          return GestureDetector(
            onTap: () async {
               final track = _convertToTrack(s);
               // 简单的单曲播放逻辑，也可以扩展为播放列表
               await PlayerService().playTrack(track);
            },
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (pic.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: pic,
                              fit: BoxFit.cover,
                            ),
                          // 播放按钮遮罩
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 文字信息
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Track _convertToTrack(Map<String, dynamic> song) {
    final al = (song['al'] ?? song['album'] ?? {}) as Map<String, dynamic>;
    final ar = (song['ar'] ?? song['artists'] ?? []) as List<dynamic>;
    return Track(
      id: song['id'] ?? 0,
      name: song['name']?.toString() ?? '',
      artists: ar.map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '').where((e) => e.isNotEmpty).join(' / '),
      album: al['name']?.toString() ?? '',
      picUrl: al['picUrl']?.toString() ?? '',
      source: MusicSource.netease,
    );
  }
}
