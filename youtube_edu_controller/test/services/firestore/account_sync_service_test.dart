import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qbeen/services/firestore/account_sync_service.dart';
import 'package:qbeen/services/firestore/user_repository.dart';
import 'package:qbeen/services/storage/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AccountSyncService', () {
    late FakeFirebaseFirestore firestore;
    late UserRepository repository;
    late LocalStorageService storage;
    late AccountSyncService sync;
    const uid = 'guardian-1';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
      firestore = FakeFirebaseFirestore();
      repository = UserRepository(firestore: firestore);
      sync = AccountSyncService(repository: repository, storage: storage);
    });

    Future<void> signIn({String? childName, int? childGrade}) {
      return sync.onSignedIn(
        uid: uid,
        displayName: '김보호',
        email: 'parent@example.com',
        provider: 'password',
        childName: childName,
        childGrade: childGrade,
      );
    }

    group('first sign-in (no child in cloud)', () {
      test('creates child from local settings and remembers it', () async {
        await storage.setStudyInterval(25);
        await storage.setQuizQuestionCount(4);

        await signIn(childName: '민준', childGrade: 5);

        final childId = storage.getActiveChildId();
        expect(childId, isNotNull);
        final child = await repository.getChild(uid, childId!);
        expect(child!.name, '민준');
        expect(child.grade, 5);
        expect(child.studyIntervalMinutes, 25);
        expect(child.quizQuestionCount, 4);
      });

      test('applies signup grade to local storage', () async {
        await signIn(childName: '민준', childGrade: 6);
        expect(storage.getUserGrade(), 6);
      });

      test('uses default child name when none is given (Google sign-in)',
          () async {
        await signIn();
        final child = await repository.getFirstChild(uid);
        expect(child!.name, '우리 아이');
      });
    });

    group('returning sign-in (child exists in cloud)', () {
      test('restores cloud settings into local storage', () async {
        final childId = await repository.createChild(
          uid: uid,
          name: '민준',
          grade: 2,
          studyIntervalMinutes: 30,
          quizQuestionCount: 6,
        );
        // 새 기기라 로컬 값이 기본값인 상황
        await storage.setUserGrade(3);
        await storage.setStudyInterval(15);
        await storage.setQuizQuestionCount(3);

        await signIn();

        expect(storage.getActiveChildId(), childId);
        expect(storage.getUserGrade(), 2);
        expect(storage.getStudyInterval(), 30);
        expect(storage.getQuizQuestionCount(), 6);
      });

      test('does not create a second child', () async {
        await repository.createChild(
          uid: uid,
          name: '민준',
          grade: 2,
          studyIntervalMinutes: 30,
          quizQuestionCount: 6,
        );

        await signIn(childName: '다른 이름', childGrade: 5);

        final children =
            await firestore.collection('users/$uid/children').get();
        expect(children.docs.length, 1);
      });
    });

    group('pushSettings', () {
      test('uploads local settings to active child', () async {
        await signIn(childName: '민준', childGrade: 4);
        await storage.setQuizQuestionCount(8);
        await storage.setStudyInterval(40);

        await sync.pushSettings(uid: uid);

        final child =
            await repository.getChild(uid, storage.getActiveChildId()!);
        expect(child!.quizQuestionCount, 8);
        expect(child.studyIntervalMinutes, 40);
      });

      test('does nothing when signed out', () async {
        await sync.pushSettings(uid: null);
        final users = await firestore.collection('users').get();
        expect(users.docs, isEmpty);
      });
    });

    test('onSignedOut clears active child id', () async {
      await signIn(childName: '민준', childGrade: 4);
      expect(storage.getActiveChildId(), isNotNull);

      await sync.onSignedOut();

      expect(storage.getActiveChildId(), isNull);
    });
  });
}
