import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../config/app_routes.dart';
import '../../services/storage/local_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _userGrade = 3;
  int _studyInterval = AppConfig.defaultStudyInterval;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = LocalStorageService();
    final grade = storage.getUserGrade();
    final interval = storage.getStudyInterval();
    if (!mounted) return;
    setState(() {
      _userGrade = grade;
      _studyInterval = interval;
    });
  }

  Future<void> _openSettings(String route) async {
    await context.push(route);
    await _loadSettings();
  }

  String _gradeLabel(int grade) {
    return AppConfig.gradeLevels[grade] ?? '선택 안 함';
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
