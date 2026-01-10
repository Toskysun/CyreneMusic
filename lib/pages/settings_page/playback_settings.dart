import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import '../../widgets/fluent_settings_card.dart';
import '../../widgets/cupertino/cupertino_settings_widgets.dart';
import '../../services/audio_quality_service.dart';
import '../../models/song_detail.dart';
import '../../utils/theme_manager.dart';
import '../../widgets/material/material_settings_widgets.dart';


/// 播放设置组件
class PlaybackSettings extends StatelessWidget {
  const PlaybackSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final isFluent = fluent_ui.FluentTheme.maybeOf(context) != null;
    final isCupertino = ThemeManager().isCupertinoFramework;

    if (isFluent) {
      return FluentSettingsGroup(
        title: '播放',
        children: [
          FluentSettingsTile(
            icon: Icons.high_quality,
            title: '音质选择',
            subtitle:
                '${AudioQualityService().getQualityName()} - ${AudioQualityService().getQualityDescription()}',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAudioQualityDialogFluent(context),
          ),
        ],
      );
    }

    if (isCupertino) {
      return _buildCupertinoUI(context);
    }

    return MD3SettingsSection(
      children: [
        MD3SettingsTile(
          leading: const Icon(Icons.high_quality_outlined),
          title: '音质选择',
          subtitle: '${AudioQualityService().getQualityName()} - ${AudioQualityService().getQualityDescription()}',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAudioQualityDialog(context),
        ),
      ],
    );
  }

  /// 构建 Cupertino UI 版本
  Widget _buildCupertinoUI(BuildContext context) {
    return CupertinoSettingsTile(
      icon: CupertinoIcons.music_note_2,
      iconColor: CupertinoColors.systemPurple,
      title: '音质选择',
      subtitle: '${AudioQualityService().getQualityName()} - ${AudioQualityService().getQualityDescription()}',
      showChevron: true,
      onTap: () => _showAudioQualityDialogCupertino(context),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showAudioQualityDialog(BuildContext context) {
    final currentQuality = AudioQualityService().currentQuality;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择音质'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AudioQuality>(
              title: const Text('标准音质'),
              subtitle: const Text('128kbps，节省流量'),
              value: AudioQuality.standard,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('音质设置已更新'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
            ),
            RadioListTile<AudioQuality>(
              title: const Text('极高音质'),
              subtitle: const Text('320kbps，推荐'),
              value: AudioQuality.exhigh,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('音质设置已更新'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
            ),
            RadioListTile<AudioQuality>(
              title: const Text('无损音质'),
              subtitle: const Text('FLAC，音质最佳'),
              value: AudioQuality.lossless,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('音质设置已更新'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAudioQualityDialogFluent(BuildContext context) {
    final currentQuality = AudioQualityService().currentQuality;

    fluent_ui.showDialog(
      context: context,
      builder: (context) {
        return fluent_ui.ContentDialog(
          title: const Text('选择音质'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [Text('标准音质'), Text('128kbps，节省流量')],
                ),
                checked: currentQuality == AudioQuality.standard,
                onChanged: (v) {
                  AudioQualityService().setQuality(AudioQuality.standard);
                  Navigator.pop(context);
                },
              ),
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [Text('极高音质'), Text('320kbps，推荐')],
                ),
                checked: currentQuality == AudioQuality.exhigh,
                onChanged: (v) {
                  AudioQualityService().setQuality(AudioQuality.exhigh);
                  Navigator.pop(context);
                },
              ),
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [Text('无损音质'), Text('FLAC，音质最佳')],
                ),
                checked: currentQuality == AudioQuality.lossless,
                onChanged: (v) {
                  AudioQualityService().setQuality(AudioQuality.lossless);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            fluent_ui.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 显示 Cupertino 风格的音质选择对话框
  void _showAudioQualityDialogCupertino(BuildContext context) {
    final currentQuality = AudioQualityService().currentQuality;
    
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择音质'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              AudioQualityService().setQuality(AudioQuality.standard);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentQuality == AudioQuality.standard)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark, size: 18),
                  ),
                const Text('标准音质'),
                const SizedBox(width: 8),
                Text(
                  '128kbps，节省流量',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              AudioQualityService().setQuality(AudioQuality.exhigh);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentQuality == AudioQuality.exhigh)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark, size: 18),
                  ),
                const Text('极高音质'),
                const SizedBox(width: 8),
                Text(
                  '320kbps，推荐',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              AudioQualityService().setQuality(AudioQuality.lossless);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentQuality == AudioQuality.lossless)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark, size: 18),
                  ),
                const Text('无损音质'),
                const SizedBox(width: 8),
                Text(
                  'FLAC，音质最佳',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

