import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
              children: const [
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: '버전',
                  subtitle: 'v${AppConfig.appVersion}',
                  showChevron: false,
                ),
              ],
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
