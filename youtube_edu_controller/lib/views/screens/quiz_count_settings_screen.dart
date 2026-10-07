import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_config.dart';
import '../../services/storage/local_storage_service.dart';

/// 타이머 만료 시 한 번에 출제되는 퀴즈 문제 수 설정 화면 (#73).
class QuizCountSettingsScreen extends StatefulWidget {
  const QuizCountSettingsScreen({super.key});

  @override
  State<QuizCountSettingsScreen> createState() =>
      _QuizCountSettingsScreenState();
}

class _QuizCountSettingsScreenState extends State<QuizCountSettingsScreen> {
  int _questionCount = AppConfig.defaultQuizQuestionCount;
  bool _isSaving = false;
  late TextEditingController _countController;
  String? _errorText;

  static const List<int> _presetCounts = [1, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController();
    _loadCount();
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _loadCount() async {
    final count = LocalStorageService().getQuizQuestionCount();
    if (!mounted) return;
    setState(() {
      _questionCount = count;
      _countController.text = count.toString();
    });
  }

  bool _validateInput(String value) {
    if (value.isEmpty) {
      setState(() => _errorText = '값을 입력해주세요');
      return false;
    }
    final parsed = int.tryParse(value);
    if (parsed == null) {
      setState(() => _errorText = '숫자만 입력해주세요');
      return false;
    }
    if (parsed < AppConfig.minQuizQuestionCount) {
      setState(() =>
          _errorText = '최소 ${AppConfig.minQuizQuestionCount}문제 이상이어야 합니다');
      return false;
    }
    if (parsed > AppConfig.maxQuizQuestionCount) {
      setState(() =>
          _errorText = '최대 ${AppConfig.maxQuizQuestionCount}문제까지 설정할 수 있습니다');
      return false;
    }
    setState(() => _errorText = null);
    return true;
  }

  Future<void> _saveCount(int count) async {
    setState(() {
      _isSaving = true;
    });
    await LocalStorageService().setQuizQuestionCount(count);
    if (!mounted) return;
    setState(() {
      _questionCount = count;
      _countController.text = count.toString();
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('한 번에 $count문제씩 출제하도록 저장되었습니다.')),
    );
  }

  void _onInputSubmitted(String value) {
    if (_validateInput(value)) {
      _saveCount(int.parse(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈 문제 수 설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const Text(
            '타이머가 만료될 때 한 번에 출제되는 문제 수를 설정하세요.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '문제 수',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText:
                                '${AppConfig.minQuizQuestionCount}~${AppConfig.maxQuizQuestionCount}',
                            suffixText: '문제',
                            errorText: _errorText,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          enabled: !_isSaving,
                          onSubmitted: _onInputSubmitted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _onInputSubmitted(_countController.text),
                        child: const Text('저장'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppConfig.minQuizQuestionCount}문제 ~ '
                    '${AppConfig.maxQuizQuestionCount}문제 사이로 설정 가능',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '추천 문제 수',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final count in _presetCounts)
                ChoiceChip(
                  label: Text('$count문제'),
                  selected: _questionCount == count,
                  onSelected: _isSaving
                      ? null
                      : (selected) {
                          if (!selected) return;
                          _saveCount(count);
                        },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.amber.withValues(alpha: 0.12),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '문제 수를 늘리면 영상 재생이 더 오래 중단됩니다. '
                      '학습 효과와 집중 시간을 함께 고려해 설정하세요.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
