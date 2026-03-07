import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 移动平台视频背景播放器（Android/iOS）
/// 使用 video_player，配置为与音乐播放共存
class VideoBackgroundPlayerMobile extends StatefulWidget {
  final String videoPath;
  final double blurAmount;
  final double opacity;
  
  const VideoBackgroundPlayerMobile({
    super.key,
    required this.videoPath,
    this.blurAmount = 0.0,
    this.opacity = 1.0,
  });

  @override
  State<VideoBackgroundPlayerMobile> createState() => _VideoBackgroundPlayerMobileState();
}

class _VideoBackgroundPlayerMobileState extends State<VideoBackgroundPlayerMobile> 
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  double _videoOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用恢复前台时，确保视频继续播放
    if (state == AppLifecycleState.resumed) {
      if (_controller != null && _isInitialized && !_controller!.value.isPlaying) {
        _controller!.play();
      }
    }
  }

  @override
  void didUpdateWidget(VideoBackgroundPlayerMobile oldWidget) {
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

        // 创建控制器，配置混音选项以不干扰音乐播放
        _controller = VideoPlayerController.file(
          file,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,  // 允许与其他音频混合（关键配置）
            allowBackgroundPlayback: false,  // 不需要后台播放
          ),
        );
      } else {
        // 网络请求
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoPath),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
      }
      
      await _controller!.initialize();
      
      // 添加监听器以实现循环时的渐变过渡
      _controller!.addListener(_onVideoPositionChanged);

      // 设置循环播放和静音
      await _controller!.setLooping(true);
      await _controller!.setVolume(0.0);  // 静音
      
      // 开始播放
      await _controller!.play();
      
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _videoOpacity = 1.0;
      });
      
      print('✅ [VideoBackground] 视频已初始化 (video_player, 混音模式): ${widget.videoPath}');
    } catch (e) {
      print('❌ [VideoBackground] 初始化视频失败: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  void _onVideoPositionChanged() {
    if (_controller == null || !_isInitialized) return;
    
    final duration = _controller!.value.duration.inMilliseconds;
    final position = _controller!.value.position.inMilliseconds;
    
    if (duration == 0) return;

    // 当视频离结束还剩不到 800ms 时开始淡出，重新开始播放时（位置跃回开头）恢复淡入
    if (duration - position <= 800) {
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
    _controller?.removeListener(_onVideoPositionChanged);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _videoOpacity = 0.0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox.shrink();
    }

    Widget videoWidget = (_isInitialized && _controller != null)
        ? SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        : const SizedBox.shrink();

    if (widget.blurAmount > 0 || widget.opacity < 1.0) {
      videoWidget = Stack(
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

