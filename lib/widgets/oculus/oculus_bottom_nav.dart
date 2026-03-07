import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Oculus 重构版：全宽顶部圆角款
/// 参考 E-Robo Wallet 截图实现，极致简约，仅图标
class OculusBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<OculusNavItem> items;

  const OculusBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // 视觉配置
    final Color backgroundColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final Color activeColor = isDark ? Colors.white : Colors.black;
    const Color inactiveColor = Color(0xFFCED0DE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64, // 导航栏内容高度
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      HapticFeedback.lightImpact();
                      onTap(index);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.asset(
                        item.svgAsset,
                        width: 26,
                        height: 26,
                        colorFilter: ColorFilter.mode(
                          isSelected ? activeColor : inactiveColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Oculus 导航项数据
class OculusNavItem {
  final String svgAsset;
  final String label;
  const OculusNavItem({
    required this.svgAsset,
    required this.label,
  });
}
