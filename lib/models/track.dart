/// 音乐平台枚举
enum MusicSource {
  netease,  // 网易云音乐
  qq,       // QQ音乐
  kugou,    // 酷狗音乐
  kuwo,     // 酷我音乐
  apple,    // Apple Music
  spotify,  // Spotify
  local,    // 本地文件
}

/// 歌曲模型
class Track {
  final dynamic id;  // 支持 int 和 String 类型（网易云用int，QQ和酷狗用String）
  final String name;
  final String artists;
  final String album;
  final String picUrl;
  final MusicSource source;

  Track({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.picUrl,
    this.source = MusicSource.netease, // 默认网易云音乐
  });

  /// 从 JSON 创建 Track 对象
  factory Track.fromJson(Map<String, dynamic> json, {MusicSource? source}) {
    MusicSource? effectiveSource = source;
    
    // 如果 JSON 中包含 source 字符串，优先使用它
    if (json.containsKey('source') && json['source'] is String) {
      final sourceStr = json['source'] as String;
      effectiveSource = MusicSource.values.firstWhere(
        (e) => e.name == sourceStr,
        orElse: () => source ?? MusicSource.netease,
      );
    }

    return Track(
      id: json['id'], // 可以是 int 或 String
      name: json['name'] as String? ?? '',
      artists: json['artists'] as String? ?? '',
      album: json['album'] as String? ?? '',
      picUrl: json['picUrl'] as String? ?? '',
      source: effectiveSource ?? MusicSource.netease,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artists': artists,
      'album': album,
      'picUrl': picUrl,
      'source': source.name,
    };
  }

  /// 获取音乐来源的中文名称
  String getSourceName() {
    switch (source) {
      case MusicSource.netease:
        return '网易云音乐';
      case MusicSource.qq:
        return 'QQ音乐';
      case MusicSource.kugou:
        return '酷狗音乐';
      case MusicSource.kuwo:
        return '酷我音乐';
      case MusicSource.apple:
        return 'Apple Music';
      case MusicSource.spotify:
        return 'Spotify';
      case MusicSource.local:
        return '本地';
    }
  }

  /// 获取音乐来源的图标
  String getSourceIcon() {
    switch (source) {
      case MusicSource.netease:
        return '🎵';
      case MusicSource.qq:
        return '🎶';
      case MusicSource.kugou:
        return '🎼';
      case MusicSource.kuwo:
        return '🎸';
      case MusicSource.apple:
        return '🍎';
      case MusicSource.spotify:
        return '🟢';
      case MusicSource.local:
        return '📁';
    }
  }
}

