import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_edu_controller/models/study_session_model.dart';

void main() {
  group('StudySession', () {
    late StudySession sampleSession;
    late DateTime startTime;
    late DateTime endTime;

    setUp(() {
      startTime = DateTime(2024, 1, 15, 10, 0, 0);
      endTime = DateTime(2024, 1, 15, 10, 30, 0);
      sampleSession = StudySession(
        id: 's1',
        userId: 'u1',
        videoId: 'vid1',
        videoTitle: 'Math Lesson 1',
        subject: 'Mathematics',
        currentVideoPosition: 120,
        watchedDuration: const Duration(minutes: 25),
        startTime: startTime,
        endTime: endTime,
        questionsAnswered: 10,
        correctAnswers: 7,
        pointsEarned: 70,
      );
    });

    group('fromJson / toJson round-trip', () {
      test('should serialize and deserialize all fields', () {
        final json = sampleSession.toJson();
        final restored = StudySession.fromJson(json);

        expect(restored.id, sampleSession.id);
        expect(restored.userId, sampleSession.userId);
        expect(restored.videoId, sampleSession.videoId);
        expect(restored.videoTitle, sampleSession.videoTitle);
        expect(restored.subject, sampleSession.subject);
        expect(restored.currentVideoPosition, 120);
        expect(restored.watchedDuration, const Duration(minutes: 25));
        expect(restored.startTime, startTime);
        expect(restored.endTime, endTime);
        expect(restored.questionsAnswered, 10);
        expect(restored.correctAnswers, 7);
        expect(restored.pointsEarned, 70);
      });

      test('should handle null optional fields', () {
        final session = StudySession(
          id: 's2',
          userId: 'u1',
          videoId: 'vid2',
          videoTitle: 'Korean Lesson',
          startTime: startTime,
          questionsAnswered: 0,
          correctAnswers: 0,
          pointsEarned: 0,
        );

        final json = session.toJson();
        expect(json['subject'], isNull);
        expect(json['currentVideoPosition'], isNull);
        expect(json['watchedDuration'], isNull);
        expect(json['endTime'], isNull);

        final restored = StudySession.fromJson(json);
        expect(restored.subject, isNull);
        expect(restored.currentVideoPosition, isNull);
        expect(restored.watchedDuration, isNull);
        expect(restored.endTime, isNull);
      });

      test('should store watchedDuration as milliseconds', () {
        final json = sampleSession.toJson();
        expect(json['watchedDuration'], 25 * 60 * 1000);
      });
    });

    group('accuracy', () {
      test('should return 0.0 when no questions answered', () {
        final session = StudySession(
          id: 's3',
          userId: 'u1',
          videoId: 'vid1',
          videoTitle: 'Test',
          startTime: startTime,
          questionsAnswered: 0,
          correctAnswers: 0,
          pointsEarned: 0,
        );

        expect(session.accuracy, 0.0);
      });

      test('should calculate accuracy correctly (7/10 = 0.7)', () {
        expect(sampleSession.accuracy, 0.7);
      });

      test('should return 1.0 for perfect score', () {
        final session = sampleSession.copyWith(
          questionsAnswered: 5,
          correctAnswers: 5,
        );
        expect(session.accuracy, 1.0);
      });
    });

    group('sessionDuration', () {
      test('should return null when endTime is null', () {
        final session = StudySession(
          id: 's4',
          userId: 'u1',
          videoId: 'vid1',
          videoTitle: 'Test',
          startTime: startTime,
          questionsAnswered: 0,
          correctAnswers: 0,
          pointsEarned: 0,
        );

        expect(session.sessionDuration, isNull);
      });

      test('should return correct duration', () {
        expect(sampleSession.sessionDuration, const Duration(minutes: 30));
      });
    });

    group('copyWith', () {
      test('should copy with changed fields', () {
        final copied = sampleSession.copyWith(
          questionsAnswered: 20,
          correctAnswers: 15,
        );

        expect(copied.questionsAnswered, 20);
        expect(copied.correctAnswers, 15);
        // Unchanged fields
        expect(copied.id, sampleSession.id);
        expect(copied.videoTitle, sampleSession.videoTitle);
      });

      test('should keep original values when no args provided', () {
        final copied = sampleSession.copyWith();

        expect(copied.id, sampleSession.id);
        expect(copied.userId, sampleSession.userId);
        expect(copied.videoId, sampleSession.videoId);
        expect(copied.questionsAnswered, sampleSession.questionsAnswered);
      });
    });
  });
}
