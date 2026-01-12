import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'url_service.dart';
import 'auth_service.dart';

/// 用户歌曲回忆坐标服务
/// 获取用户对特定歌曲的首次播放时间和累计播放次数
class SongMemoryService extends ChangeNotifier {
  static final SongMemoryService _instance = SongMemoryService._internal();
  factory SongMemoryService() => _instance;
  SongMemoryService._internal();

  /// 获取用户对特定歌曲的回忆坐标
  /// 返回 { firstPlayedAt, playCount, lastPlayedAt }
  Future<Map<String, dynamic>?> fetchSongMemory(dynamic trackId, String source) async {
    try {
      // 检查用户是否已登录
      final token = AuthService().token;
      if (token == null || token.isEmpty) {
        debugPrint('[SongMemoryService] 用户未登录，无法获取回忆坐标');
        return null;
      }

      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/stats/song-memory?trackId=$trackId&source=$source';
      
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (resp.statusCode != 200) return null;
      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 200) return null;
      return data['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ [SongMemoryService] 获取回忆坐标失败: $e');
      return null;
    }
  }
}
