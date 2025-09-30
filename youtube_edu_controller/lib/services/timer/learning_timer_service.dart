import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';

class LearningTimerService extends StateNotifier<LearningTimerState> {
  Timer? _timer;
  Duration _currentSession = Duration.zero;
  int _intervalMinutes = AppConfig.defaultStudyInterval;
  bool _isActive = false;

  LearningTimerService() : super(LearningTimerState.initial());

  void setInterval(int minutes) {
    if (minutes >= AppConfig.minStudyInterval &&
        minutes <= AppConfig.maxStudyInterval) {
      _intervalMinutes = minutes;
      state = state.copyWith(intervalMinutes: minutes);
    }
  }

  void startSession() {
    if (_isActive) return;

    _isActive = true;
    _currentSession = Duration.zero;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentSession = Duration(seconds: _currentSession.inSeconds + 1);

      state = state.copyWith(
        currentSession: _currentSession,
        isActive: true,
        timeUntilBreak: Duration(
          minutes: _intervalMinutes,
        ) - _currentSession,
      );

      if (_currentSession.inMinutes >= _intervalMinutes) {
        _triggerLearningBreak();
      }
    });
  }

  void pauseSession() {
    _timer?.cancel();
    _isActive = false;
    state = state.copyWith(isActive: false);
  }

  void resumeSession() {
    if (!_isActive) {
      startSession();
    }
  }

  void stopSession() {
    _timer?.cancel();
    _isActive = false;
    _currentSession = Duration.zero;

    state = state.copyWith(
      isActive: false,
      currentSession: Duration.zero,
      timeUntilBreak: Duration(minutes: _intervalMinutes),
      isBreakTime: false,
    );
  }

  void _triggerLearningBreak() {
    _timer?.cancel();
    _isActive = false;

    state = state.copyWith(
      isActive: false,
      isBreakTime: true,
      timeUntilBreak: Duration.zero,
    );
  }

  void completeBreak() {
    _currentSession = Duration.zero;
    state = state.copyWith(
      isBreakTime: false,
      currentSession: Duration.zero,
      timeUntilBreak: Duration(minutes: _intervalMinutes),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class LearningTimerState {
  final Duration currentSession;
  final Duration timeUntilBreak;
  final int intervalMinutes;
  final bool isActive;
  final bool isBreakTime;

  const LearningTimerState({
    required this.currentSession,
    required this.timeUntilBreak,
    required this.intervalMinutes,
    required this.isActive,
    required this.isBreakTime,
  });

  factory LearningTimerState.initial() {
    return LearningTimerState(
      currentSession: Duration.zero,
      timeUntilBreak: Duration(minutes: AppConfig.defaultStudyInterval),
      intervalMinutes: AppConfig.defaultStudyInterval,
      isActive: false,
      isBreakTime: false,
    );
  }

  LearningTimerState copyWith({
    Duration? currentSession,
    Duration? timeUntilBreak,
    int? intervalMinutes,
    bool? isActive,
    bool? isBreakTime,
  }) {
    return LearningTimerState(
      currentSession: currentSession ?? this.currentSession,
      timeUntilBreak: timeUntilBreak ?? this.timeUntilBreak,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      isActive: isActive ?? this.isActive,
      isBreakTime: isBreakTime ?? this.isBreakTime,
    );
  }
}

final learningTimerProvider = StateNotifierProvider<LearningTimerService, LearningTimerState>(
  (ref) => LearningTimerService(),
);