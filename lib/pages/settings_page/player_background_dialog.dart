import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/player_background_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme_manager.dart';

/// 播放器背景设置对话框
class PlayerBackgroundDialog extends StatefulWidget {
  final VoidCallback onChanged;
  
  const PlayerBackgroundDialog({super.key, required this.onChanged});

  @override
  State<PlayerBackgroundDialog> createState() => _PlayerBackgroundDialogState();
}

class _PlayerBackgroundDialogState extends State<PlayerBackgroundDialog> {
  @override
  Widget build(BuildContext context) {
    final backgroundService = PlayerBackgroundService();
    final currentType = backgroundService.backgroundType;
    final isFluent = Platform.isWindows && ThemeManager().isFluentFramework;
    
    // 检查用户是否为赞助用户
    final authService = AuthService();
    final isSponsor = authService.currentUser?.isSponsor ?? false;

    if (isFluent) {
      return fluent_ui.ContentDialog(
        title: const Text('播放器背景设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 自适应背景
              fluent_ui.RadioButton(
                content: const Text('自适应背景'),
                checked: currentType == PlayerBackgroundType.adaptive,
                onChanged: (v) async {
                  await backgroundService.setBackgroundType(PlayerBackgroundType.adaptive);
                  setState(() {});
                  widget.onChanged();
                },
              ),
              // 渐变开关（仅在自适应背景时显示）
              if (currentType == PlayerBackgroundType.adaptive) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('封面渐变效果')),
                    fluent_ui.ToggleSwitch(
                      checked: backgroundService.enableGradient,
                      onChanged: (value) async {
                        await backgroundService.setEnableGradient(value);
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    Platform.isWindows || Platform.isMacOS || Platform.isLinux
                        ? '专辑封面位于左侧，向右渐变到主题色'
                        : '专辑封面位于顶部，向下渐变到主题色',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // 纯色背景
              fluent_ui.RadioButton(
                content: const Text('纯色背景'),
                checked: currentType == PlayerBackgroundType.solidColor,
                onChanged: (v) async {
                  await backgroundService.setBackgroundType(PlayerBackgroundType.solidColor);
                  setState(() {});
                  widget.onChanged();
                },
              ),
              if (currentType == PlayerBackgroundType.solidColor) ...[
                const SizedBox(height: 8),
                fluent_ui.FilledButton(
                  onPressed: _showSolidColorPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.palette, color: backgroundService.solidColor),
                      const SizedBox(width: 8),
                      const Text('选择颜色'),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // 图片背景（赞助用户独享）
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backgroundService.mediaPath != null && backgroundService.isImage 
                          ? '图片背景（已设置）' 
                          : '图片背景',
                    ),
                    if (!isSponsor)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          '🎁 赞助用户独享功能',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
                checked: currentType == PlayerBackgroundType.image,
                onChanged: isSponsor
                    ? (v) async {
                        await backgroundService.setBackgroundType(PlayerBackgroundType.image);
                        setState(() {});
                        widget.onChanged();
                      }
                    : null, // 非赞助用户禁用
              ),
              
              const SizedBox(height: 8),
              
              // 视频背景（赞助用户独享）
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backgroundService.mediaPath != null && backgroundService.isVideo 
                          ? '视频背景（已设置）' 
                          : '视频背景',
                    ),
                    if (!isSponsor)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          '🎁 赞助用户独享功能',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
                checked: currentType == PlayerBackgroundType.video,
                onChanged: isSponsor
                    ? (v) async {
                        await backgroundService.setBackgroundType(PlayerBackgroundType.video);
                        setState(() {});
                        widget.onChanged();
                      }
                    : null, // 非赞助用户禁用
              ),
              if (currentType == PlayerBackgroundType.image || currentType == PlayerBackgroundType.video) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: fluent_ui.FilledButton(
                        onPressed: _selectBackgroundMedia,
                        child: Text(currentType == PlayerBackgroundType.image ? '选择图片' : '选择视频'),
                      ),
                    ),
                    if (backgroundService.mediaPath != null) ...[
                      const SizedBox(width: 8),
                      fluent_ui.IconButton(
                        icon: const Icon(fluent_ui.FluentIcons.clear),
                        onPressed: () async {
                          await backgroundService.clearMediaBackground();
                          setState(() {});
                          widget.onChanged();
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text('模糊程度: ${backgroundService.blurAmount.toStringAsFixed(0)}'),
                fluent_ui.Slider(
                  value: backgroundService.blurAmount,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  onChanged: (value) async {
                    await backgroundService.setBlurAmount(value);
                    setState(() {});
                    widget.onChanged();
                  },
                ),
                const Text('0 = 清晰，50 = 最模糊', style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          fluent_ui.Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wallpaper),
          SizedBox(width: 8),
          Text('播放器背景设置'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 自适应背景
            RadioListTile<PlayerBackgroundType>(
              title: const Text('自适应背景'),
              subtitle: const Text('基于专辑封面提取颜色'),
              value: PlayerBackgroundType.adaptive,
              groupValue: currentType,
              onChanged: (value) async {
                await backgroundService.setBackgroundType(value!);
                setState(() {});
                widget.onChanged();
              },
            ),
            
            // 渐变开关（仅在自适应背景时显示）
            if (currentType == PlayerBackgroundType.adaptive) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: SwitchListTile(
                  title: const Text('封面渐变效果'),
                  subtitle: Text(
                    Platform.isWindows || Platform.isMacOS || Platform.isLinux
                        ? '专辑封面位于左侧，向右渐变到主题色'
                        : '专辑封面位于顶部，向下渐变到主题色',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  value: backgroundService.enableGradient,
                  onChanged: (value) async {
                    await backgroundService.setEnableGradient(value);
                    setState(() {});
                    widget.onChanged();
                  },
                  secondary: const Icon(Icons.gradient),
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
                ),
              ),
            ],
            
            // 纯色背景
            RadioListTile<PlayerBackgroundType>(
              title: const Text('纯色背景'),
              subtitle: const Text('使用自定义纯色'),
              value: PlayerBackgroundType.solidColor,
              groupValue: currentType,
              onChanged: (value) async {
                await backgroundService.setBackgroundType(value!);
                setState(() {});
                widget.onChanged();
              },
            ),
            
            // 纯色选择器（仅在选择纯色时显示）
            if (currentType == PlayerBackgroundType.solidColor) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: OutlinedButton.icon(
                  onPressed: _showSolidColorPicker,
                  icon: Icon(
                    Icons.palette,
                    color: backgroundService.solidColor,
                  ),
                  label: const Text('选择颜色'),
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // 图片背景（赞助用户独享）
            RadioListTile<PlayerBackgroundType>(
              title: Row(
                children: [
                  const Text('图片背景'),
                  if (!isSponsor) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: const Text(
                        '赞助独享',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                !isSponsor
                    ? '成为赞助用户即可使用自定义图片背景'
                    : (backgroundService.mediaPath != null && backgroundService.isImage
                        ? '已设置自定义图片'
                        : '未设置图片'),
              ),
              value: PlayerBackgroundType.image,
              groupValue: currentType,
              enabled: isSponsor, // 非赞助用户禁用
              onChanged: isSponsor
                  ? (value) async {
                      await backgroundService.setBackgroundType(value!);
                      setState(() {});
                      widget.onChanged();
                    }
                  : null,
            ),
            
            // 视频背景（赞助用户独享）
            RadioListTile<PlayerBackgroundType>(
              title: Row(
                children: [
                  const Text('视频背景'),
                  if (!isSponsor) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: const Text(
                        '赞助独享',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                !isSponsor
                    ? '成为赞助用户即可使用自定义视频背景'
                    : (backgroundService.mediaPath != null && backgroundService.isVideo
                        ? '已设置自定义视频'
                        : '未设置视频'),
              ),
              value: PlayerBackgroundType.video,
              groupValue: currentType,
              enabled: isSponsor, // 非赞助用户禁用
              onChanged: isSponsor
                  ? (value) async {
                      await backgroundService.setBackgroundType(value!);
                      setState(() {});
                      widget.onChanged();
                    }
                  : null,
            ),
                
            // 媒体选择和模糊设置（仅在选择图片或视频背景时显示）
            if (currentType == PlayerBackgroundType.image || currentType == PlayerBackgroundType.video) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 选择媒体按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectBackgroundMedia,
                            icon: Icon(currentType == PlayerBackgroundType.image ? Icons.image : Icons.video_library),
                            label: Text(currentType == PlayerBackgroundType.image ? '选择图片' : '选择视频'),
                          ),
                        ),
                        if (backgroundService.mediaPath != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              await backgroundService.clearMediaBackground();
                              setState(() {});
                              widget.onChanged();
                            },
                            icon: const Icon(Icons.clear),
                            tooltip: '清除${currentType == PlayerBackgroundType.image ? '图片' : '视频'}',
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 模糊程度调节
                    Text(
                      '模糊程度: ${backgroundService.blurAmount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Slider(
                      value: backgroundService.blurAmount,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      label: backgroundService.blurAmount.toStringAsFixed(0),
                      onChanged: (value) async {
                        await backgroundService.setBlurAmount(value);
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
                    Text(
                      '0 = 清晰，50 = 最模糊',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  /// 显示纯色选择器
  Future<void> _showSolidColorPicker() async {
    final backgroundService = PlayerBackgroundService();
    Color? selectedColor;

    final isFluent = Platform.isWindows && ThemeManager().isFluentFramework;

    if (isFluent) {
      await fluent_ui.showDialog(
        context: context,
        builder: (context) => fluent_ui.ContentDialog(
          title: const Text('选择纯色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('预设颜色'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Colors.grey[900]!,
                    Colors.black,
                    Colors.blue[900]!,
                    Colors.purple[900]!,
                    Colors.red[900]!,
                    Colors.green[900]!,
                    Colors.orange[900]!,
                    Colors.teal[900]!,
                  ].map((color) => GestureDetector(
                    onTap: () {
                      selectedColor = color;
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color == backgroundService.solidColor
                              ? Colors.white.withOpacity(0.6)
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                fluent_ui.Button(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCustomColorPicker();
                  },
                  child: const Text('自定义颜色'),
                ),
              ],
            ),
          ),
          actions: [
            fluent_ui.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择纯色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 预设颜色
                const Text(
                  '预设颜色',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Colors.grey[900]!,
                    Colors.black,
                    Colors.blue[900]!,
                    Colors.purple[900]!,
                    Colors.red[900]!,
                    Colors.green[900]!,
                    Colors.orange[900]!,
                    Colors.teal[900]!,
                  ].map((color) => InkWell(
                    onTap: () {
                      selectedColor = color;
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color == backgroundService.solidColor
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                
                const SizedBox(height: 20),
                
                // 自定义颜色按钮
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCustomColorPicker();
                  },
                  icon: const Icon(Icons.palette),
                  label: const Text('自定义颜色'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    }

    if (selectedColor != null) {
      await backgroundService.setSolidColor(selectedColor!);
      setState(() {});
      widget.onChanged();
    }
  }
  
  /// 显示自定义颜色选择器（调色盘）
  Future<void> _showCustomColorPicker() async {
    final backgroundService = PlayerBackgroundService();
    Color pickerColor = backgroundService.solidColor;

    final isFluent = Platform.isWindows && ThemeManager().isFluentFramework;
    if (isFluent) {
      await fluent_ui.showDialog(
        context: context,
        builder: (context) => fluent_ui.ContentDialog(
          title: const Text('自定义颜色'),
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
            fluent_ui.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            fluent_ui.FilledButton(
              onPressed: () async {
                await backgroundService.setSolidColor(pickerColor);
                setState(() {});
                widget.onChanged();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('自定义颜色'),
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
                await backgroundService.setSolidColor(pickerColor);
                setState(() {});
                widget.onChanged();
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
  }

  /// 选择背景媒体（图片或视频）
  Future<void> _selectBackgroundMedia() async {
    final backgroundService = PlayerBackgroundService();
    final isVideo = backgroundService.backgroundType == PlayerBackgroundType.video;
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isVideo
          ? ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v']
          : ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
      dialogTitle: isVideo ? '选择背景视频' : '选择背景图片',
    );

    if (result != null && result.files.single.path != null) {
      final mediaPath = result.files.single.path!;
      await backgroundService.setMediaBackground(mediaPath);
      setState(() {});
      widget.onChanged();
      
      if (mounted) {
        final isFluent = Platform.isWindows && ThemeManager().isFluentFramework;
        
        if (isFluent) {
          fluent_ui.displayInfoBar(
            context,
            builder: (context, close) => fluent_ui.InfoBar(
              title: Text(isVideo ? '背景视频已设置' : '背景图片已设置'),
              severity: fluent_ui.InfoBarSeverity.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isVideo ? '背景视频已设置' : '背景图片已设置'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
  
  /// 选择背景图片（兼容旧代码）
  Future<void> _selectBackgroundImage() async {
    await _selectBackgroundMedia();
  }
}

