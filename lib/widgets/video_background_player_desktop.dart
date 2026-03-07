import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 桌面平台视频背景播放器（Windows/macOS/Linux）
/// 使用 media_kit
class VideoBackgroundPlayerDesktop extends StatefulWidget {
  final String videoPath;
  final double blurAmount;
  final double opacity;
  
  const VideoBackgroundPlayerDesktop({
    super.key,
    required this.videoPath,
    this.blurAmount = 0.0,
    this.opacity = 1.0,
  });

  @override
  State<VideoBackgroundPlayerDesktop> createState() => _VideoBackgroundPlayerDesktopState();
}

class _VideoBackgroundPlayerDesktopState extends State<VideoBackgroundPlayerDesktop> {
  Player? _player;
  VideoController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  double _videoOpacity = 0.0;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoBackgroundPlayerDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _disposeController();
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      final isNetwork = widget.videoPath.startsWith('http://') || widget.videoPath.startsWith('https://');

      if (!isNetwork) {
        final file = File(widget.videoPath);
        if (!await file.exists()) {
          print('❌ [VideoBackground] 视频文件不存在: ${widget.videoPath}');
          setState(() {
            _hasError = true;
          });
          return;
        }
      }

      // 创建播放器实例（配置为背景视频模式）
      _player = Player(
        configuration: const PlayerConfiguration(
          title: 'Background Video',
          ready: null,
        ),
      );
      _controller = VideoController(_player!);
      
      // 先设置静音和循环，再打开视频
      await _player!.setVolume(0.0);  // 静音
      await _player!.setPlaylistMode(PlaylistMode.loop);  // 循环播放
      
      // 监听位置实现循环渐透明过渡
      _positionSubscription = _player!.stream.position.listen(_onVideoPositionChanged);

      // 打开并播放视频
      await _player!.open(Media(widget.videoPath));
      await _player!.play();
      
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _videoOpacity = 1.0;
      });
      
      print('✅ [VideoBackground] 视频已初始化 (media_kit, 静音模式): ${widget.videoPath}');
    } catch (e) {
      print('❌ [VideoBackground] 初始化视频失败: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  void _onVideoPositionChanged(Duration position) {
    if (_player == null || !_isInitialized) return;
    
    final duration = _player!.state.duration.inMilliseconds;
    final pos = position.inMilliseconds;
    
    if (duration == 0) return;

    // 当视频离结束还剩不到 800ms 时开始淡出，重新开始播放时（位置跃回开头）恢复淡入
    if (duration - pos <= 800) {
      if (_videoOpacity != 0.0) {
        setState(() => _videoOpacity = 0.0);
      }
    } else {
      if (_videoOpacity != 1.0) {
        setState(() => _videoOpacity = 1.0);
      }
    }
  }

  void _disposeController() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _player?.dispose();
    _player = null;
    _controller = null;
    _isInitialized = false;
    _videoOpacity = 0.0;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox.shrink();
    }

    Widget videoWidget = (_isInitialized && _controller != null)
        ? RepaintBoundary(
            child: Video(
              controller: _controller!,
              fit: BoxFit.cover,
              controls: null,
            ),
          )
        : const SizedBox.shrink();

    if (widget.blurAmount > 0 || widget.opacity < 1.0) {
      videoWidget = RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            videoWidget,
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurAmount,
                sigmaY: widget.blurAmount,
              ),
              child: Container(
                color: Colors.black.withOpacity(1 - widget.opacity),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedOpacity(
      opacity: _videoOpacity,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      child: videoWidget,
    );
  }
}

