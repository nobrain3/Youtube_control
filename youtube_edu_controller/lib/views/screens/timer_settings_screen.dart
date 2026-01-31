import 'package:flutter/material.dart';
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
    _loadInterval();
  }

  Future<void> _loadInterval() async {
    final storage = LocalStorageService();
    final interval = storage.getStudyInterval();
    if (!mounted) return;
    setState(() {
      _studyInterval = interval;
    });
  }

  Future<void> _saveInterval(int minutes) async {
    setState(() {
      _isSaving = true;
    });
    await LocalStorageService().setStudyInterval(minutes);
    if (!mounted) return;
    setState(() {
      _studyInterval = minutes;
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('타이머 간격이 저장되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minInterval = AppConfig.minStudyInterval.toDouble();
    final maxInterval = AppConfig.maxStudyInterval.toDouble();
    final divisions =
        ((AppConfig.maxStudyInterval - AppConfig.minStudyInterval) ~/ 5);

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '현재 간격',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('$_studyInterval분'),
                    ],
                  ),
                  Slider(
                    value: _studyInterval.toDouble(),
                    min: minInterval,
                    max: maxInterval,
                    divisions: divisions,
                    label: '$_studyInterval분',
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _studyInterval = value.round();
                            });
                          },
                    onChangeEnd: _isSaving
                        ? null
                        : (value) {
                            _saveInterval(value.round());
                          },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${AppConfig.minStudyInterval}분'),
                      Text('${AppConfig.maxStudyInterval}분'),
                    ],
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
