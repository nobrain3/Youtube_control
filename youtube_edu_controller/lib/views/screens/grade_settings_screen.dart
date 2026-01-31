import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/storage/local_storage_service.dart';

class GradeSettingsScreen extends StatefulWidget {
  const GradeSettingsScreen({super.key});

  @override
  State<GradeSettingsScreen> createState() => _GradeSettingsScreenState();
}

class _GradeSettingsScreenState extends State<GradeSettingsScreen> {
  int _selectedGrade = 3;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGrade();
  }

  Future<void> _loadGrade() async {
    final storage = LocalStorageService();
    final grade = storage.getUserGrade();
    if (!mounted) return;
    setState(() {
      _selectedGrade = grade;
    });
  }

  Future<void> _saveGrade(int grade) async {
    setState(() {
      _isSaving = true;
    });
    await LocalStorageService().setUserGrade(grade);
    if (!mounted) return;
    setState(() {
      _selectedGrade = grade;
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('학년 설정이 저장되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradeEntries = AppConfig.gradeLevels.entries.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('나이/학년 설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const Text(
            '현재 학년에 맞는 난이도로 문제를 출제합니다.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final entry in gradeEntries)
                  RadioListTile<int>(
                    value: entry.key,
                    groupValue: _selectedGrade,
                    title: Text(entry.value),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            _saveGrade(value);
                          },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
