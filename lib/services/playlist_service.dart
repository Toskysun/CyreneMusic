import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/playlist.dart';
import '../models/track.dart';
import 'auth_service.dart';
import 'url_service.dart';

class PlaylistSyncResult {
  final int insertedCount;
  final List<PlaylistTrack> newTracks;
  final String message;

  const PlaylistSyncResult({
    required this.insertedCount,
    required this.newTracks,
    this.message = '',
  });

  factory PlaylistSyncResult.empty({String message = ''}) {
    return PlaylistSyncResult(
      insertedCount: 0,
      newTracks: const <PlaylistTrack>[],
      message: message,
    );
  }

  bool get hasUpdates => insertedCount > 0;
}

/// 歌单服务
class PlaylistService extends ChangeNotifier {
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal() {
    // 监听登录状态变化
    AuthService().addListener(_onAuthChanged);
  }

  /// 更新歌单导入配置
  Future<bool> updateImportConfig(int playlistId, {
    required String source,
    required String sourcePlaylistId,
  }) async {
    if (!AuthService().isLoggedIn) return false;
    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token!;
      final resp = await http.put(
        Uri.parse('$baseUrl/playlists/$playlistId/import-config'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'source': source,
          'sourcePlaylistId': sourcePlaylistId,
        }),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final idx = _playlists.indexWhere((p) => p.id == playlistId);
        if (idx != -1) {
          final p = _playlists[idx];
          _playlists[idx] = Playlist(
            id: p.id,
            name: p.name,
            isDefault: p.isDefault,
            trackCount: p.trackCount,
            createdAt: p.createdAt,
            updatedAt: DateTime.now(),
            source: source,
            sourcePlaylistId: sourcePlaylistId,
          );
          notifyListeners();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// 触发服务端同步
  Future<PlaylistSyncResult> syncPlaylist(int playlistId) async {
    if (!AuthService().isLoggedIn) return PlaylistSyncResult.empty();
    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token!;
      final url = '$baseUrl/playlists/$playlistId/sync';
      print('🚀 [PlaylistService] 同步开始: $url (playlistId=$playlistId)');
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(minutes: 2));
      print('📥 [PlaylistService] 同步响应: status=${resp.statusCode}');
      if (resp.body.isNotEmpty) {
        print('📄 [PlaylistService] 响应内容: ${resp.body}');
      }
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        if ((data['status'] as int?) != 200) {
          final failureMessage = data['message'] as String? ?? '同步失败';
          print('⚠️ [PlaylistService] 同步失败: $failureMessage');
          return PlaylistSyncResult.empty(message: failureMessage);
        }
        final inserted = data['insertedCount'] as int? ?? 0;
        final newTracks = (data['newTracks'] as List<dynamic>? ?? [])
            .map((item) => PlaylistTrack.fromJson(item as Map<String, dynamic>))
            .toList();
        final message = data['message'] as String? ?? '同步完成';
        print('✅ [PlaylistService] 同步完成，新增 $inserted 首');
        if (inserted > 0) {
          _applySyncUpdates(playlistId, inserted, newTracks);
        }
        return PlaylistSyncResult(
          insertedCount: inserted,
          newTracks: newTracks,
          message: message,
        );
      } else if (resp.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        await AuthService().handleUnauthorized();
        return PlaylistSyncResult.empty(message: '未登录或登录已过期');
      }
      print('⚠️ [PlaylistService] 同步失败: HTTP ${resp.statusCode}');
    } catch (e) {
      print('❌ [PlaylistService] 同步异常: $e');
      return PlaylistSyncResult.empty(message: '同步失败: $e');
    }
    return PlaylistSyncResult.empty(message: '同步失败');
  }

  void _applySyncUpdates(int playlistId, int inserted, List<PlaylistTrack> newTracks) {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final playlist = _playlists[idx];
      _playlists[idx] = Playlist(
        id: playlist.id,
        name: playlist.name,
        isDefault: playlist.isDefault,
        trackCount: playlist.trackCount + inserted,
        createdAt: playlist.createdAt,
        updatedAt: DateTime.now(),
        source: playlist.source,
        sourcePlaylistId: playlist.sourcePlaylistId,
      );
    }

    if (_currentPlaylistId == playlistId && newTracks.isNotEmpty) {
      _currentTracks = [...newTracks, ..._currentTracks];
    }

    notifyListeners();
  }

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  // 当前选中的歌单 ID
  int? _currentPlaylistId;
  int? get currentPlaylistId => _currentPlaylistId;

  // 当前歌单的歌曲列表
  List<PlaylistTrack> _currentTracks = [];
  List<PlaylistTrack> get currentTracks => _currentTracks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingTracks = false;
  bool get isLoadingTracks => _isLoadingTracks;

  /// 监听认证状态变化
  void _onAuthChanged() {
    if (!AuthService().isLoggedIn) {
      // 用户登出时清空数据
      clear();
    }
  }

  /// 清空所有数据
  void clear() {
    _playlists = [];
    _currentPlaylistId = null;
    _currentTracks = [];
    notifyListeners();
  }

  /// 获取默认歌单（我的收藏）
  Playlist? get defaultPlaylist {
    return _playlists.firstWhere(
      (p) => p.isDefault,
      orElse: () => _playlists.isNotEmpty ? _playlists.first : Playlist(
        id: 0,
        name: '我的收藏',
        isDefault: true,
        trackCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// 加载歌单列表
  Future<void> loadPlaylists() async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法加载歌单');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token;
      if (token == null) {
        throw Exception('无有效令牌');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/playlists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          final List<dynamic> playlistsJson = data['playlists'] ?? [];
          _playlists = playlistsJson
              .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
              .toList();

          print('✅ [PlaylistService] 加载歌单列表: ${_playlists.length} 个');
        } else {
          throw Exception(data['message'] ?? '加载失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        await AuthService().handleUnauthorized();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 加载歌单列表失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建新歌单
  Future<bool> createPlaylist(String name) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法创建歌单');
      return false;
    }

    if (name.trim().isEmpty) {
      print('⚠️ [PlaylistService] 歌单名称不能为空');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token;
      if (token == null) {
        throw Exception('无有效令牌');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/playlists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'name': name.trim()}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 添加到本地列表
          final newPlaylist = Playlist.fromJson(data['playlist'] as Map<String, dynamic>);
          _playlists.add(newPlaylist);

          print('✅ [PlaylistService] 创建歌单成功: $name');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '创建失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        await AuthService().handleUnauthorized();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 创建歌单失败: $e');
      return false;
    }
  }

  /// 更新歌单（重命名）
  Future<bool> updatePlaylist(int playlistId, String name) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法更新歌单');
      return false;
    }

    if (name.trim().isEmpty) {
      print('⚠️ [PlaylistService] 歌单名称不能为空');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token;
      if (token == null) {
        throw Exception('无有效令牌');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/playlists/$playlistId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'name': name.trim()}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 更新本地列表
          final index = _playlists.indexWhere((p) => p.id == playlistId);
          if (index != -1) {
            _playlists[index] = Playlist(
              id: _playlists[index].id,
              name: name.trim(),
              isDefault: _playlists[index].isDefault,
              trackCount: _playlists[index].trackCount,
              createdAt: _playlists[index].createdAt,
              updatedAt: DateTime.now(),
              source: _playlists[index].source,
              sourcePlaylistId: _playlists[index].sourcePlaylistId,
            );
          }

          print('✅ [PlaylistService] 更新歌单成功: $name');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '更新失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 更新歌单失败: $e');
      return false;
    }
  }

  /// 删除歌单
  Future<bool> deletePlaylist(int playlistId) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法删除歌单');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token;
      if (token == null) {
        throw Exception('无有效令牌');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/playlists/$playlistId/delete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        // Bun/Elysia 在检测到 Content-Type: application/json 时会尝试解析请求体，
        // 即使是删除歌单这种无参数请求。传入空 JSON 保证解析阶段不会抛出 PARSE 错误。
        body: json.encode({}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 从本地列表删除
          _playlists.removeWhere((p) => p.id == playlistId);

          // 如果删除的是当前选中的歌单，清空当前歌曲列表
          if (_currentPlaylistId == playlistId) {
            _currentPlaylistId = null;
            _currentTracks = [];
          }

          print('✅ [PlaylistService] 删除歌单成功');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '删除失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 删除歌单失败: $e');
      return false;
    }
  }

  /// 添加歌曲到歌单
  Future<bool> addTrackToPlaylist(int playlistId, Track track) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法添加歌曲');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token;
      if (token == null) {
        throw Exception('无有效令牌');
      }
      final playlistTrack = PlaylistTrack.fromTrack(track);

      final response = await http.post(
        Uri.parse('$baseUrl/playlists/$playlistId/tracks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(playlistTrack.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 更新歌单的歌曲数量
          final index = _playlists.indexWhere((p) => p.id == playlistId);
          if (index != -1) {
            _playlists[index] = Playlist(
              id: _playlists[index].id,
              name: _playlists[index].name,
              isDefault: _playlists[index].isDefault,
              trackCount: _playlists[index].trackCount + 1,
              createdAt: _playlists[index].createdAt,
              updatedAt: DateTime.now(),
              source: _playlists[index].source,
              sourcePlaylistId: _playlists[index].sourcePlaylistId,
            );
          }

          // 如果是当前选中的歌单，添加到当前列表
          if (_currentPlaylistId == playlistId) {
            _currentTracks.insert(0, playlistTrack);
          }

          print('✅ [PlaylistService] 添加歌曲成功: ${track.name}');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '添加失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 添加歌曲失败: $e');
      return false;
    }
  }

  /// 加载歌单中的歌曲
  Future<void> loadPlaylistTracks(int playlistId) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法加载歌曲');
      return;
    }

    try {
      _isLoadingTracks = true;
      _currentPlaylistId = playlistId;
      notifyListeners();

      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token;
      if (token == null) {
        throw Exception('无有效令牌');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/playlists/$playlistId/tracks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          final List<dynamic> tracksJson = data['tracks'] ?? [];
          _currentTracks = tracksJson
              .map((item) => PlaylistTrack.fromJson(item as Map<String, dynamic>))
              .toList();

          print('✅ [PlaylistService] 加载歌曲列表: ${_currentTracks.length} 首');
        } else {
          throw Exception(data['message'] ?? '加载失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 加载歌曲列表失败: $e');
    } finally {
      _isLoadingTracks = false;
      notifyListeners();
    }
  }

  /// 从歌单删除歌曲
  Future<bool> removeTrackFromPlaylist(int playlistId, PlaylistTrack track) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法删除歌曲');
      return false;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token;
      if (token == null) {
        throw Exception('无有效令牌');
      }
      final source = track.source.toString().split('.').last;
      
      // 诊断日志
      print('🗑️ [PlaylistService] 准备删除歌曲:');
      print('   PlaylistId: $playlistId');
      print('   TrackId: ${track.trackId}');
      print('   Source: $source');
      print('   URL: $baseUrl/playlists/$playlistId/tracks/remove');

      // 使用 POST 请求代替 DELETE（避免某些框架的解析问题）
      final response = await http.post(
        Uri.parse('$baseUrl/playlists/$playlistId/tracks/remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'trackId': track.trackId,
          'source': source,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('请求超时'),
      );
      
      print('📥 [PlaylistService] 删除请求响应状态码: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('📄 [PlaylistService] 响应内容: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          // 更新歌单的歌曲数量
          final index = _playlists.indexWhere((p) => p.id == playlistId);
          if (index != -1) {
            _playlists[index] = Playlist(
              id: _playlists[index].id,
              name: _playlists[index].name,
              isDefault: _playlists[index].isDefault,
              trackCount: _playlists[index].trackCount - 1,
              createdAt: _playlists[index].createdAt,
              updatedAt: DateTime.now(),
              source: _playlists[index].source,
              sourcePlaylistId: _playlists[index].sourcePlaylistId,
            );
          }

          // 从当前列表删除
          if (_currentPlaylistId == playlistId) {
            _currentTracks.removeWhere((t) => 
              t.trackId == track.trackId && t.source == track.source
            );
          }

          print('✅ [PlaylistService] 删除歌曲成功');
          notifyListeners();
          return true;
        } else {
          throw Exception(data['message'] ?? '删除失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        AuthService().logout();
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 删除歌曲失败: $e');
      return false;
    }
  }

  /// 批量删除歌曲
  Future<int> removeTracksFromPlaylist(int playlistId, List<PlaylistTrack> tracks) async {
    if (!AuthService().isLoggedIn) {
      print('⚠️ [PlaylistService] 未登录，无法批量删除歌曲');
      return 0;
    }

    if (tracks.isEmpty) {
      print('⚠️ [PlaylistService] 歌曲列表为空');
      return 0;
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token;
      if (token == null) {
        throw Exception('无有效令牌');
      }

      // 构建删除列表
      final tracksToDelete = tracks.map((track) => {
        'trackId': track.trackId,
        'source': track.source.toString().split('.').last,
      }).toList();

      print('🗑️ [PlaylistService] 准备批量删除 ${tracks.length} 首歌曲');

      final response = await http.post(
        Uri.parse('$baseUrl/playlists/$playlistId/tracks/batch-remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'tracks': tracksToDelete,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('请求超时'),
      );

      print('📥 [PlaylistService] 批量删除响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        if (data['status'] == 200) {
          final deletedCount = data['deletedCount'] as int? ?? 0;

          // 更新歌单的歌曲数量
          final index = _playlists.indexWhere((p) => p.id == playlistId);
          if (index != -1) {
            _playlists[index] = Playlist(
              id: _playlists[index].id,
              name: _playlists[index].name,
              isDefault: _playlists[index].isDefault,
              trackCount: _playlists[index].trackCount - deletedCount,
              createdAt: _playlists[index].createdAt,
              updatedAt: DateTime.now(),
              source: _playlists[index].source,
              sourcePlaylistId: _playlists[index].sourcePlaylistId,
            );
          }

          // 从当前列表批量删除
          if (_currentPlaylistId == playlistId) {
            for (var track in tracks) {
              _currentTracks.removeWhere((t) => 
                t.trackId == track.trackId && t.source == track.source
              );
            }
          }

          print('✅ [PlaylistService] 批量删除成功: $deletedCount 首');
          notifyListeners();
          return deletedCount;
        } else {
          throw Exception(data['message'] ?? '批量删除失败');
        }
      } else if (response.statusCode == 401) {
        print('⚠️ [PlaylistService] 未授权，需要重新登录');
        await AuthService().handleUnauthorized();
        return 0;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PlaylistService] 批量删除失败: $e');
      return 0;
    }
  }

  /// 检查歌曲是否在指定歌单中
  bool isTrackInPlaylist(int playlistId, Track track) {
    if (_currentPlaylistId != playlistId) {
      return false;
    }
    return _currentTracks.any((t) => 
      t.trackId == track.id.toString() && t.source == track.source
    );
  }

  /// 检查歌曲是否在用户的任何歌单中（调用后端 API）
  Future<TrackInPlaylistResult> isTrackInAnyPlaylist(Track track) async {
    if (!AuthService().isLoggedIn) {
      return TrackInPlaylistResult(inPlaylist: false, playlistIds: [], playlistNames: []);
    }

    try {
      final baseUrl = UrlService().baseUrl;
      final token = AuthService().token!;
      final trackId = track.id.toString();
      final source = track.source.name;
      
      final response = await http.get(
        Uri.parse('$baseUrl/playlists/check-track?trackId=$trackId&source=$source'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return TrackInPlaylistResult(
          inPlaylist: data['inPlaylist'] as bool? ?? false,
          playlistIds: (data['playlistIds'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
          playlistNames: (data['playlistNames'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        );
      } else if (response.statusCode == 401) {
        await AuthService().handleUnauthorized();
      }
    } catch (e) {
      print('❌ [PlaylistService] 检查歌曲是否在歌单中失败: $e');
    }
    
    return TrackInPlaylistResult(inPlaylist: false, playlistIds: [], playlistNames: []);
  }
}

/// 歌曲在歌单中的检查结果
class TrackInPlaylistResult {
  final bool inPlaylist;
  final List<int> playlistIds;
  final List<String> playlistNames;

  TrackInPlaylistResult({
    required this.inPlaylist,
    required this.playlistIds,
    required this.playlistNames,
  });
}

