import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/playback_mode_service.dart';
import '../../services/lyric_style_service.dart';
import '../../services/player_background_service.dart';
import '../../services/sleep_timer_service.dart';
import '../../services/auth_service.dart';
import '../../models/track.dart';

/// 移动端播放器设置底部弹出板
/// 从底部弹出，包含播放顺序、播放器样式、背景、睡眠定时器等设置
class MobilePlayerSettingsSheet extends StatefulWidget {
  final Track? currentTrack;
  
  const MobilePlayerSettingsSheet({
    super.key,
    this.currentTrack,
  });

  /// 显示设置底部弹出板
  static void show(BuildContext context, {Track? currentTrack}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MobilePlayerSettingsSheet(currentTrack: currentTrack),
    );
  }

  @override
  State<MobilePlayerSettingsSheet> createState() => _MobilePlayerSettingsSheetState();
}

class _MobilePlayerSettingsSheetState extends State<MobilePlayerSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖动指示器
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      '播放器设置',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white24, height: 1),
              
              // 设置列表
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    // 播放顺序
                    _buildPlaybackModeSection(),
                    
                    const SizedBox(height: 20),
                    
                    // 播放器样式
                    _buildPlayerStyleSection(),
                    
                    const SizedBox(height: 20),
                    
                    // 播放器背景
                    _buildBackgroundSection(),
                    
                    const SizedBox(height: 20),
                    
                    // 睡眠定时器
                    _buildSleepTimerSection(),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建播放顺序设置区域
  Widget _buildPlaybackModeSection() {
    return AnimatedBuilder(
      animation: PlaybackModeService(),
      builder: (context, _) {
        final modeService = PlaybackModeService();
        final currentMode = modeService.currentMode;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '播放顺序',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildModeChip(
                    icon: Icons.repeat_rounded,
                    label: '顺序',
                    isSelected: currentMode == PlaybackMode.sequential,
                    onTap: () => modeService.setMode(PlaybackMode.sequential),
                  ),
                  const SizedBox(width: 8),
                  _buildModeChip(
                    icon: Icons.repeat_one_rounded,
                    label: '单曲循环',
                    isSelected: currentMode == PlaybackMode.repeatOne,
                    onTap: () => modeService.setMode(PlaybackMode.repeatOne),
                  ),
                  const SizedBox(width: 8),
                  _buildModeChip(
                    icon: Icons.shuffle_rounded,
                    label: '随机',
                    isSelected: currentMode == PlaybackMode.shuffle,
                    onTap: () => modeService.setMode(PlaybackMode.shuffle),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建模式选择芯片
  Widget _buildModeChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white60,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建播放器样式设置区域
  Widget _buildPlayerStyleSection() {
    return AnimatedBuilder(
      animation: LyricStyleService(),
      builder: (context, _) {
        final styleService = LyricStyleService();
        final currentStyle = styleService.currentStyle;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '播放器样式',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStyleChip(
                    icon: Icons.water_drop_rounded,
                    label: '流体云',
                    description: '沉浸式歌词体验',
                    isSelected: currentStyle == LyricStyle.fluidCloud,
                    onTap: () => styleService.setStyle(LyricStyle.fluidCloud),
                  ),
                  const SizedBox(width: 12),
                  _buildStyleChip(
                    icon: Icons.music_note_rounded,
                    label: '经典',
                    description: '卡拉OK效果',
                    isSelected: currentStyle == LyricStyle.defaultStyle,
                    onTap: () => styleService.setStyle(LyricStyle.defaultStyle),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建样式选择芯片
  Widget _buildStyleChip({
    required IconData icon,
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white60,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: isSelected ? Colors.white54 : Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建背景设置区域
  Widget _buildBackgroundSection() {
    return AnimatedBuilder(
      animation: PlayerBackgroundService(),
      builder: (context, _) {
        final bgService = PlayerBackgroundService();
        final currentType = bgService.backgroundType;
        final isSponsor = AuthService().currentUser?.isSponsor ?? false;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '播放器背景',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              
              // 基础背景选项
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildBackgroundChip(
                    icon: Icons.auto_awesome_rounded,
                    label: '自适应',
                    isSelected: currentType == PlayerBackgroundType.adaptive,
                    onTap: () => bgService.setBackgroundType(PlayerBackgroundType.adaptive),
                  ),
                  _buildBackgroundChip(
                    icon: Icons.blur_on_rounded,
                    label: '动态',
                    isSelected: currentType == PlayerBackgroundType.dynamic,
                    onTap: () => bgService.setBackgroundType(PlayerBackgroundType.dynamic),
                  ),
                  _buildBackgroundChip(
                    icon: Icons.palette_rounded,
                    label: '纯色',
                    isSelected: currentType == PlayerBackgroundType.solidColor,
                    onTap: () => bgService.setBackgroundType(PlayerBackgroundType.solidColor),
                  ),
                ],
              ),
              
              // 纯色选择器（仅在选择纯色时显示）
              if (currentType == PlayerBackgroundType.solidColor) ...[
                const SizedBox(height: 12),
                _buildSolidColorPicker(bgService),
              ],
              
              const SizedBox(height: 16),
              
              // 赞助用户专属背景选项
              Row(
                children: [
                  const Text(
                    '赞助用户专属',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '🎁',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildBackgroundChip(
                    icon: Icons.image_rounded,
                    label: bgService.mediaPath != null && bgService.isImage ? '图片(已设置)' : '图片',
                    isSelected: currentType == PlayerBackgroundType.image,
                    onTap: isSponsor 
                        ? () => bgService.setBackgroundType(PlayerBackgroundType.image)
                        : () => _showSponsorOnlyMessage(),
                    isDisabled: !isSponsor,
                  ),
                  _buildBackgroundChip(
                    icon: Icons.video_library_rounded,
                    label: bgService.mediaPath != null && bgService.isVideo ? '视频(已设置)' : '视频',
                    isSelected: currentType == PlayerBackgroundType.video,
                    onTap: isSponsor 
                        ? () => bgService.setBackgroundType(PlayerBackgroundType.video)
                        : () => _showSponsorOnlyMessage(),
                    isDisabled: !isSponsor,
                  ),
                ],
              ),
              
              // 图片/视频设置（仅在选择图片或视频时显示）
              if ((currentType == PlayerBackgroundType.image || currentType == PlayerBackgroundType.video) && isSponsor) ...[
                const SizedBox(height: 12),
                _buildMediaBackgroundSettings(bgService, currentType),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 显示赞助用户专属提示
  void _showSponsorOnlyMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎁 此功能为赞助用户专属，成为赞助用户即可解锁'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 构建纯色选择器
  Widget _buildSolidColorPicker(PlayerBackgroundService bgService) {
    final presetColors = [
      Colors.grey[900]!,
      Colors.black,
      Colors.blue[900]!,
      Colors.purple[900]!,
      Colors.red[900]!,
      Colors.green[900]!,
      Colors.orange[900]!,
      Colors.teal[900]!,
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择颜色',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // 预设颜色
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetColors.map((color) => GestureDetector(
                  onTap: () async {
                    await bgService.setSolidColor(color);
                    setState(() {});
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color == bgService.solidColor
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            // 自定义颜色按钮
            GestureDetector(
              onTap: () => _showCustomColorPicker(bgService),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.colorize, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 显示自定义颜色选择器
  Future<void> _showCustomColorPicker(PlayerBackgroundService bgService) async {
    Color pickerColor = bgService.solidColor;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('自定义颜色', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
            labelTypes: const [
              ColorLabelType.rgb,
              ColorLabelType.hsv,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await bgService.setSolidColor(pickerColor);
              setState(() {});
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 构建图片/视频背景设置
  Widget _buildMediaBackgroundSettings(PlayerBackgroundService bgService, PlayerBackgroundType currentType) {
    final isVideo = currentType == PlayerBackgroundType.video;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择媒体按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectBackgroundMedia(bgService, isVideo),
                icon: Icon(isVideo ? Icons.video_library : Icons.image, color: Colors.white70, size: 18),
                label: Text(
                  isVideo ? '选择视频' : '选择图片',
                  style: const TextStyle(color: Colors.white70),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (bgService.mediaPath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  await bgService.clearMediaBackground();
                  setState(() {});
                },
                icon: const Icon(Icons.clear, color: Colors.white54),
                tooltip: '清除${isVideo ? '视频' : '图片'}',
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 模糊程度调节
        Row(
          children: [
            const Text(
              '模糊程度',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(
              '${bgService.blurAmount.toInt()}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: bgService.blurAmount,
            min: 0,
            max: 50,
            divisions: 50,
            onChanged: (value) async {
              await bgService.setBlurAmount(value);
              setState(() {});
            },
          ),
        ),
        const Text(
          '0 = 清晰，50 = 最模糊',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  /// 选择背景媒体（图片或视频）
  Future<void> _selectBackgroundMedia(PlayerBackgroundService bgService, bool isVideo) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isVideo
          ? ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v']
          : ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
      dialogTitle: isVideo ? '选择背景视频' : '选择背景图片',
    );

    if (result != null && result.files.single.path != null) {
      final mediaPath = result.files.single.path!;
      await bgService.setMediaBackground(mediaPath);
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVideo ? '背景视频已设置' : '背景图片已设置'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 构建背景选择芯片
  Widget _buildBackgroundChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withAlpha(38) 
              : Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white.withAlpha(77) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDisabled 
                  ? Colors.white38 
                  : (isSelected ? Colors.white : Colors.white60),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isDisabled 
                    ? Colors.white38 
                    : (isSelected ? Colors.white : Colors.white60),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建睡眠定时器区域
  Widget _buildSleepTimerSection() {
    return AnimatedBuilder(
      animation: SleepTimerService(),
      builder: (context, _) {
        final timer = SleepTimerService();
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '睡眠定时器',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (timer.isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        timer.remainingTimeString,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              
              if (timer.isActive)
                // 定时器运行中
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          timer.extend(15);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已延长15分钟')),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('延长15分钟'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          timer.cancel();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('定时器已取消')),
                          );
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('取消'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                )
              else
                // 定时器未运行
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [15, 30, 45, 60, 90].map((minutes) {
                    return GestureDetector(
                      onTap: () {
                        timer.setTimerByDuration(minutes);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('定时器已设置: ${minutes}分钟后停止播放')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$minutes分钟',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
