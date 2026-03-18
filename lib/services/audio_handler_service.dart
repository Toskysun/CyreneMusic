import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'player_service.dart';
import 'android_floating_lyric_service.dart';
import 'android_media_notification_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../utils/image_utils.dart';
import 'lab_functions_service.dart';

/// Android 媒体通知处理器
/// 使用 audio_service 包实现 Android 系统通知栏的媒体控件
class CyreneAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  Timer? _updateTimer;  // 防抖定时器
  bool _updatePending = false;  // 是否有待处理的更新
  Timer? _lyricUpdateTimer;  // 悬浮歌词更新定时器（后台持续运行）
  Timer? _positionUpdateTimer;  // 进度条更新定时器（播放时定期更新）
  Timer? _iosStateRefreshTimer;  // iOS 专用状态刷新定时器（保持锁屏显示）
  PlayerState? _lastLoggedState;  // 上次记录日志时的状态
  DateTime? _lastLogTime;  // 上次记录日志的时间
  Duration? _lastUpdatedPosition;  // 上次更新的位置（用于减少不必要的更新）
  PlayerState? _lastUpdatedState;  // 上次更新的播放状态（用于减少不必要的更新）
  String? _lastWidgetArtUri;      // 上次小部件使用的封面 URI
  String? _lastWidgetArtPath;     // 上次小部件使用的封面本地路径
  String? _lastWidgetSongKey;     // 上次小部件显示的歌曲标识 (Title + Artist)
  
  // 构造函数
  CyreneAudioHandler() {
    print('🎵 [AudioHandler] 开始初始化...');
    
    // 🔧 关键修复：立即设置初始播放状态（必需，否则通知不会显示）
    _setInitialPlaybackState();
    
    // 监听播放器状态变化
    PlayerService().addListener(_onPlayerStateChanged);
    
    // 启动悬浮歌词后台更新定时器（仅 Android）
    if (Platform.isAndroid) {
      _startLyricUpdateTimer();

      // 启动自定义 Android 媒体通知服务（复用 audio_service 的 MediaSession）
      // 🔧 修复：禁用自定义通知服务，避免与 audio_service/media_kit 的系统通知冲突导致出现两个播放器控件
      // AndroidMediaNotificationService().start();
    }
    
    // 🍎 iOS 专用：启动状态刷新定时器以保持锁屏/灵动岛显示
    if (Platform.isIOS) {
      _startIOSStateRefreshTimer();
    }
    
    // 启动进度条更新定时器
    _startPositionUpdateTimer();
    
    print('✅ [AudioHandler] 初始化完成');
  }
  
  /// 启动悬浮歌词后台更新定时器
  void _startLyricUpdateTimer() {
    // 🔧 性能优化：将同步频率从 200ms 降低至 2000ms。
    // Android 原生层 (FloatingLyricService) 内部已有 100ms 的平滑自推进机制，
    // Dart 侧只需每 2 秒同步一次基准位置进行校准即可，这样可以显著降低后台 CPU 占用。
    _lyricUpdateTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) async {
      if (Platform.isAndroid && AndroidFloatingLyricService().isVisible) {
        // 使用 await 确保每次更新完成后再进行下一次
        // 这样可以避免并发调用导致的问题
        await PlayerService().updateFloatingLyricManually();
      }
    });
    print('✅ [AudioHandler] 悬浮歌词后台更新定时器已启动（2000ms间隔，定期校准）');
  }

  /// 🍎 iOS 专用：启动状态刷新定时器
  /// iOS 的 MPNowPlayingInfoCenter 需要定期刷新状态才能保持锁屏控制中心活跃
  void _startIOSStateRefreshTimer() {
    _iosStateRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final player = PlayerService();
      // 只要有歌曲在播放或暂停，就持续刷新状态
      if (player.state == PlayerState.playing || player.state == PlayerState.paused) {
        // 强制重新发送当前状态，保持 iOS 锁屏显示
        final song = player.currentSong;
        final track = player.currentTrack;
        
        // 更新 mediaItem（确保封面、歌名等信息不丢失）
        if (song != null || track != null) {
          _updateMediaItem(song, track);
        }
        
        // 更新播放状态
        _updatePlaybackState(player.state, player.position, player.duration);
      }
    });
    print('✅ [AudioHandler] iOS 状态刷新定时器已启动（3秒间隔，保持锁屏显示）');
  }

  /// 启动进度条更新定时器（播放时定期更新进度）
  void _startPositionUpdateTimer() {
    // 🔧 性能优化：降低更新频率到 1 秒，减少系统通知更新次数
    // 每1秒更新一次进度条（仅在播放时）
    _positionUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final player = PlayerService();
      if (player.state == PlayerState.playing || player.state == PlayerState.paused) {
        // 只更新进度位置，不触发完整的状态更新（避免与防抖冲突）
        final currentState = playbackState.value;
        final isPlaying = player.state == PlayerState.playing;
        final currentPosition = player.position;
        final currentDuration = player.duration;
        
        // 🔧 性能优化：只有当位置变化超过 0.5 秒或状态改变时才更新
        // 这样可以大幅减少系统通知的更新频率
        final positionChanged = _lastUpdatedPosition == null ||
            (currentPosition.inSeconds - _lastUpdatedPosition!.inSeconds).abs() >= 0.5;
        final stateChanged = _lastUpdatedState != player.state;
        final playingStateChanged = currentState.playing != isPlaying;
        final durationChanged = currentState.bufferedPosition != currentDuration;
        
        // 🍎 iOS 始终更新以保持锁屏显示活跃，Android 使用优化逻辑
        final shouldUpdate = Platform.isIOS || 
            positionChanged || stateChanged || playingStateChanged || durationChanged;
        
        // 只有当位置、状态或时长有显著变化时才更新（或 iOS 始终更新）
        if (shouldUpdate) {
          // 更新播放状态和进度
          playbackState.add(currentState.copyWith(
            playing: isPlaying,
            updatePosition: currentPosition,
            bufferedPosition: currentDuration,
            speed: isPlaying ? 1.0 : 0.0,
          ));
          
          // 记录上次更新的值
          _lastUpdatedPosition = currentPosition;
          _lastUpdatedState = player.state;
        }
      } else {
        // 不在播放状态时，清除缓存
        _lastUpdatedPosition = null;
        _lastUpdatedState = null;
      }
    });
    print('✅ [AudioHandler] 进度条更新定时器已启动（1秒间隔，带位置变化阈值）');
  }
  
  @override
  Future<void> onTaskRemoved() async {
    // 清理定时器
    _updateTimer?.cancel();
    _lyricUpdateTimer?.cancel();
    _positionUpdateTimer?.cancel();
    _iosStateRefreshTimer?.cancel();  // 🍎 iOS 专用定时器
    await super.onTaskRemoved();
  }

  /// 设置初始播放状态（必需）
  void _setInitialPlaybackState() {
    // 设置初始 MediaItem（即使没有歌曲也要设置）
    mediaItem.add(MediaItem(
      id: '0',
      title: 'Cyrene Music',
      artist: '等待播放...',
      album: '',
      duration: Duration.zero,
    ));
    
    // 设置初始 PlaybackState（这是显示通知的关键）
    // 只显示 3 个按钮：上一首、播放、下一首
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,  // 上一首
        MediaControl.play,            // 播放
        MediaControl.skipToNext,      // 下一首
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.play,           // 🎯 蓝牙耳机控制必需
        MediaAction.pause,          // 🎯 蓝牙耳机控制必需
        MediaAction.skipToNext,     // 🎯 蓝牙耳机控制必需
        MediaAction.skipToPrevious, // 🎯 蓝牙耳机控制必需
      },
      androidCompactActionIndices: const [0, 1, 2],  // 全部 3 个按钮都显示
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 0.0,
      queueIndex: 0,
    ));
    
    print('✅ [AudioHandler] 初始播放状态已设置（3个按钮：上一首/播放/下一首）');
  }

  /// 播放器状态变化回调（带防抖）
  void _onPlayerStateChanged() {
    final player = PlayerService();
    final currentState = player.state;
    final previousState = playbackState.value;
    final now = DateTime.now();
    
    // 🔧 性能优化：忽略仅位置变化的情况（位置更新由专门的定时器处理）
    // 只有当播放状态、歌曲或时长真正改变时才需要更新
    final isOnlyPositionChange = currentState == _lastUpdatedState &&
        (currentState == PlayerState.playing || currentState == PlayerState.paused);
    
    if (isOnlyPositionChange) {
      // 仅位置变化，由定时器处理，不需要触发完整的状态更新
      return;
    }
    
    // 🔧 关键修复：在播放开始时（loading 或 playing）立即更新，不等待防抖
    // 这样可以确保初次播放时状态和进度立即显示
    // 🔧 关键修复：在播放开始或暂停时都立即更新，不等待防抖
    // 这样可以确保状态切换（播放/暂停）立即响应
    final shouldUpdateImmediately = currentState == PlayerState.loading || 
        (currentState == PlayerState.playing && !previousState.playing) ||
        (currentState == PlayerState.paused && previousState.playing);
    
    if (shouldUpdateImmediately) {
      // 立即更新，不等待防抖
      _updateTimer?.cancel();
      _updatePending = false;
      _performUpdate();
      
      // 清除位置缓存，确保下次更新
      _lastUpdatedPosition = null;
      _lastUpdatedState = null;
      
      // 🔧 优化日志：只在状态真正改变时打印，且限制频率（最多每秒一次）
      final stateChanged = _lastLoggedState != currentState;
      final timeSinceLastLog = _lastLogTime == null || 
          now.difference(_lastLogTime!).inSeconds >= 1;
      
      // 只在状态改变时打印，或者每秒最多打印一次（避免进度更新时频繁打印）
      if (stateChanged && timeSinceLastLog) {
        print('🔄 [AudioHandler] 播放状态变化: ${_lastLoggedState?.name ?? "null"} -> ${currentState.name}');
        _lastLoggedState = currentState;
        _lastLogTime = now;
      }
      return;
    }
    
    // 🔧 性能优化：使用防抖机制，避免过于频繁的更新（例如调整音量时）
    // 取消之前的定时器
    _updateTimer?.cancel();
    
    // 标记有待处理的更新
    _updatePending = true;
    
    // 🔧 性能优化：增加防抖延迟到 200ms，减少更新频率
    // 设置新的定时器，延迟 200ms 执行更新
    _updateTimer = Timer(const Duration(milliseconds: 200), () {
      if (_updatePending) {
        _performUpdate();
        _updatePending = false;
        // 清除位置缓存，确保下次更新
        _lastUpdatedPosition = null;
        _lastUpdatedState = null;
      }
    });
  }

  /// 外部手动触发更新（例如在设置中开启小部件后立即同步）
  void refreshWidget() {
    print('🔄 [AudioHandler] 手动触发小部件更新...');
    _performUpdate();
  }
  
  /// 实际执行更新操作
  Future<void> _performUpdate() async {
    final player = PlayerService();
    final song = player.currentSong;
    final track = player.currentTrack;
    
    // 更新播放状态
    _updatePlaybackState(player.state, player.position, player.duration);

    // 更新媒体信息 (先用原始 URL 更新，保证响应速度)
    if (song != null || track != null) {
      _updateMediaItem(song, track);
    }
    
    // 获取本地封面路径
    final dynamic songOrTrack = song ?? track;
    final String artUri = (songOrTrack?.pic as String?) ?? (songOrTrack?.picUrl as String?) ?? '';
    final String title = (songOrTrack?.name as String?) ?? (songOrTrack?.title as String?) ?? 'Not Playing';
    final String artist = (songOrTrack?.arName as String?) ?? (songOrTrack?.artist as String?) ?? 'Cyrene Music';
    final currentSongKey = '$title-$artist';
    
    String? localArtPath;
    final songChanged = currentSongKey != _lastWidgetSongKey;
    
    if (artUri.isNotEmpty && (songChanged || artUri != _lastWidgetArtUri)) {
      if (artUri.startsWith('http')) {
        try {
          print('🌐 [AudioHandler] 下载封面用于通知/小部件: $artUri');
          final response = await http.get(Uri.parse(artUri), headers: getImageHeaders(artUri)).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/widget_art.png');
            await file.writeAsBytes(response.bodyBytes);
            localArtPath = file.path;
            
            _lastWidgetArtUri = artUri;
            _lastWidgetArtPath = localArtPath;
            _lastWidgetSongKey = currentSongKey;
          }
        } catch (e) {
          print('⚠️ [AudioHandler] 下载通知封面失败: $e');
        }
      } else if (artUri.startsWith('/') || artUri.startsWith('file://')) {
        localArtPath = artUri.replaceFirst('file://', '');
        _lastWidgetArtUri = artUri;
        _lastWidgetArtPath = localArtPath;
        _lastWidgetSongKey = currentSongKey;
      }
    } else if (artUri.isEmpty) {
      if (songChanged) {
        _lastWidgetArtUri = null;
        _lastWidgetArtPath = null;
        _lastWidgetSongKey = currentSongKey;
      }
    } else {
      localArtPath = _lastWidgetArtPath;
    }
    
    // 再次更新媒体信息，这次传入本地封面路径，供系统通知栏获取图片（防止 Android 下载时无网易云 header）
    if (localArtPath != null && (song != null || track != null)) {
      _updateMediaItem(song, track, overrideArtUri: 'file://$localArtPath');
    }
    
    // 更新桌面小部件
    _updateWidget(player.state, song ?? track, localArtPath);
  }

  /// 更新桌面小部件数据
  Future<void> _updateWidget(PlayerState state, dynamic songOrTrack, String? albumArtPath) async {
    if (!Platform.isAndroid) return;
    
    // 检查小部件是否开启（仅赞助用户可用且由用户在实验室设置中手动开启）
    if (!LabFunctionsService().enableAndroidWidget) {
      // 如果未开启，将小部件内容替换为提示文字
      try {
        await Future.wait([
          HomeWidget.saveWidgetData<String>('title', '小部件功能权限未开启？\n请前往设置-实验室开启'),
          HomeWidget.saveWidgetData<String>('artist', ''),
          HomeWidget.saveWidgetData<bool>('isPlaying', false),
          HomeWidget.saveWidgetData<String>('albumArtPath', ''),
          HomeWidget.saveWidgetData<bool>('isEnabled', false),
        ]);
        await _triggerWidgetUpdates();
      } catch (e) {
        print('⚠️ [AudioHandler] 更新小部件禁用状态提示失败: $e');
      }
      return;
    }
    
    try {
      final title = songOrTrack?.name ?? songOrTrack?.title ?? 'Not Playing';
      final artist = songOrTrack?.arName ?? songOrTrack?.artist ?? 'Cyrene Music';
      final isPlaying = state == PlayerState.playing;

      // 保存所有信息
      await Future.wait([
        HomeWidget.saveWidgetData<String>('title', title),
        HomeWidget.saveWidgetData<String>('artist', artist),
        HomeWidget.saveWidgetData<bool>('isPlaying', isPlaying),
        HomeWidget.saveWidgetData<bool>('isEnabled', true),
        HomeWidget.saveWidgetData<int>('art_version', DateTime.now().millisecondsSinceEpoch),
        HomeWidget.saveWidgetData<String>('albumArtPath', albumArtPath ?? ''),
      ]);
      
      print('📱 [AudioHandler] 更新小部件数据: Title=$title, Artist=$artist, Playing=$isPlaying, ArtPath=$albumArtPath');

      // 触发小部件更新
      _triggerWidgetUpdates();
    } catch (e) {
      print('⚠️ [AudioHandler] 更新桌面小部件失败: $e');
    }
  }

  /// 触发所有小部件更新
  Future<void> _triggerWidgetUpdates() async {
    // 触发小部件更新 (MusicWidget)
    await HomeWidget.updateWidget(
      name: 'MusicWidget',
      qualifiedAndroidName: 'com.cyrene.music.MusicWidget',
    );
    
    // 触发小部件更新 (MusicWidgetSmall)
    await HomeWidget.updateWidget(
      name: 'MusicWidgetSmall',
      qualifiedAndroidName: 'com.cyrene.music.MusicWidgetSmall',
    );
    print('✅ [AudioHandler] 小部件更新请求已发送 (Large & Small)');
  }

  /// 更新媒体信息
  void _updateMediaItem(dynamic song, dynamic track, {String? overrideArtUri}) {
    final title = song?.name ?? track?.name ?? '未知歌曲';
    final artist = song?.arName ?? track?.artists ?? '未知歌手';
    final album = song?.alName ?? track?.album ?? '';
    final artUri = overrideArtUri ?? song?.pic ?? track?.picUrl ?? '';

    // 转换封面 URI
    Uri? parsedArtUri;
    if (artUri.isNotEmpty) {
      if (artUri.startsWith('/')) {
        // 本地文件路径，转换为 file:// URI
        parsedArtUri = Uri.file(artUri);
      } else if (artUri.startsWith('http://') || artUri.startsWith('https://') || artUri.startsWith('file://')) {
        // 已经是完整的 URI
        parsedArtUri = Uri.parse(artUri);
      } else {
        // 其他情况，尝试直接解析
        parsedArtUri = Uri.tryParse(artUri);
      }
    }

    mediaItem.add(MediaItem(
      id: track?.id.toString() ?? '0',
      title: title,
      artist: artist,
      album: album,
      artUri: parsedArtUri,
      duration: PlayerService().duration,
    ));
  }

  /// 更新播放状态
  void _updatePlaybackState(PlayerState playerState, Duration position, Duration duration) {
    // 只保留 3 个核心按钮：上一首、播放/暂停、下一首
    final controls = [
      MediaControl.skipToPrevious,  // 上一首
      if (playerState == PlayerState.playing)
        MediaControl.pause          // 暂停
      else
        MediaControl.play,          // 播放
      MediaControl.skipToNext,      // 下一首
    ];

    final playing = playerState == PlayerState.playing;
    final processingState = _getProcessingState(playerState);
    final currentState = playbackState.value;

    // 🔧 性能优化：只有当状态真正改变时才更新，避免不必要的系统通知更新
    final stateChanged = currentState.playing != playing ||
        currentState.processingState != processingState ||
        currentState.controls.length != controls.length ||
        !_controlsEqual(currentState.controls, controls);
    
    if (stateChanged) {
      playbackState.add(currentState.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,           // 🎯 蓝牙耳机控制必需
          MediaAction.pause,          // 🎯 蓝牙耳机控制必需
          MediaAction.skipToNext,     // 🎯 蓝牙耳机控制必需
          MediaAction.skipToPrevious, // 🎯 蓝牙耳机控制必需
        },
        androidCompactActionIndices: const [0, 1, 2], // 全部3个按钮都显示在紧凑视图
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        bufferedPosition: duration,
        speed: playing ? 1.0 : 0.0,
        queueIndex: 0,
      ));
    } else {
      // 状态没变，只更新位置（如果位置有变化）
      final positionChanged = currentState.updatePosition != position ||
          currentState.bufferedPosition != duration;
      if (positionChanged) {
        playbackState.add(currentState.copyWith(
          updatePosition: position,
          bufferedPosition: duration,
        ));
      }
    }
  }
  
  /// 检查两个控件列表是否相等
  bool _controlsEqual(List<MediaControl> a, List<MediaControl> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].action != b[i].action) return false;
    }
    return true;
  }

  /// 强制立即更新播放状态（用于按钮点击时立即同步状态）
  void _forceUpdatePlaybackState() {
    // 取消防抖定时器，立即执行更新
    _updateTimer?.cancel();
    _updatePending = false;
    
    // 立即执行更新
    final player = PlayerService();
    final currentState = player.state;
    final currentPosition = player.position;
    final currentDuration = player.duration;
    
    _updatePlaybackState(currentState, currentPosition, currentDuration);
    
    print('🔄 [AudioHandler] 强制更新播放状态: ${currentState.name}, 位置: ${currentPosition.inSeconds}s/${currentDuration.inSeconds}s');
  }

  /// 转换播放状态
  AudioProcessingState _getProcessingState(PlayerState state) {
    switch (state) {
      case PlayerState.idle:
        return AudioProcessingState.idle;
      case PlayerState.loading:
        return AudioProcessingState.loading;
      case PlayerState.playing:
      case PlayerState.paused:
        return AudioProcessingState.ready;
      case PlayerState.error:
        return AudioProcessingState.error;
    }
  }

  // ============== 媒体控制按钮回调 ==============

  @override
  Future<void> play() async {
    print('🎮 [AudioHandler] 蓝牙/系统媒体控件: 播放');
    final player = PlayerService();
    await player.resume();
    // 🔧 移除手动强制更新，依赖 _onPlayerStateChanged 监听器自动更新
    // 之前的手动更新会导致竞态条件（状态还没变就强制更新了旧状态）
  }

  @override
  Future<void> pause() async {
    print('🎮 [AudioHandler] 蓝牙/系统媒体控件: 暂停');
    final player = PlayerService();
    await player.pause();
    // 🔧 移除手动强制更新，依赖 _onPlayerStateChanged 监听器自动更新
  }

  @override
  Future<void> stop() async {
    print('🎮 [AudioHandler] 蓝牙/系统媒体控件: 停止');
    await PlayerService().stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    print('🎮 [AudioHandler] 蓝牙/系统媒体控件: 下一首');
    // 🔧 修复：使用 PlayerService 的 playNext 方法
    // 这样可以正确处理播放队列和播放历史
    await PlayerService().playNext();
    // 注意：playNext 会触发歌曲切换，状态会通过 _onPlayerStateChanged 自动更新
  }

  @override
  Future<void> skipToPrevious() async {
    print('🎮 [AudioHandler] 蓝牙/系统媒体控件: 上一首');
    // 🔧 修复：使用 PlayerService 的 playPrevious 方法
    // 这样可以正确处理播放队列和播放历史
    await PlayerService().playPrevious();
    // 注意：playPrevious 会触发歌曲切换，状态会通过 _onPlayerStateChanged 自动更新
  }

  @override
  Future<void> seek(Duration position) async {
    await PlayerService().seek(position);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    // 自定义操作处理
    if (!Platform.isAndroid) return;

    if (name == 'toggle_floating_lyric') {
      // 来自系统媒体控件“词”按钮的指令
      print('🎮 [AudioHandler] 系统媒体控件: 切换悬浮歌词');
      await AndroidFloatingLyricService().toggle();
      return;
    }
  }
}


