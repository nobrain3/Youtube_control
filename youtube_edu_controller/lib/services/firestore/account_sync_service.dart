import 'package:flutter/foundation.dart';
import '../storage/local_storage_service.dart';
import 'user_repository.dart';

/// 로그인한 보호자 계정과 기기 로컬 설정 사이의 동기화 규칙 (#99).
///
/// - 클라우드에 아이 프로필이 **없으면** (첫 로그인): 로컬 설정으로 아이를 만든다.
/// - 클라우드에 아이 프로필이 **있으면** (재로그인·기기 변경): 클라우드 값을
///   로컬에 내려받는다.
/// - 설정을 바꾸면 로컬에 먼저 저장한 뒤 [pushSettings]로 클라우드에 올린다.
///
/// 동기화 실패가 로그인 자체를 막지 않도록 호출부에서 예외를 처리한다.
class AccountSyncService {
  AccountSyncService({
    UserRepository? repository,
    LocalStorageService? storage,
  })  : _repository = repository ?? UserRepository(),
        _storage = storage ?? LocalStorageService();

  final UserRepository _repository;
  final LocalStorageService _storage;

  /// 로그인 직후 호출한다.
  ///
  /// [childName], [childGrade]는 회원가입 시 입력받은 값으로, 새 아이를
  /// 만들 때만 사용한다.
  Future<void> onSignedIn({
    required String uid,
    required String displayName,
    required String email,
    required String provider,
    String? childName,
    int? childGrade,
  }) async {
    await _repository.ensureGuardian(
      uid: uid,
      displayName: displayName,
      email: email,
      provider: provider,
    );

    final existing = await _repository.getFirstChild(uid);
    if (existing == null) {
      if (childGrade != null) {
        await _storage.setUserGrade(childGrade);
      }
      final childId = await _repository.createChild(
        uid: uid,
        name: childName ?? '우리 아이',
        grade: _storage.getUserGrade(),
        studyIntervalMinutes: _storage.getStudyInterval(),
        quizQuestionCount: _storage.getQuizQuestionCount(),
      );
      await _storage.setActiveChildId(childId);
      return;
    }

    await _storage.setActiveChildId(existing.id);
    await _storage.setUserGrade(existing.grade);
    await _storage.setStudyInterval(existing.studyIntervalMinutes);
    await _storage.setQuizQuestionCount(existing.quizQuestionCount);
  }

  /// 로컬 설정을 현재 아이 프로필에 올린다. 로그인 상태가 아니면 아무것도 하지 않는다.
  Future<void> pushSettings({required String? uid}) async {
    final childId = _storage.getActiveChildId();
    if (uid == null || childId == null) return;
    try {
      await _repository.updateChildSettings(
        uid: uid,
        childId: childId,
        grade: _storage.getUserGrade(),
        studyIntervalMinutes: _storage.getStudyInterval(),
        quizQuestionCount: _storage.getQuizQuestionCount(),
      );
    } catch (e) {
      // 오프라인 등으로 실패해도 로컬 설정은 이미 저장되어 있으므로 무시한다.
      // (Firestore는 오프라인 쓰기를 큐에 담았다가 연결되면 재전송한다)
      debugPrint('설정 클라우드 동기화 실패: $e');
    }
  }

  /// 로그아웃 시 호출한다.
  Future<void> onSignedOut() async {
    await _storage.clearActiveChildId();
  }
}
