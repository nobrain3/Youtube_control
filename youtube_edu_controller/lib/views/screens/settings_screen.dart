import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../config/app_routes.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/google_auth_service.dart';
import '../../services/storage/local_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _userGrade = 3;
  int _studyInterval = AppConfig.defaultStudyInterval;
  int _quizQuestionCount = AppConfig.defaultQuizQuestionCount;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = LocalStorageService();
    final grade = storage.getUserGrade();
    final interval = storage.getStudyInterval();
    final quizCount = storage.getQuizQuestionCount();
    if (!mounted) return;
    setState(() {
      _userGrade = grade;
      _studyInterval = interval;
      _quizQuestionCount = quizCount;
    });
  }

  Future<void> _openSettings(String route) async {
    await context.push(route);
    await _loadSettings();
  }

  String _gradeLabel(int grade) {
    return AppConfig.gradeLevels[grade] ?? '선택 안 함';
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠어요? 이 기기의 학습 설정은 그대로 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  /// 보호자 계정 섹션 (#99). 로그인 여부에 따라 계정 정보/로그인 버튼을 보여준다.
  Widget _buildAccountCard() {
    final user = AuthService().currentUser;
    if (user == null) {
      return Card(
        child: _SettingsTile(
          icon: Icons.login,
          title: '보호자 계정으로 로그인',
          subtitle: '로그인하면 학습 설정이 클라우드에 저장됩니다',
          onTap: () => context.go(AppRoutes.login),
        ),
      );
    }
    final isGoogle = AuthService().isGoogleUser;
    return Card(
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            title: user.displayName?.isNotEmpty == true ? user.displayName! : '보호자',
            subtitle: '${user.email ?? ''}${isGoogle ? ' · Google 계정' : ''}',
            showChevron: false,
          ),
          const Divider(height: 1),
          _SettingsTile(
            icon: Icons.logout,
            title: '로그아웃',
            subtitle: '이 기기에서 보호자 계정 로그아웃',
            onTap: _confirmSignOut,
          ),
        ],
      ),
    );
  }

  /// YouTube 권한을 켜거나 끈다 (#103). 켤 때는 Google 동의 화면이 뜰 수 있다.
  Future<void> _toggleYouTubePermission(
    YouTubePermission permission,
    bool enable,
  ) async {
    final auth = GoogleAuthService();
    try {
      if (enable) {
        final granted = await auth.requestPermission(permission);
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('권한을 허용하지 않았습니다')),
          );
        }
      } else {
        await auth.removePermission(permission);
      }
    } catch (e) {
      debugPrint('YouTube 권한 변경 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('권한 변경에 실패했습니다. 잠시 후 다시 시도해주세요')),
        );
      }
    }
    if (mounted) setState(() {});
  }

  /// Google 로그인 보호자에게만 보이는 YouTube 연결 섹션 (#103).
  Widget _buildYouTubeCard() {
    final auth = GoogleAuthService();
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.subscriptions_outlined),
            title: const Text('구독 채널 기반 추천'),
            subtitle: const Text('구독한 채널의 새 영상을 홈에 보여줍니다'),
            value: auth.hasPermission(YouTubePermission.subscriptions),
            onChanged: (value) => _toggleYouTubePermission(
                YouTubePermission.subscriptions, value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.thumb_up_alt_outlined),
            title: const Text('좋아요·싫어요 기록'),
            subtitle: const Text('재생 화면의 평가를 YouTube 계정에 남깁니다'),
            value: auth.hasPermission(YouTubePermission.rating),
            onChanged: (value) =>
                _toggleYouTubePermission(YouTubePermission.rating, value),
          ),
          const Divider(height: 1),
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Google 계정 권한 관리',
            subtitle: '허용한 권한을 Google 계정에서 완전히 해제합니다',
            onTap: () =>
                _openExternalLink('https://myaccount.google.com/permissions'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const _SectionHeader(title: '보호자 계정'),
          _buildAccountCard(),
          const SizedBox(height: 16),
          if (AuthService().isGoogleUser) ...[
            const _SectionHeader(title: 'YouTube 연결'),
            _buildYouTubeCard(),
            const SizedBox(height: 16),
          ],
          const _SectionHeader(title: '사용자 정보'),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.school_outlined,
                  title: '나이/학년 설정',
                  subtitle: _gradeLabel(_userGrade),
                  onTap: () => _openSettings(AppRoutes.settingsGrade),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '학습 설정'),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.timer_outlined,
                  title: '플레이 시간(타이머 간격)',
                  subtitle: '$_studyInterval분 간격',
                  onTap: () => _openSettings(AppRoutes.settingsTimer),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.quiz_outlined,
                  title: '퀴즈 문제 수',
                  subtitle: '한 번에 $_quizQuestionCount문제',
                  onTap: () => _openSettings(AppRoutes.settingsQuizCount),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '앱 정보'),
          Card(
            child: Column(
              children: [
                const _SettingsTile(
                  icon: Icons.info_outline,
                  title: '버전',
                  subtitle: 'v${AppConfig.appVersion}',
                  showChevron: false,
                ),
                const Divider(height: 1),
                // YouTube API Services 약관에 따른 비공식 앱 고지 및 Attribution
                const _SettingsTile(
                  icon: Icons.verified_outlined,
                  title: '비공식 앱 안내',
                  subtitle: '이 앱은 YouTube의 비공식 앱이며 Google LLC와 '
                      '제휴하거나 후원받지 않았습니다. YouTube 및 관련 상표는 '
                      'Google LLC의 자산입니다.',
                  showChevron: false,
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'YouTube 서비스 약관',
                  subtitle: 'YouTube API Services를 사용합니다',
                  onTap: () => _openExternalLink('https://www.youtube.com/t/terms'),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Google 개인정보처리방침',
                  subtitle: 'policies.google.com/privacy',
                  onTap: () => _openExternalLink('https://policies.google.com/privacy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _PoweredByNotice(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// YouTube API Services 약관이 요구하는 Attribution 고지.
class _PoweredByNotice extends StatelessWidget {
  const _PoweredByNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Powered by YouTube',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'YouTube는 Google LLC의 상표입니다',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black38,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: showChevron ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
