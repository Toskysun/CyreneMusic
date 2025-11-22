import 'dart:io';
import 'package:flutter/material.dart';
import 'video_background_player_desktop.dart';
import 'video_background_player_mobile.dart';

/// 视频背景播放器组件（跨平台）
/// 用于播放背景视频，支持循环播放、模糊效果和静音
/// 桌面平台（Windows/macOS/Linux）使用 media_kit
/// 移动平台（Android/iOS）使用 video_player
class VideoBackgroundPlayer extends StatelessWidget {
  final String videoPath;
  final double blurAmount;
  final double opacity;
  
  const VideoBackgroundPlayer({
    super.key,
    required this.videoPath,
    this.blurAmount = 0.0,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // 根据平台选择合适的播放器实现
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    
    if (isDesktop) {
      return VideoBackgroundPlayerDesktop(
        videoPath: videoPath,
        blurAmount: blurAmount,
        opacity: opacity,
      );
    } else {
      return VideoBackgroundPlayerMobile(
        videoPath: videoPath,
        blurAmount: blurAmount,
        opacity: opacity,
      );
    }
  }
}

