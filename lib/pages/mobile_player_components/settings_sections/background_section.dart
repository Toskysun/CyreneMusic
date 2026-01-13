import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/player_background_service.dart';
import '../../../services/auth_service.dart';

/// 背景设置区域 - Material Design Expressive 风格
/// 全圆胶囊形芯片 + 赞助专属渐变装饰
class BackgroundSection extends StatefulWidget {
  const BackgroundSection({super.key});

  @override
  State<BackgroundSection> createState() => _BackgroundSectionState();
}

class _BackgroundSectionState extends State<BackgroundSection> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: PlayerBackgroundService(),
      builder: (context, _) {
        final bgService = PlayerBackgroundService();
        final currentType = bgService.backgroundType;
        final isSponsor = AuthService().currentUser?.isSponsor ?? false;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.6 : 0.8),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(
                      Icons.wallpaper_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '播放器背景',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                
                // 基础背景选项 - 胶囊芯片
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildPillChip(
                      icon: Icons.auto_awesome_rounded,
                      label: '自适应',
                      isSelected: currentType == PlayerBackgroundType.adaptive,
                      onTap: () => bgService.setBackgroundType(PlayerBackgroundType.adaptive),
                      colorScheme: colorScheme,
                    ),
                    _buildPillChip(
                      icon: Icons.blur_on_rounded,
                      label: '动态',
                      isSelected: currentType == PlayerBackgroundType.dynamic,
                      onTap: () => bgService.setBackgroundType(PlayerBackgroundType.dynamic),
                      colorScheme: colorScheme,
                    ),
                    _buildPillChip(
                      icon: Icons.palette_rounded,
                      label: '纯色',
                      isSelected: currentType == PlayerBackgroundType.solidColor,
                      onTap: () => bgService.setBackgroundType(PlayerBackgroundType.solidColor),
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
                
                // 纯色选择器
                if (currentType == PlayerBackgroundType.solidColor) ...[
                  const SizedBox(height: 16),
                  _buildSolidColorPicker(bgService, colorScheme, isDark),
                ],
                
                const SizedBox(height: 20),
                
                // 赞助用户专属 - 渐变徽章
                _buildSponsorBadge(colorScheme),
                const SizedBox(height: 12),
                
                // 赞助专属背景选项
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildPillChip(
                      icon: Icons.image_rounded,
                      label: bgService.mediaPath != null && bgService.isImage 
                          ? '图片 ✓' : '图片',
                      isSelected: currentType == PlayerBackgroundType.image,
                      onTap: isSponsor 
                          ? () => bgService.setBackgroundType(PlayerBackgroundType.image)
                          : () => _showSponsorOnlyMessage(),
                      colorScheme: colorScheme,
                      isDisabled: !isSponsor,
                      isSponsorFeature: true,
                    ),
                    _buildPillChip(
                      icon: Icons.video_library_rounded,
                      label: bgService.mediaPath != null && bgService.isVideo 
                          ? '视频 ✓' : '视频',
                      isSelected: currentType == PlayerBackgroundType.video,
                      onTap: isSponsor 
                          ? () => bgService.setBackgroundType(PlayerBackgroundType.video)
                          : () => _showSponsorOnlyMessage(),
                      colorScheme: colorScheme,
                      isDisabled: !isSponsor,
                      isSponsorFeature: true,
                    ),
                  ],
                ),
                
                // 图片/视频设置
                if ((currentType == PlayerBackgroundType.image || 
                     currentType == PlayerBackgroundType.video) && isSponsor) ...[
                  const SizedBox(height: 16),
                  _buildMediaBackgroundSettings(bgService, currentType, colorScheme, isDark),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 显示赞助用户专属提示
  void _showSponsorOnlyMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🎁'),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('此功能为赞助用户专属，成为赞助用户即可解锁'),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 构建胶囊形芯片
  Widget _buildPillChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    bool isDisabled = false,
    bool isSponsorFeature = false,
  }) {
    final effectiveColor = isDisabled 
        ? colorScheme.outline 
        : (isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected && !isDisabled
              ? LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.primaryContainer.withOpacity(0.7),
                  ],
                )
              : (isSponsorFeature && !isDisabled
                  ? LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.1),
                        Colors.amber.withOpacity(0.05),
                      ],
                    )
                  : null),
          color: isSelected || isSponsorFeature ? null : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected 
                ? colorScheme.primary 
                : (isSponsorFeature && !isDisabled 
                    ? Colors.orange.withOpacity(0.3) 
                    : colorScheme.outlineVariant.withOpacity(0.3)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected && !isDisabled
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: effectiveColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 赞助用户专属徽章
  Widget _buildSponsorBadge(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.15),
            Colors.amber.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎁', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            '赞助用户专属',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建纯色选择器
  Widget _buildSolidColorPicker(
    PlayerBackgroundService bgService,
    ColorScheme colorScheme,
    bool isDark,
  ) {
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
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择颜色',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...presetColors.map((color) => _buildColorBlock(
                color: color,
                isSelected: color == bgService.solidColor,
                onTap: () async {
                  await bgService.setSolidColor(color);
                  setState(() {});
                },
                colorScheme: colorScheme,
              )),
              // 自定义颜色按钮
              GestureDetector(
                onTap: () => _showCustomColorPicker(bgService, colorScheme),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red, Colors.orange, Colors.yellow,
                        Colors.green, Colors.blue, Colors.purple,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.colorize, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建颜色块
  Widget _buildColorBlock({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  /// 显示自定义颜色选择器
  Future<void> _showCustomColorPicker(
    PlayerBackgroundService bgService,
    ColorScheme colorScheme,
  ) async {
    Color pickerColor = bgService.solidColor;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '自定义颜色',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
            labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
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
  Widget _buildMediaBackgroundSettings(
    PlayerBackgroundService bgService,
    PlayerBackgroundType currentType,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final isVideo = currentType == PlayerBackgroundType.video;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 选择媒体按钮
          Row(
            children: [
              Expanded(
                child: Material(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _selectBackgroundMedia(bgService, isVideo),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isVideo ? Icons.video_library : Icons.image,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isVideo ? '选择视频' : '选择图片',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (bgService.mediaPath != null) ...[
                const SizedBox(width: 12),
                Material(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () async {
                      await bgService.clearMediaBackground();
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.onErrorContainer,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 18),
          
          // 模糊程度调节
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.blur_linear_rounded,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '模糊程度',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.2),
                      colorScheme.primary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${bgService.blurAmount.toInt()}',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colorScheme.primary,
              inactiveTrackColor: colorScheme.surfaceContainerHighest,
              thumbColor: colorScheme.primary,
              overlayColor: colorScheme.primary.withOpacity(0.15),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 4,
              ),
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
          Text(
            '0 = 清晰，50 = 最模糊',
            style: TextStyle(
              color: colorScheme.outline,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// 选择背景媒体
  Future<void> _selectBackgroundMedia(
    PlayerBackgroundService bgService,
    bool isVideo,
  ) async {
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
