import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/audio_source_service.dart';
import '../services/auth_service.dart';
import '../services/persistent_storage_service.dart';
import '../utils/theme_manager.dart';
import 'settings_page/audio_source_settings_page.dart';
import 'auth/auth_page.dart';

/// 移动端初始配置引导页
/// 
/// 多步引导流程：主题选择 → 配置音源 → 登录 → 进入主应用
class MobileSetupPage extends StatefulWidget {
  const MobileSetupPage({super.key});

  @override
  State<MobileSetupPage> createState() => _MobileSetupPageState();
}

class _MobileSetupPageState extends State<MobileSetupPage> {
  /// 引导步骤
  /// 0 = 主题选择
  /// 1 = 欢迎/音源配置入口
  /// 2 = 音源配置中
  /// 3 = 登录中
  /// 4 = 协议确认中
  int _currentStep = 0;
  
  /// 主题是否已选择
  bool _themeSelected = false;

  @override
  void initState() {
    super.initState();
    // 检查主题是否已配置过
    _checkThemeConfigured();
    // 监听音源配置和登录状态变化
    AudioSourceService().addListener(_onStateChanged);
    AuthService().addListener(_onStateChanged);
  }
  
  /// 检查主题是否已配置过（通过检查本地存储）
  void _checkThemeConfigured() {
    final storage = PersistentStorageService();
    final hasThemeConfig = storage.containsKey('mobile_theme_framework');
    if (hasThemeConfig) {
      setState(() {
        _themeSelected = true;
        _currentStep = 1; // 跳到音源配置步骤
      });
    }
  }

