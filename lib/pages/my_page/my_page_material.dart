part of 'my_page.dart';

/// Material UI 构建方法
extension MyPageMaterialUI on _MyPageState {
  Widget _buildMaterialPage(BuildContext context, ColorScheme colorScheme, bool isLoggedIn) {
    if (!isLoggedIn) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline, size: 80, color: colorScheme.primary),
              ),
              const SizedBox(height: 32),
              Text('发现你的音乐世界', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  '登录即可解锁个性化推荐、管理云端歌单并记录你的每一次聆听。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 16),
                ),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: () => showAuthDialog(context).then((_) { refresh(); }),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.login),
                label: const Text('立即开启'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedPlaylist != null) {
      return _buildMaterialPlaylistDetail(_selectedPlaylist!, colorScheme);
    }

    final user = AuthService().currentUser;

    return RefreshIndicator(
      onRefresh: () async {
        await _playlistService.loadPlaylists();
        await _loadStats();
      },
      child: Stack(
        children: [
          // 全局沉浸式背景
          Positioned.fill(
            child: user?.avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: user!.avatarUrl!,
                    fit: BoxFit.cover,
                  )
                : Container(color: colorScheme.surface),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.surface.withOpacity(0.2),
                      colorScheme.surface.withOpacity(0.6),
                      colorScheme.surface.withOpacity(0.8),
                      colorScheme.surface,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 沉浸式头部 - 背景设为透明，因为底层已有背景
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                  ],
                  background: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48), // 为状态栏和可能的返回键留出空间
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: colorScheme.secondaryContainer.withOpacity(0.5),
                          backgroundImage: user?.avatarUrl != null ? CachedNetworkImageProvider(user!.avatarUrl!) : null,
                          child: user?.avatarUrl == null ? Text(user?.username[0].toUpperCase() ?? '?', style: TextStyle(fontSize: 32, color: colorScheme.onSecondaryContainer)) : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user?.username ?? '未登录',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 核心统计磁贴
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildMaterialStatsTiles(colorScheme),
                ),
              ),

              // 歌单部分标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    children: [
                      Text('我的收藏', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: _showMusicTasteDialog,
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        tooltip: '品味总结',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _showImportPlaylistDialog,
                        icon: const Icon(Icons.cloud_download_outlined, size: 20),
                        tooltip: '导入',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _showCreatePlaylistDialog,
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: '新建',
                      ),
                    ],
                  ),
                ),
              ),

              // 歌单列表
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: _buildMaterialPlaylistsSliver(colorScheme),
              ),

              // 播放排行榜标题
              if (_statsData != null && _statsData!.playCounts.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text('播放排行 Top 10', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: _buildMaterialTopPlaysSliver(colorScheme),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialStatsTiles(ColorScheme colorScheme) {
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_statsData == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: _buildExpressiveStatTile(
            icon: Icons.access_time_filled,
            label: '聆听时长',
            value: ListeningStatsService.formatDuration(_statsData!.totalListeningTime),
            color: colorScheme.primary,
            onSurface: colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildExpressiveStatTile(
            icon: Icons.play_circle_filled,
            label: '播放次数',
            value: '${_statsData!.totalPlayCount}',
            color: colorScheme.tertiary,
            onSurface: colorScheme.onTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildExpressiveStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color onSurface,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 16),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color.withOpacity(0.7), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMaterialPlaylistsSliver(ColorScheme colorScheme) {
    final playlists = _playlistService.playlists;

    if (playlists.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Icon(Icons.library_music_outlined, size: 48, color: colorScheme.outline.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text('快去开启你的第一个歌单吧', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final playlist = playlists[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              leading: _buildMaterialPlaylistCover(playlist, colorScheme),
              title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${playlist.trackCount} 首歌曲', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert, size: 22),
                onPressed: () => _showPlaylistMoreOptions(playlist, colorScheme),
              ),
              onTap: () => _openPlaylistDetail(playlist),
            ),
          );
        },
        childCount: playlists.length,
      ),
    );
  }

  /// 显示歌单更多操作底板
  void _showPlaylistMoreOptions(Playlist playlist, ColorScheme colorScheme) {
    final canSync = _hasImportConfig(playlist);
    
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: colorScheme.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _buildMaterialPlaylistCover(playlist, colorScheme),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('${playlist.trackCount} 首歌曲', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(indent: 24, endIndent: 24),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('播放全部'),
              onTap: () {
                Navigator.pop(context);
                _openPlaylistDetail(playlist);
                // 等待加载完成后播放的逻辑通常在详情页，这里仅打开详情
              },
            ),
            ListTile(
              leading: Icon(Icons.sync, color: canSync ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(0.3)),
              title: const Text('同步歌单'),
              subtitle: canSync ? null : const Text('请先设置导入来源', style: TextStyle(fontSize: 10)),
              onTap: canSync ? () {
                Navigator.pop(context);
                _syncPlaylistFromList(playlist);
              } : null,
            ),
            if (!playlist.isDefault)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('删除歌单', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePlaylist(playlist);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTopPlaysSliver(ColorScheme colorScheme) {
    final topPlays = _statsData!.playCounts.take(10).toList();
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = topPlays[index];
          final rank = index + 1;
          Color? rankColor;
          if (rank == 1) rankColor = Colors.amber;
          else if (rank == 2) rankColor = Colors.grey.shade400;
          else if (rank == 3) rankColor = Colors.brown.shade300;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: item.picUrl, width: 56, height: 56, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 56, height: 56, color: colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                      errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                    ),
                  ),
                  Positioned(
                    left: 0, top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rankColor ?? colorScheme.primary.withOpacity(0.9),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                      ),
                      child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              title: Text(item.trackName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.artists, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item.playCount} 次', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  Text(item.toTrack().getSourceName(), style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              onTap: () => _playTrack(item),
            ),
          );
        },
        childCount: topPlays.length,
      ),
    );
  }

  Widget _buildMaterialPlaylistDetail(Playlist playlist, ColorScheme colorScheme) {
    final allTracks = _playlistService.currentPlaylistId == playlist.id ? _playlistService.currentTracks : <PlaylistTrack>[];
    final isLoading = _playlistService.isLoadingTracks;
    final filteredTracks = _filterTracks(allTracks);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildMaterialDetailAppBar(playlist, colorScheme, allTracks),
          if (_isSearchMode) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: _buildMaterialSearchField(colorScheme))),
          if (isLoading && allTracks.isEmpty)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (allTracks.isEmpty)
            SliverFillRemaining(child: _buildMaterialDetailEmptyState(colorScheme))
          else if (filteredTracks.isEmpty && _searchQuery.isNotEmpty)
            SliverFillRemaining(child: _buildMaterialSearchEmptyState(colorScheme))
          else ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16.0), child: _buildMaterialDetailStatsCard(colorScheme, filteredTracks.length, totalCount: allTracks.length))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final track = filteredTracks[index];
                final originalIndex = allTracks.indexOf(track);
                return _buildMaterialTrackItem(track, originalIndex, colorScheme);
              }, childCount: filteredTracks.length)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialSearchField(ColorScheme colorScheme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '搜索歌曲、歌手、专辑...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _onSearchChanged(''); }) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: _onSearchChanged,
      autofocus: true,
    );
  }

  Widget _buildMaterialSearchEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('未找到匹配的歌曲', style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 8),
          Text('尝试其他关键词', style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildMaterialDetailAppBar(Playlist playlist, ColorScheme colorScheme, List<PlaylistTrack> tracks) {
    return SliverAppBar(
      floating: true, snap: true,
      backgroundColor: colorScheme.surface,
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _backToList),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEditMode ? '已选择 ${_selectedTrackIds.length} 首' : playlist.name, style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
          if (!_isEditMode && playlist.isDefault) Text('默认歌单', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
      actions: [
        if (_isEditMode) ...[
          IconButton(icon: Icon(_selectedTrackIds.length == tracks.length ? Icons.check_box : Icons.check_box_outline_blank), onPressed: tracks.isNotEmpty ? _toggleSelectAll : null, tooltip: _selectedTrackIds.length == tracks.length ? '取消全选' : '全选'),
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _selectedTrackIds.isNotEmpty ? _batchRemoveTracks : null, tooltip: '删除选中'),
          TextButton(onPressed: _toggleEditMode, child: const Text('取消')),
        ] else ...[
          if (tracks.isNotEmpty) IconButton(icon: Icon(_isSearchMode ? Icons.search_off : Icons.search), onPressed: _toggleSearchMode, tooltip: _isSearchMode ? '关闭搜索' : '搜索歌曲'),
          if (tracks.isNotEmpty) IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () => _showSourceSwitchDialog(playlist, tracks), tooltip: '换源'),
          if (tracks.isNotEmpty) IconButton(icon: const Icon(Icons.edit), onPressed: _toggleEditMode, tooltip: '批量管理'),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              if (!_hasImportConfig(playlist)) {
                _showUserNotification('请先在"导入管理"中绑定来源后再同步', severity: fluent.InfoBarSeverity.warning);
                return;
              }
              _showUserNotification('正在同步...', duration: const Duration(seconds: 1));
              final result = await _playlistService.syncPlaylist(playlist.id);
              _showUserNotification(_formatSyncResultMessage(result), severity: result.insertedCount > 0 ? fluent.InfoBarSeverity.success : fluent.InfoBarSeverity.info);
              await _playlistService.loadPlaylistTracks(playlist.id);
            },
            tooltip: '同步',
          ),
        ],
      ],
    );
  }

  Widget _buildMaterialDetailStatsCard(ColorScheme colorScheme, int count, {int? totalCount}) {
    final String countText = (totalCount != null && totalCount != count) ? '筛选出 $count / 共 $totalCount 首歌曲' : '共 $count 首歌曲';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.music_note, size: 24, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(countText, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (count > 0) FilledButton.icon(onPressed: _playAll, icon: const Icon(Icons.play_arrow, size: 20), label: const Text('播放全部')),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialDetailEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('歌单为空', style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 8),
          Text('快去添加一些喜欢的歌曲吧', style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildMaterialTrackItem(PlaylistTrack item, int index, ColorScheme colorScheme) {
    final trackKey = _getTrackKey(item);
    final isSelected = _selectedTrackIds.contains(trackKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected && _isEditMode ? colorScheme.primaryContainer.withOpacity(0.3) : null,
      child: ListTile(
        leading: _isEditMode
            ? Checkbox(value: isSelected, onChanged: (_) => _toggleTrackSelection(item))
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: item.picUrl, width: 50, height: 50, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 50, height: 50, color: colorScheme.surfaceContainerHighest),
                      errorWidget: (_, __, ___) => Container(width: 50, height: 50, color: colorScheme.surfaceContainerHighest),
                    ),
                  ),
                  Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4))), child: Text('#${index + 1}', style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 10, fontWeight: FontWeight.bold)))),
                ],
              ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${item.artists} • ${item.album}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        trailing: _isEditMode ? null : const SizedBox.shrink(),
        onTap: _isEditMode ? () => _toggleTrackSelection(item) : () => _playDetailTrack(index),
      ),
    );
  }

  Widget _buildMaterialUserCard(ColorScheme colorScheme) {
    final user = AuthService().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: user.avatarUrl != null ? CachedNetworkImageProvider(user.avatarUrl!) : null,
              child: user.avatarUrl == null ? Text(user.username[0].toUpperCase(), style: const TextStyle(fontSize: 24)) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(user.email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialPlaylistCover(Playlist playlist, ColorScheme colorScheme) {
    if (playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: playlist.coverUrl!,
          width: 56, height: 56, fit: BoxFit.cover,
          placeholder: (_, __) => Container(width: 56, height: 56, decoration: BoxDecoration(color: playlist.isDefault ? colorScheme.primaryContainer : colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(playlist.isDefault ? Icons.favorite : Icons.library_music, color: playlist.isDefault ? Colors.red : colorScheme.primary)),
          errorWidget: (_, __, ___) => Container(width: 56, height: 56, decoration: BoxDecoration(color: playlist.isDefault ? colorScheme.primaryContainer : colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(playlist.isDefault ? Icons.favorite : Icons.library_music, color: playlist.isDefault ? Colors.red : colorScheme.primary)),
        ),
      );
    }
    return Container(width: 56, height: 56, decoration: BoxDecoration(color: playlist.isDefault ? colorScheme.primaryContainer : colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(playlist.isDefault ? Icons.favorite : Icons.library_music, color: playlist.isDefault ? Colors.red : colorScheme.primary));
  }
}

