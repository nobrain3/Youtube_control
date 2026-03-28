import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_edu_controller/services/storage/local_storage_service.dart';
import 'package:youtube_edu_controller/models/user_model.dart';
import 'package:youtube_edu_controller/models/study_session_model.dart';

void main() {
  group('LocalStorageService', () {
    late LocalStorageService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = LocalStorageService();
      await service.init();
    });

    group('Settings', () {
      test('getStudyInterval should return default 15', () {
        expect(service.getStudyInterval(), 15);
      });

      test('setStudyInterval should persist value', () async {
        await service.setStudyInterval(25);
        expect(service.getStudyInterval(), 25);
      });

      test('getPreferredSubjects should return default [Mathematics]', () {
        expect(service.getPreferredSubjects(), ['Mathematics']);
      });

      test('setPreferredSubjects should persist value', () async {
        await service.setPreferredSubjects(['Korean', 'English']);
        expect(service.getPreferredSubjects(), ['Korean', 'English']);
      });

      test('getUserGrade should return default 3', () {
        expect(service.getUserGrade(), 3);
      });

      test('setUserGrade should persist value', () async {
        await service.setUserGrade(7);
        expect(service.getUserGrade(), 7);
      });

      test('getDifficultyLevel should return default 2', () {
        expect(service.getDifficultyLevel(), 2);
      });

      test('setDifficultyLevel should persist value', () async {
        await service.setDifficultyLevel(3);
        expect(service.getDifficultyLevel(), 3);
      });

      test('getThemeMode should return default system', () {
        expect(service.getThemeMode(), 'system');
      });

      test('setThemeMode should persist value', () async {
        await service.setThemeMode('dark');
        expect(service.getThemeMode(), 'dark');
      });

      test('isFirstLaunch should return true by default', () {
        expect(service.isFirstLaunch(), true);
      });

      test('setFirstLaunch should persist value', () async {
        await service.setFirstLaunch(false);
        expect(service.isFirstLaunch(), false);
      });
    });

    group('User CRUD', () {
      late User testUser;

      setUp(() {
        testUser = User(
          id: 'u1',
          username: 'testuser',
          email: 'test@example.com',
          birthDate: DateTime(2015, 3, 1),
          grade: 3,
          preferredSubjects: ['Mathematics', 'Science'],
          weakSubjects: ['Korean'],
          currentLevel: 5,
          totalPoints: 100,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 15),
        );
      });

      test('getCurrentUser should return null when no user saved', () {
        expect(service.getCurrentUser(), isNull);
      });

      test('saveUser and getCurrentUser should work together', () async {
        await service.saveUser(testUser);
        final loaded = service.getCurrentUser();

        expect(loaded, isNotNull);
        expect(loaded!.id, testUser.id);
        expect(loaded.username, testUser.username);
        expect(loaded.email, testUser.email);
        expect(loaded.grade, testUser.grade);
      });

      test('clearUser should remove the user', () async {
        await service.saveUser(testUser);
        await service.clearUser();

        expect(service.getCurrentUser(), isNull);
      });
    });

    group('StudySession CRUD', () {
      late StudySession testSession;

      setUp(() {
        testSession = StudySession(
          id: 's1',
          userId: 'u1',
          videoId: 'vid1',
          videoTitle: 'Test Video',
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 10, 30),
          questionsAnswered: 5,
          correctAnswers: 3,
          pointsEarned: 30,
        );
      });

      test('getStudySessions should return empty list initially', () async {
        final sessions = await service.getStudySessions();
        expect(sessions, isEmpty);
      });

      test('saveStudySession should add a session', () async {
        await service.saveStudySession(testSession);
        final sessions = await service.getStudySessions();

        expect(sessions, hasLength(1));
        expect(sessions[0].id, 's1');
      });

      test('should save multiple sessions', () async {
        await service.saveStudySession(testSession);
        await service.saveStudySession(testSession.copyWith(id: 's2'));

        final sessions = await service.getStudySessions();
        expect(sessions, hasLength(2));
      });

      test('getStudySessionsByUserId should filter by user', () async {
        await service.saveStudySession(testSession);
        await service.saveStudySession(
          testSession.copyWith(id: 's2', userId: 'u2'),
        );

        final sessions = await service.getStudySessionsByUserId('u1');
        expect(sessions, hasLength(1));
        expect(sessions[0].userId, 'u1');
      });

      test('updateStudySession should modify existing session', () async {
        await service.saveStudySession(testSession);
        final updated = testSession.copyWith(correctAnswers: 5);
        await service.updateStudySession(updated);

        final sessions = await service.getStudySessions();
        expect(sessions[0].correctAnswers, 5);
      });

      test('updateStudySession should no-op for non-existent id', () async {
        await service.saveStudySession(testSession);
        final other = testSession.copyWith(id: 'nonexistent');
        await service.updateStudySession(other);

        final sessions = await service.getStudySessions();
        expect(sessions, hasLength(1));
        expect(sessions[0].id, 's1');
      });
    });

    group('Watch History', () {
      test('getWatchHistory should return empty list initially', () {
        expect(service.getWatchHistory(), isEmpty);
      });

      test('addToWatchHistory should add a video', () async {
        await service.addToWatchHistory({
          'videoId': 'v1',
          'title': 'Test Video',
        });

        final history = service.getWatchHistory();
        expect(history, hasLength(1));
        expect(history[0]['videoId'], 'v1');
        expect(history[0]['watchedAt'], isNotNull);
      });

      test('duplicate video should move to front, not create duplicate',
          () async {
        await service.addToWatchHistory({
          'videoId': 'v1',
          'title': 'First',
        });
        await service.addToWatchHistory({
          'videoId': 'v2',
          'title': 'Second',
        });
        await service.addToWatchHistory({
          'videoId': 'v1',
          'title': 'First Again',
        });

        final history = service.getWatchHistory();
        expect(history, hasLength(2));
        expect(history[0]['videoId'], 'v1');
        expect(history[1]['videoId'], 'v2');
      });

      test('should limit history to 100 items', () async {
        for (int i = 0; i < 105; i++) {
          await service.addToWatchHistory({
            'videoId': 'v$i',
            'title': 'Video $i',
          });
        }

        final history = service.getWatchHistory();
        expect(history.length, 100);
        // Most recent should be first
        expect(history[0]['videoId'], 'v104');
      });

      test('should ignore entries with null or empty videoId', () async {
        await service.addToWatchHistory({'title': 'No ID'});
        await service.addToWatchHistory({'videoId': '', 'title': 'Empty ID'});

        expect(service.getWatchHistory(), isEmpty);
      });

      test('clearWatchHistory should remove all history', () async {
        await service.addToWatchHistory({
          'videoId': 'v1',
          'title': 'Test',
        });
        await service.clearWatchHistory();

        expect(service.getWatchHistory(), isEmpty);
      });
    });

    group('clearAllData', () {
      test('should clear everything', () async {
        await service.setStudyInterval(30);
        await service.setUserGrade(7);

        await service.clearAllData();

        expect(service.getStudyInterval(), 15); // default
        expect(service.getUserGrade(), 3); // default
      });
    });
  });
}
