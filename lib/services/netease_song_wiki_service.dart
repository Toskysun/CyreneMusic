import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'url_service.dart';

/// 网易云歌曲百科及元数据服务
class NeteaseSongWikiService extends ChangeNotifier {
  static final NeteaseSongWikiService _instance = NeteaseSongWikiService._internal();
  factory NeteaseSongWikiService() => _instance;
  NeteaseSongWikiService._internal();

  /// 获取歌曲百科摘要 (Wiki Summary)
  /// 包含：曲风、语种、发行时间、简介等
  Future<Map<String, dynamic>?> fetchSongWiki(dynamic id) async {
    try {
      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/song/wiki/summary?id=$id';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['status'] != 200) return null;
      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [SongWikiService] 获取百科失败: $e');
      return null;
    }
  }

  /// 获取歌曲音轨详细信息 (Music Detail)
  /// 包含：BPM、能量值、情感倾向等
  Future<Map<String, dynamic>?> fetchSongMusicDetail(dynamic id) async {
    try {
      final baseUrl = UrlService().baseUrl;
      final url = '$baseUrl/song/music/detail/get?id=$id';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['status'] != 200) return null;
      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [SongWikiService] 获取歌曲元数据失败: $e');
      return null;
    }
  }
}
