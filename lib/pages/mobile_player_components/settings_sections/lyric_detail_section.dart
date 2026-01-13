import 'package:flutter/material.dart';
import '../../../services/lyric_style_service.dart';

/// 歌词细节设置区域 - Material Design Expressive 风格
/// 现代化滑块设计，带圆形数值徽章
class LyricDetailSection extends StatelessWidget {
  const LyricDetailSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: LyricStyleService(),
      builder: (context, _) {
        final styleService = LyricStyleService();
        
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
                      Icons.text_fields_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '歌词细节',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // 字号调节
                _buildSliderSection(
                  context: context,
                  icon: Icons.format_size_rounded,
                  label: '歌词字号',
                  value: styleService.fontSize,
                  displayValue: '${styleService.fontSize.toInt()} px',
                  min: 24.0,
                  max: 48.0,
                  divisions: 24,
                  accentColor: colorScheme.primary,
                  onChanged: (v) => styleService.setFontSize(v),
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                
                const SizedBox(height: 20),
                
                // 视觉模糊强度
                _buildSliderSection(
                  context: context,
                  icon: Icons.blur_on_rounded,
                  label: '视觉模糊',
                  value: styleService.blurSigma,
                  displayValue: styleService.blurSigma.toStringAsFixed(1),
                  min: 0.0,
                  max: 10.0,
                  divisions: 20,
                  accentColor: colorScheme.secondary,
                  onChanged: (v) => styleService.setBlurSigma(v),
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                
                const SizedBox(height: 20),
                
                // 行间距调节
                _buildLineHeightSection(
                  context: context,
                  styleService: styleService,
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建滑块区域
  Widget _buildSliderSection({
    required BuildContext context,
    required IconData icon,
    required String label,
    required double value,
    required String displayValue,
    required double min,
    required double max,
    required int divisions,
    required Color accentColor,
    required ValueChanged<double> onChanged,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签行
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // 圆形数值徽章
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.2),
                    accentColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 滑块
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            inactiveTrackColor: colorScheme.surfaceContainerHigh,
            thumbColor: accentColor,
            overlayColor: accentColor.withOpacity(0.15),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// 构建行间距区域（带自动/手动切换）
  Widget _buildLineHeightSection({
    required BuildContext context,
    required LyricStyleService styleService,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final accentColor = colorScheme.tertiary;
    final isAuto = styleService.autoLineHeight;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签行
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.format_line_spacing_rounded,
                color: accentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '歌词行间距',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // 分段按钮：自动/手动
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSegmentButton(
                    label: '自动',
                    icon: Icons.auto_awesome_rounded,
                    isSelected: isAuto,
                    onTap: () => styleService.setAutoLineHeight(true),
                    colorScheme: colorScheme,
                    accentColor: accentColor,
                  ),
                  _buildSegmentButton(
                    label: '手动',
                    icon: Icons.edit_rounded,
                    isSelected: !isAuto,
                    onTap: () => styleService.setAutoLineHeight(false),
                    colorScheme: colorScheme,
                    accentColor: accentColor,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // 数值显示
        if (!isAuto)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.2),
                      accentColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${styleService.lineHeight.toInt()} px',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        
        // 滑块
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: isAuto
                ? colorScheme.outline.withOpacity(0.5)
                : accentColor,
            inactiveTrackColor: colorScheme.surfaceContainerHigh,
            thumbColor: isAuto
                ? colorScheme.outline.withOpacity(0.5)
                : accentColor,
            overlayColor: accentColor.withOpacity(0.15),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 4,
            ),
            disabledActiveTrackColor: colorScheme.outline.withOpacity(0.3),
            disabledInactiveTrackColor: colorScheme.surfaceContainerHigh,
            disabledThumbColor: colorScheme.outline.withOpacity(0.5),
          ),
          child: Slider(
            value: styleService.lineHeight,
            min: 60.0,
            max: 180.0,
            onChanged: isAuto ? null : (v) => styleService.setLineHeight(v),
          ),
        ),
      ],
    );
  }

  /// 构建分段按钮
  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? accentColor
                  : colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? accentColor
                    : colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
