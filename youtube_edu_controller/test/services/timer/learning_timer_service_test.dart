import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:youtube_edu_controller/services/timer/learning_timer_service.dart';
import 'package:youtube_edu_controller/config/app_config.dart';

void main() {
  group('LearningTimerService', () {
    late LearningTimerService service;

    setUp(() {
      service = LearningTimerService();
    });

    tearDown(() {
      service.cleanup();
    });

    group('initial state', () {
      test('should have correct default values', () {
        final state = service.state;

        expect(state.isActive, false);
        expect(state.isBreakTime, false);
        expect(state.intervalMinutes, AppConfig.defaultStudyInterval);
        expect(state.currentSession, Duration.zero);
        expect(
          state.timeUntilBreak,
          Duration(minutes: AppConfig.defaultStudyInterval),
        );
      });
    });

    group('setInterval', () {
      test('should accept valid interval within bounds', () {
        service.setInterval(10);
        expect(service.state.intervalMinutes, 10);
      });

      test('should accept minimum interval', () {
        service.setInterval(AppConfig.minStudyInterval);
        expect(
          service.state.intervalMinutes,
          AppConfig.minStudyInterval,
        );
      });

      test('should accept maximum interval', () {
        service.setInterval(AppConfig.maxStudyInterval);
        expect(
          service.state.intervalMinutes,
          AppConfig.maxStudyInterval,
        );
      });

      test('should reject interval below minimum', () {
        final before = service.state.intervalMinutes;
        service.setInterval(AppConfig.minStudyInterval - 1);
        expect(service.state.intervalMinutes, before);
      });

      test('should reject interval above maximum', () {
        final before = service.state.intervalMinutes;
        service.setInterval(AppConfig.maxStudyInterval + 1);
        expect(service.state.intervalMinutes, before);
      });
    });

    group('start / pause / resume / stop', () {
      test('startSession should set isActive to true', () {
        fakeAsync((async) {
          service.startSession();
          async.elapse(const Duration(seconds: 1));
          expect(service.state.isActive, true);
        });
      });

      test('startSession should be idempotent (double start)', () {
        fakeAsync((async) {
          service.startSession();
          async.elapse(const Duration(seconds: 3));
          final after3 = service.state.currentSession;

          service.startSession(); // no-op
          async.elapse(const Duration(seconds: 2));

          // Should continue from ~5 seconds, not reset
          expect(
            service.state.currentSession.inSeconds,
            greaterThanOrEqualTo(4),
          );
          expect(after3.inSeconds, greaterThanOrEqualTo(2));
        });
      });

      test('pauseSession should stop the timer', () {
        fakeAsync((async) {
          service.startSession();
          async.elapse(const Duration(seconds: 5));
          service.pauseSession();

          final paused = service.state.currentSession;
          async.elapse(const Duration(seconds: 5));

          expect(service.state.isActive, false);
          expect(service.state.currentSession, paused);
        });
      });

      test('resumeSession should restart the timer', () {
        fakeAsync((async) {
          service.startSession();
          async.elapse(const Duration(seconds: 3));
          service.pauseSession();

          service.resumeSession();
          async.elapse(const Duration(seconds: 2));

          expect(service.state.isActive, true);
        });
      });

      test('stopSession should reset everything', () {
        fakeAsync((async) {
          service.startSession();
          async.elapse(const Duration(seconds: 10));
          service.stopSession();

          expect(service.state.isActive, false);
          expect(service.state.currentSession, Duration.zero);
          expect(service.state.isBreakTime, false);
        });
      });
    });

    group('break trigger', () {
      test('should trigger break after interval elapses', () {
        fakeAsync((async) {
          service.setInterval(1); // 1 minute
          service.startSession();
          async.elapse(const Duration(seconds: 60));

          expect(service.state.isBreakTime, true);
          expect(service.state.isActive, false);
          expect(service.state.timeUntilBreak, Duration.zero);
        });
      });

      test('completeBreak should reset for next cycle', () {
        fakeAsync((async) {
          service.setInterval(1);
          service.startSession();
          async.elapse(const Duration(seconds: 60));

          service.completeBreak();

          expect(service.state.isBreakTime, false);
          expect(service.state.currentSession, Duration.zero);
          expect(
            service.state.timeUntilBreak,
            const Duration(minutes: 1),
          );
        });
      });

      test('timeUntilBreak should decrease as session progresses', () {
        fakeAsync((async) {
          service.setInterval(1); // 1 minute
          service.startSession();
          async.elapse(const Duration(seconds: 30));

          expect(
            service.state.timeUntilBreak.inSeconds,
            30,
          );
        });
      });
    });

    group('cleanup', () {
      test('should cancel timer and reset state', () {
        fakeAsync((async) {
          service.startSession();
          async.elapse(const Duration(seconds: 5));
          service.cleanup();

          // After cleanup, state should still be whatever it was
          // but no more timer ticks
          final afterCleanup = service.state.currentSession;
          async.elapse(const Duration(seconds: 5));
          expect(service.state.currentSession, afterCleanup);
        });
      });
    });
  });
}
