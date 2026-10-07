import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qbeen/services/firestore/user_repository.dart';

void main() {
  group('UserRepository', () {
    late FakeFirebaseFirestore firestore;
    late UserRepository repository;
    const uid = 'guardian-1';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = UserRepository(firestore: firestore);
    });

    group('ensureGuardian', () {
      test('creates guardian document with role and provider', () async {
        await repository.ensureGuardian(
          uid: uid,
          displayName: '김보호',
          email: 'parent@example.com',
          provider: 'password',
        );

        final doc = await firestore.collection('users').doc(uid).get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['displayName'], '김보호');
        expect(doc.data()!['email'], 'parent@example.com');
        expect(doc.data()!['provider'], 'password');
        expect(doc.data()!['role'], 'guardian');
        expect(doc.data()!['createdAt'], isNotNull);
      });

      test('updates name/email but keeps createdAt and provider when exists',
          () async {
        await repository.ensureGuardian(
          uid: uid,
          displayName: '처음 이름',
          email: 'old@example.com',
          provider: 'password',
        );
        final before = await firestore.collection('users').doc(uid).get();

        await repository.ensureGuardian(
          uid: uid,
          displayName: '바뀐 이름',
          email: 'new@example.com',
          provider: 'google.com',
        );

        final after = await firestore.collection('users').doc(uid).get();
        expect(after.data()!['displayName'], '바뀐 이름');
        expect(after.data()!['email'], 'new@example.com');
        expect(after.data()!['provider'], 'password');
        expect(after.data()!['createdAt'], before.data()!['createdAt']);
      });
    });

    group('children', () {
      test('getFirstChild returns null when no child exists', () async {
        expect(await repository.getFirstChild(uid), isNull);
      });

      test('createChild stores profile and settings', () async {
        final childId = await repository.createChild(
          uid: uid,
          name: '민준',
          grade: 4,
          studyIntervalMinutes: 20,
          quizQuestionCount: 5,
        );

        final child = await repository.getChild(uid, childId);
        expect(child, isNotNull);
        expect(child!.name, '민준');
        expect(child.grade, 4);
        expect(child.studyIntervalMinutes, 20);
        expect(child.quizQuestionCount, 5);
      });

      test('getFirstChild returns the earliest created child', () async {
        final firstId = await repository.createChild(
          uid: uid,
          name: '첫째',
          grade: 5,
          studyIntervalMinutes: 15,
          quizQuestionCount: 3,
        );
        await repository.createChild(
          uid: uid,
          name: '둘째',
          grade: 2,
          studyIntervalMinutes: 15,
          quizQuestionCount: 3,
        );

        final first = await repository.getFirstChild(uid);
        expect(first!.id, firstId);
        expect(first.name, '첫째');
      });

      test('updateChildSettings changes only provided fields', () async {
        final childId = await repository.createChild(
          uid: uid,
          name: '민준',
          grade: 4,
          studyIntervalMinutes: 20,
          quizQuestionCount: 5,
        );

        await repository.updateChildSettings(
          uid: uid,
          childId: childId,
          quizQuestionCount: 7,
        );

        final child = await repository.getChild(uid, childId);
        expect(child!.quizQuestionCount, 7);
        expect(child.grade, 4);
        expect(child.studyIntervalMinutes, 20);
        expect(child.name, '민준');
      });

      test('children of different guardians are isolated', () async {
        await repository.createChild(
          uid: uid,
          name: '우리 아이',
          grade: 3,
          studyIntervalMinutes: 15,
          quizQuestionCount: 3,
        );

        expect(await repository.getFirstChild('other-guardian'), isNull);
      });
    });
  });
}
