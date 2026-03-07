import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ImageProvider;
import '../models/track.dart';
import 'persistent_storage_service.dart';

/// 播放队列来源
enum QueueSource {
  none,        // 无队列
  favorites,   // 收藏列表
  playlist,    // 歌单
  history,     // 播放历史
  search,      // 搜索结果
  toplist,     // 排行榜
}

/// 播放队列服务 - 管理当前播放列表
class PlaylistQueueService extends ChangeNotifier {
  static final PlaylistQueueService _instance = PlaylistQueueService._internal();
  factory PlaylistQueueService() => _instance;
  PlaylistQueueService._internal();

  List<Track> _queue = [];
  int _currentIndex = -1;
  QueueSource _source = QueueSource.none;
  final Map<String, ImageProvider> _coverProviders = {};
  
  // 随机播放相关
  List<int> _shuffledIndices = [];  // 洗牌后的索引顺序
  int _shufflePosition = -1;        // 当前在洗牌序列中的位置
  final Random _random = Random();

  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  String _coverKey(Track track) => '${track.source.name}_${track.id}';

  ImageProvider? getCoverProvider(Track track) {
    return _coverProviders[_coverKey(track)] ??
        (track.picUrl.isNotEmpty ? _coverProviders[track.picUrl] : null);
  }

  void updateCoverProvider(Track track, ImageProvider provider) {
    _coverProviders[_coverKey(track)] = provider;
    if (track.picUrl.isNotEmpty) {
      _coverProviders[track.picUrl] = provider;
    }
  }

  void updateCoverProviders(Map<String, ImageProvider> providers) {
    _coverProviders.addAll(providers);
  }

  QueueSource get source => _source;
  bool get hasQueue => _queue.isNotEmpty;

  /// 设置播放队列
  void setQueue(
    List<Track> tracks,
    int startIndex,
    QueueSource source, {
    Map<String, ImageProvider>? coverProviders,
  }) {
    _queue = List.from(tracks);
    _currentIndex = startIndex;
    _source = source;
    _coverProviders
      ..clear()
      ..addAll(coverProviders ?? {});
    
    // 重置洗牌序列，下次随机播放时会重新生成
    _shuffledIndices.clear();
    _shufflePosition = -1;
    
    print('🎵 [PlaylistQueueService] 设置播放队列: ${_queue.length} 首歌曲, 来源: ${source.name}, 当前索引: $startIndex');
    notifyListeners();
  }

  /// 播放指定曲目（更新当前索引）
  void playTrack(Track track) {
    final index = _queue.indexWhere(
      (t) => t.id.toString() == track.id.toString() && t.source == track.source
    );
    
    if (index != -1) {
      _currentIndex = index;
      print('🎵 [PlaylistQueueService] 切换到队列中的歌曲: ${track.name}, 索引: $index');
      notifyListeners();
    } else {
      print('⚠️ [PlaylistQueueService] 歌曲不在当前队列中: ${track.name}');
    }
  }

  /// 获取下一首歌曲
  Track? getNext() {
    if (_queue.isEmpty) {
      return null;
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex < _queue.length) {
      _currentIndex = nextIndex;
      print('⏭️ [PlaylistQueueService] 下一首: ${_queue[_currentIndex].name}');
      notifyListeners();
      return _queue[_currentIndex];
    }

    print('⚠️ [PlaylistQueueService] 已经是队列最后一首');
    return null;
  }

  /// 获取上一首歌曲
  Track? getPrevious() {
    if (_queue.isEmpty) {
      return null;
    }

    final prevIndex = _currentIndex - 1;
    if (prevIndex >= 0) {
      _currentIndex = prevIndex;
      print('⏮️ [PlaylistQueueService] 上一首: ${_queue[_currentIndex].name}');
      notifyListeners();
      return _queue[_currentIndex];
    }

    print('⚠️ [PlaylistQueueService] 已经是队列第一首');
    return null;
  }

  /// 检查是否有下一首
  bool get hasNext => _queue.isNotEmpty && _currentIndex < _queue.length - 1;

  /// 检查是否有上一首
  bool get hasPrevious => _queue.isNotEmpty && _currentIndex > 0;

  /// 生成洗牌序列（Fisher-Yates 算法）
  void _generateShuffledIndices() {
    _shuffledIndices = List.generate(_queue.length, (i) => i);
    
    // Fisher-Yates 洗牌算法
    for (int i = _shuffledIndices.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = _shuffledIndices[i];
      _shuffledIndices[i] = _shuffledIndices[j];
      _shuffledIndices[j] = temp;
    }
    
    // 确保当前歌曲不是洗牌后的第一首（避免连续播放同一首）
    if (_currentIndex >= 0 && _shuffledIndices.isNotEmpty && _shuffledIndices[0] == _currentIndex) {
      // 将当前歌曲移到后面
      final swapIndex = _random.nextInt(_shuffledIndices.length - 1) + 1;
      final temp = _shuffledIndices[0];
      _shuffledIndices[0] = _shuffledIndices[swapIndex];
      _shuffledIndices[swapIndex] = temp;
    }
    
    _shufflePosition = -1;
    print('🔀 [PlaylistQueueService] 生成新的洗牌序列，共 ${_shuffledIndices.length} 首');
  }

