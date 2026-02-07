import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_config.dart';
import '../../services/storage/local_storage_service.dart';

class TimerSettingsScreen extends StatefulWidget {
  const TimerSettingsScreen({super.key});

  @override
  State<TimerSettingsScreen> createState() => _TimerSettingsScreenState();
}

class _TimerSettingsScreenState extends State<TimerSettingsScreen> {
  int _studyInterval = AppConfig.defaultStudyInterval;
  bool _isSaving = false;
  late TextEditingController _intervalController;
  String? _errorText;

  static const List<int> _presetIntervals = [
    5,
    10,
    15,
    20,
    30,
    45,
    60,
  ];

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController();
    _loadInterval();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _loadInterval() async {
    final storage = LocalStorageService();
    final interval = storage.getStudyInterval();
    if (!mounted) return;
    setState(() {
      _studyInterval = interval;
      _intervalController.text = interval.toString();
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
    if (parsed < AppConfig.minStudyInterval) {
      setState(() => _errorText = '최소 ${AppConfig.minStudyInterval}분 이상이어야 합니다');
      return false;
    }
    if (parsed > AppConfig.maxStudyInterval) {
      setState(() => _errorText = '최대 ${AppConfig.maxStudyInterval}분까지 설정할 수 있습니다');
      return false;
    }
    setState(() => _errorText = null);
    return true;
  }

  Future<void> _saveInterval(int minutes) async {
    setState(() {
      _isSaving = true;
    });
    await LocalStorageService().setStudyInterval(minutes);
    if (!mounted) return;
    setState(() {
      _studyInterval = minutes;
      _intervalController.text = minutes.toString();
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('타이머 간격이 저장되었습니다.')),
    );
  }

  void _onInputSubmitted(String value) {
    if (_validateInput(value)) {
      _saveInterval(int.parse(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이 시간 설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const Text(
            '퀴즈가 나오는 간격을 설정하세요.',
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
                    '타이머 간격 (분)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _intervalController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: '${AppConfig.minStudyInterval}~${AppConfig.maxStudyInterval}',
                            suffixText: '분',
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
                            : () => _onInputSubmitted(_intervalController.text),
                        child: const Text('저장'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppConfig.minStudyInterval}분 ~ ${AppConfig.maxStudyInterval}분 사이로 설정 가능',
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
            '추천 간격',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final interval in _presetIntervals)
                ChoiceChip(
                  label: Text('$interval분'),
                  selected: _studyInterval == interval,
                  onSelected: _isSaving
                      ? null
                      : (selected) {
                          if (!selected) return;
                          _saveInterval(interval);
                        },
                ),
            ],
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