  @override
  void dispose() {
    AudioSourceService().removeListener(_onStateChanged);
    AuthService().removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {
        // 如果音源已配置且在配置步骤，自动进入下一步
        if (_currentStep == 2 && AudioSourceService().isConfigured) {
          _currentStep = 1; // 返回欢迎页（音源入口）
        }
        // 如果登录已完成且在登录步骤，自动进入协议页
        if (_currentStep == 3 && AuthService().isLoggedIn) {
          _currentStep = 4; 
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final isCupertino = (Platform.isIOS || Platform.isAndroid) && themeManager.isCupertinoFramework;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 主题选择页面
    if (_currentStep == 0 && !_themeSelected) {
      return _buildThemeSelectionPage(context, isDark);
    }

    // 音源配置页面
    if (_currentStep == 2) {
      return AudioSourceSettingsContent(
        onBack: () => setState(() => _currentStep = 1),
        embed: false,
      );
    }

    // 登录页面
    if (_currentStep == 3) {
      return _buildLoginPage(context, isCupertino, isDark);
    }

    // 协议确认页面
    if (_currentStep == 4) {
      return _buildAgreementPage(context, isCupertino, colorScheme, isDark);
    }

    // 欢迎/引导页面（音源配置入口）
    return _buildWelcomePage(context, isCupertino, colorScheme, isDark);
  }

  /// 构建主题选择页面
  Widget _buildThemeSelectionPage(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🎨',
                    style: TextStyle(fontSize: 64),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 标题
              Text(
                '选择您的界面风格',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // 副标题
              Text(
                '您可以随时在设置中更改',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Material Design 选项
              _buildThemeOptionCard(
                context: context,
                title: 'Material Design',
                subtitle: 'Google 风格，现代简约',
                icon: Icons.android,
                color: Colors.green,
                isDark: isDark,
                onTap: () => _selectTheme(MobileThemeFramework.material),
              ),
              
              const SizedBox(height: 16),
              
              // Cupertino 选项
              _buildThemeOptionCard(
                context: context,
                title: 'Cupertino',
                subtitle: 'Apple 风格，精致优雅',
                icon: Icons.apple,
                color: ThemeManager.iosBlue,
                isDark: isDark,
                onTap: () => _selectTheme(MobileThemeFramework.cupertino),
              ),
              
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建主题选项卡片
  Widget _buildThemeOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
          ),
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
  
  /// 选择主题
  void _selectTheme(MobileThemeFramework framework) async {
    final themeManager = ThemeManager();
    themeManager.setMobileThemeFramework(framework);
    
    // Material Design 启用 Material You 自适应主题色
    // Cupertino 使用固定的 iOS 蓝色，无需跟随系统
    if (framework == MobileThemeFramework.material) {
      await themeManager.setFollowSystemColor(true, context: context);
    } else {
      await themeManager.setFollowSystemColor(false);
    }
    
    setState(() {
      _themeSelected = true;
      _currentStep = 1; // 进入音源配置入口
    });
  }

  /// 构建欢迎引导页面
  Widget _buildWelcomePage(BuildContext context, bool isCupertino, ColorScheme colorScheme, bool isDark) {
    final audioConfigured = AudioSourceService().isConfigured;
    final isLoggedIn = AuthService().isLoggedIn;

    // 决定当前显示的引导内容
    String title;
    String subtitle;
    String buttonText;
    VoidCallback onButtonPressed;
    bool showSkip = true;

    if (!audioConfigured) {
      // 第一步：配置音源
      title = '欢迎使用 Cyrene Music';
      subtitle = '开始前，请先配置音源以解锁全部功能';
      buttonText = '配置音源';
      onButtonPressed = () => setState(() => _currentStep = 2);
    } else if (!isLoggedIn) {
      // 第二步：登录
      title = '音源配置完成 ✓';
      subtitle = '登录账号以同步您的收藏和播放记录';
      buttonText = '登录 / 注册';
      onButtonPressed = () => setState(() => _currentStep = 3);
    } else {
      // 全部完成（理论上不会到达这里，因为 main.dart 会跳转）
      title = '准备就绪!';
      subtitle = '开始探索音乐世界吧';
      buttonText = '下一步';
      onButtonPressed = () => setState(() => _currentStep = 4);
      showSkip = false;
    }

    return Scaffold(
      backgroundColor: isCupertino
          ? (isDark ? CupertinoColors.black : CupertinoColors.systemGroupedBackground)
          : colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🤔',
                    style: TextStyle(
                      fontSize: 64,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 进度指示器
              _buildStepIndicator(_themeSelected, audioConfigured, isLoggedIn, isDark, colorScheme),
              
              const SizedBox(height: 24),
              
              // 标题
              Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // 副标题
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(flex: 2),
              
              // 主按钮
              _buildMainButton(context, isCupertino, buttonText, onButtonPressed),
              
              const SizedBox(height: 16),
              
              // 跳过按钮
              if (showSkip)
                TextButton(
                  onPressed: () => _showSkipConfirmation(context, isCupertino),
                  child: Text(
                    '稍后再说',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 14,
                    ),
                  ),
                ),
              
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建步骤指示器
  Widget _buildStepIndicator(bool themeSelected, bool audioConfigured, bool isLoggedIn, bool isDark, ColorScheme colorScheme) {
    // 当前步骤的高亮色：Material 使用主题色，Cupertino 使用 iOS 蓝
    final themeManager = ThemeManager();
    final currentStepColor = themeManager.isCupertinoFramework 
        ? ThemeManager.iosBlue 
        : colorScheme.primary;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 主题选择步骤
        _buildStepDot(
          isCompleted: themeSelected,
          isCurrent: !themeSelected,
          isDark: isDark,
          currentStepColor: currentStepColor,
        ),
        Container(
          width: 32,
          height: 2,
          color: themeSelected 
              ? (isDark ? Colors.white54 : Colors.black38)
              : (isDark ? Colors.white24 : Colors.black12),
        ),
        // 音源配置步骤
        _buildStepDot(
          isCompleted: audioConfigured,
          isCurrent: themeSelected && !audioConfigured,
          isDark: isDark,
          currentStepColor: currentStepColor,
        ),
        Container(
          width: 32,
          height: 2,
          color: audioConfigured 
              ? (isDark ? Colors.white54 : Colors.black38)
              : (isDark ? Colors.white24 : Colors.black12),
        ),
        // 登录步骤
        _buildStepDot(
          isCompleted: isLoggedIn,
          isCurrent: audioConfigured && !isLoggedIn,
          isDark: isDark,
          currentStepColor: currentStepColor,
        ),
      ],
    );
  }

  Widget _buildStepDot({
    required bool isCompleted,
    required bool isCurrent,
    required bool isDark,
    required Color currentStepColor,
  }) {
    Color color;
    if (isCompleted) {
      color = Colors.green;
    } else if (isCurrent) {
      color = currentStepColor;
    } else {
      color = isDark ? Colors.white24 : Colors.black12;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: isCompleted
          ? const Icon(Icons.check, size: 8, color: Colors.white)
          : null,
    );
  }

  /// 构建登录页面
  Widget _buildLoginPage(BuildContext context, bool isCupertino, bool isDark) {
    return Scaffold(
      backgroundColor: isCupertino
          ? (isDark ? CupertinoColors.black : CupertinoColors.systemGroupedBackground)
          : Theme.of(context).colorScheme.surface,
      appBar: isCupertino
          ? CupertinoNavigationBar(
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _currentStep = 1),
                child: const Icon(CupertinoIcons.back),
              ),
              middle: const Text('登录'),
              backgroundColor: Colors.transparent,
              border: null,
            ) as PreferredSizeWidget?
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep = 1),
              ),
              title: const Text('登录'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: const AuthPage(initialTab: 0),
    );
  }

  Widget _buildMainButton(BuildContext context, bool isCupertino, String text, VoidCallback onPressed) {
    if (isCupertino) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSkipConfirmation(BuildContext context, bool isCupertino) {
    final audioConfigured = AudioSourceService().isConfigured;
    String message;
    
    if (!audioConfigured) {
      message = '不配置音源将无法播放在线音乐。您可以稍后在设置中配置。';
    } else {
      message = '不登录将无法同步收藏和播放记录。您可以稍后在设置中登录。';
    }

    if (isCupertino) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('跳过配置'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _skipSetup();
              },
              child: const Text('确认跳过'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('跳过配置'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _skipSetup();
              },
              child: const Text('确认跳过'),
            ),
          ],
        ),
      );
    }
  }

  /// 构建协议确认页面
  Widget _buildAgreementPage(BuildContext context, bool isCupertino, ColorScheme colorScheme, bool isDark) {
    return Scaffold(
      backgroundColor: isCupertino
          ? (isDark ? CupertinoColors.black : CupertinoColors.systemGroupedBackground)
          : colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            // Emoji 😋
            const Center(
              child: Text(
                '😋',
                style: TextStyle(fontSize: 64),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '配置完成',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '在开始之前，请认真看完它：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // 协议正文容器
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('一、数据来源'),
                      _buildSectionBody('1.1 本项目的各官方平台在线数据来源原理是从其公开服务器中拉取数据（与未登录状态在官方平台 APP 获取的数据相同），经过对数据简单地筛选与合并后进行展示，因此本项目不对数据的合法性、准确性负责。'),
                      _buildSectionBody('1.2 本项目本身没有获取某个音频数据的能力，本项目使用的在线音频数据来源来自软件设置内“自定义源”设置所选择的“源”返回的在线链接。例如播放某首歌，本项目所做的只是将希望播放的歌曲名、艺术家等信息传递给“源”，若“源”返回了一个链接，则本项目将认为这就是该歌曲的音频数据而进行使用，至于这是不是正确的音频数据本项目无法校验其准确性，所以使用本项目的过程中可能会出现希望播放的音频与实际播放的音频不对应或者无法播放的问题。'),
                      _buildSectionBody('1.3 本项目的非官方平台数据（例如“我的列表”内列表）来自使用者本地系统或者使用者连接的同步服务，本项目不对这些数据的合法性、准确性负责。'),
                      
                      _buildSectionTitle('二、版权数据'),
                      _buildSectionBody('2.1 使用本项目的过程中可能会产生版权数据。对于这些版权数据，本项目不拥有它们的所有权。为了避免侵权，使用者务必在 24 小时内 清除使用本项目的过程中所产生的版权数据。'),
                      
                      _buildSectionTitle('三、音乐平台别名'),
                      _buildSectionBody('3.1 本项目内的官方音乐平台别名为本项目内对官方音乐平台的一个称呼，不包含恶意。如果官方音乐平台觉得不妥，可联系本项目更改或移除。'),
                      
                      _buildSectionTitle('四、资源使用'),
                      _buildSectionBody('4.1 本项目内使用的部分包括但不限于字体、图片等资源来源于互联网。如果出现侵权可联系本项目移除。'),
                      
                      _buildSectionTitle('五、免责声明'),
                      _buildSectionBody('5.1 由于使用本项目产生的包括由于本协议或由于使用或无法使用本项目而引起的任何性质的任何直接、间接、特殊、偶然或结果性损害（包括但不限于因商誉损失、停工、计算机故障或故障引起的损害赔偿，或任何及所有其他商业损害或损失）由使用者负责。'),
                      
                      _buildSectionTitle('六、使用限制'),
                      _buildSectionBody('6.1 本项目完全免费，且开源发布于 GitHub 面向全世界人用作对技术的学习交流。本项目不对项目内的技术可能存在违反当地法律法规的行为作保证。'),
                      _buildSectionBody('6.2 禁止在违反当地法律法规的情况下使用本项目。 对于使用者在明知或不知当地法律法规不允许的情况下使用本项目所造成的任何违法违规行为由使用者承担，本项目不承担由此造成的任何直接、间接、特殊、偶然或结果性责任。'),
                      
                      _buildSectionTitle('七、版权保护'),
                      _buildSectionBody('7.1 音乐平台不易，请尊重版权，支持正版。'),
                      
                      _buildSectionTitle('八、非商业性质'),
                      _buildSectionBody('8.1 本项目仅用于对技术可行性的探索及研究，不接受任何商业（包括但不限于广告等）合作及捐赠。'),
                      
                      _buildSectionTitle('九、接受协议'),
                      _buildSectionBody('9.1 若你使用了本项目，即代表你接受本协议。'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 确认按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _buildMainButton(
                context, 
                isCupertino, 
                '接受协议并进入', 
                () async {
                  // 持久化协议确认为 true
                  final storage = PersistentStorageService();
                  await storage.setBool('terms_accepted', true);
                  
                  // 触发监听以切换 MobileAppGate
                  AudioSourceService().notifyListeners();
                  AuthService().notifyListeners();
                }
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        body,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _skipSetup() {
    // 通知跳过 - 触发 main.dart 中的状态更新来进入主应用
    // 这里通过 notifyListeners 来触发 AnimatedBuilder 重建
    AudioSourceService().notifyListeners();
    AuthService().notifyListeners();
  }
}