  /// 预测下一首歌曲（不改变当前索引）
  /// [mode] 播放模式
  Track? peekNext(dynamic mode) {
    if (_queue.isEmpty) return null;

    final modeStr = mode.toString();
    
    // 单曲循环：下一首还是当前首
    if (modeStr.contains('repeatOne')) {
      return _currentIndex >= 0 ? _queue[_currentIndex] : null;
    }

    // 随机播放
    if (modeStr.contains('shuffle')) {
      // 如果还没有生成过洗牌序列，无法预测
      if (_shuffledIndices.isEmpty) return null;
      
      final nextShufflePos = _shufflePosition + 1;
      if (nextShufflePos < _shuffledIndices.length) {
        return _queue[_shuffledIndices[nextShufflePos]];
      }
      // 如果播到底了，下一首是重新洗牌后的第一位（通常无法精准预测，返回第一首作为兜底）
      return _queue[_shuffledIndices[0]];
    }

    // 顺序播放
    final nextIndex = _currentIndex + 1;
    if (nextIndex < _queue.length) {
      return _queue[nextIndex];
    }
    
    // 列表循环：如果到了最后，下一首是第一首
    return _queue[0];
  }

  /// 预测上一首歌曲（不改变当前索引）
  Track? peekPrevious(dynamic mode) {
    if (_queue.isEmpty) return null;

    final modeStr = mode.toString();

    // 随机播放
    if (modeStr.contains('shuffle')) {
      if (_shuffledIndices.isEmpty || _shufflePosition <= 0) return null;
      return _queue[_shuffledIndices[_shufflePosition - 1]];
    }

    // 顺序播放
    final prevIndex = _currentIndex - 1;
    if (prevIndex >= 0) {
      return _queue[prevIndex];
    }
    
    // 列表循环
    return _queue[_queue.length - 1];
  }

  /// 获取随机歌曲（用于随机播放）
  /// 使用洗牌算法确保每首歌只播放一次，直到全部播放完毕
  Track? getRandomTrack() {
    if (_queue.isEmpty) {
      return null;
    }

    // 如果洗牌序列为空或已播放完毕，重新生成
    if (_shuffledIndices.isEmpty || _shufflePosition >= _shuffledIndices.length - 1) {
      _generateShuffledIndices();
    }
    
    // 移动到下一个位置
    _shufflePosition++;
    _currentIndex = _shuffledIndices[_shufflePosition];
    
    final track = _queue[_currentIndex];
    print('🔀 [PlaylistQueueService] 随机播放 (${_shufflePosition + 1}/${_shuffledIndices.length}): ${track.name}');
    notifyListeners();
    return track;
  }
  
  /// 获取随机播放的上一首
  Track? getRandomPrevious() {
    if (_queue.isEmpty || _shuffledIndices.isEmpty) {
      return null;
    }
    
    if (_shufflePosition <= 0) {
      print('⚠️ [PlaylistQueueService] 随机播放已经是第一首');
      return null;
    }
    
    _shufflePosition--;
    _currentIndex = _shuffledIndices[_shufflePosition];
    
    final track = _queue[_currentIndex];
    print('🔀 [PlaylistQueueService] 随机播放上一首 (${_shufflePosition + 1}/${_shuffledIndices.length}): ${track.name}');
    notifyListeners();
    return track;
  }
  
  /// 重置洗牌序列（当队列变化或切换播放模式时调用）
  void resetShuffle() {
    _shuffledIndices.clear();
    _shufflePosition = -1;
    print('🔀 [PlaylistQueueService] 重置洗牌序列');
  }

  /// 清空播放队列
  void clear() {
    _queue.clear();
    _currentIndex = -1;
    _source = QueueSource.none;
    _coverProviders.clear();
    _shuffledIndices.clear();
    _shufflePosition = -1;
    print('🗑️ [PlaylistQueueService] 清空播放队列');
    notifyListeners();
  }

  /// 导出队列数据为 JSON
  Map<String, dynamic> exportQueue() {
    return {
      'queue': _queue.map((t) => t.toJson()).toList(),
      'currentIndex': _currentIndex,
      'source': _source.index,
    };
  }

  /// 从 JSON 导入队列数据
  void importQueue(Map<String, dynamic> data) {
    try {
      final List<dynamic> tracksJson = data['queue'] as List<dynamic>;
      _queue = tracksJson.map((t) => Track.fromJson(t as Map<String, dynamic>)).toList();
      _currentIndex = data['currentIndex'] as int;
      final sourceIndex = data['source'] as int;
      _source = QueueSource.values[sourceIndex];
      _shuffledIndices.clear();
      _shufflePosition = -1;
      notifyListeners();
      print('🎵 [PlaylistQueueService] 已从 JSON 恢复队列: ${_queue.length} 首歌曲');
    } catch (e) {
      print('❌ [PlaylistQueueService] 恢复队列失败: $e');
    }
  }

  /// 保存当前队列到本地存储
  void saveQueue() {
    if (_queue.isEmpty) return;
    try {
      final data = json.encode(exportQueue());
      PersistentStorageService().setString('last_playback_queue', data);
      print('💾 [PlaylistQueueService] 播放队列已保存到本地');
    } catch (e) {
      print('❌ [PlaylistQueueService] 保存队列失败: $e');
    }
  }

  /// 从本地存储恢复队列
  void restoreQueue() {
    final dataStr = PersistentStorageService().getString('last_playback_queue');
    if (dataStr != null && dataStr.isNotEmpty) {
      try {
        final data = json.decode(dataStr) as Map<String, dynamic>;
        importQueue(data);
        print('✅ [PlaylistQueueService] 播放队列已从本地恢复');
      } catch (e) {
        print('❌ [PlaylistQueueService] 解析本地队列数据失败: $e');
      }
    }
  }
}

