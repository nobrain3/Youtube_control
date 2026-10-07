import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/child_profile.dart';

/// 보호자·아이 데이터의 Firestore 접근 계층 (#99).
///
/// 데이터 구조:
/// ```
/// users/{uid}                     보호자 프로필
/// users/{uid}/children/{childId}  아이 프로필 + 학습 설정
/// ```
///
/// 테스트에서는 [firestore]에 가짜 인스턴스를 주입한다.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _guardianRef(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _childrenRef(String uid) =>
      _guardianRef(uid).collection('children');

  /// 보호자 문서를 보장한다. 없으면 만들고, 있으면 이름·이메일만 갱신한다.
  /// `createdAt`은 최초 생성 시에만 기록한다.
  Future<void> ensureGuardian({
    required String uid,
    required String displayName,
    required String email,
    required String provider,
  }) async {
    final ref = _guardianRef(uid);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      await ref.update({
        'displayName': displayName,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await ref.set({
      'displayName': displayName,
      'email': email,
      'provider': provider,
      'role': 'guardian',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 가장 먼저 만들어진 아이 프로필. 없으면 null.
  ///
  /// 이번 범위에서는 아이 1명만 UI에 연결하므로 첫 번째 아이를 사용한다.
  Future<ChildProfile?> getFirstChild(String uid) async {
    final query =
        await _childrenRef(uid).orderBy('createdAt').limit(1).get();
    if (query.docs.isEmpty) return null;
    return ChildProfile.fromFirestore(query.docs.first);
  }

  Future<ChildProfile?> getChild(String uid, String childId) async {
    final doc = await _childrenRef(uid).doc(childId).get();
    if (!doc.exists) return null;
    return ChildProfile.fromFirestore(doc);
  }

  /// 아이 프로필을 만들고 생성된 ID를 반환한다.
  Future<String> createChild({
    required String uid,
    required String name,
    required int grade,
    required int studyIntervalMinutes,
    required int quizQuestionCount,
  }) async {
    final ref = await _childrenRef(uid).add({
      'name': name,
      'grade': grade,
      'settings': {
        'studyIntervalMinutes': studyIntervalMinutes,
        'quizQuestionCount': quizQuestionCount,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// 아이의 학년·학습 설정을 갱신한다. 전달된 값만 바꾼다.
  Future<void> updateChildSettings({
    required String uid,
    required String childId,
    int? grade,
    int? studyIntervalMinutes,
    int? quizQuestionCount,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (grade != null) updates['grade'] = grade;
    if (studyIntervalMinutes != null) {
      updates['settings.studyIntervalMinutes'] = studyIntervalMinutes;
    }
    if (quizQuestionCount != null) {
      updates['settings.quizQuestionCount'] = quizQuestionCount;
    }
    await _childrenRef(uid).doc(childId).update(updates);
  }
}
