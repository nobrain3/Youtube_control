import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../firestore/account_sync_service.dart';
import 'google_auth_service.dart';

/// 화면에 그대로 보여줄 수 있는 인증 오류.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 보호자 계정 인증 (#99).
///
/// - 이메일/비밀번호 가입은 보호자 계정만 받는다 (아동 이메일 직접 수집 안 함, #18).
/// - Google 로그인은 [GoogleAuthService](google_sign_in v6)로 계정과 토큰을
///   받은 뒤 Firebase에 넘긴다. YouTube 스코프가 같은 세션에 유지되므로
///   구독 추천·좋아요 기능이 그대로 동작한다.
/// - 로그인 성공 후 [AccountSyncService]로 보호자·아이 데이터를 동기화한다.
///   동기화 실패는 로그인을 막지 않는다 (로컬 설정으로 계속 사용).
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  AccountSyncService get _sync => AccountSyncService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// 보호자 이메일 가입. 가입과 동시에 첫 아이 프로필을 만든다.
  Future<User> signUpWithEmail({
    required String guardianName,
    required String email,
    required String password,
    required String childName,
    required int childGrade,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(guardianName.trim());
      await _syncAfterSignIn(
        user,
        displayName: guardianName.trim(),
        childName: childName.trim(),
        childGrade: childGrade,
      );
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await _syncAfterSignIn(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  /// Google 로그인. 사용자가 계정 선택을 취소하면 null을 반환한다.
  Future<User?> signInWithGoogle() async {
    try {
      final account = await GoogleAuthService().signIn();
      if (account == null) return null;

      final tokens = await account.authentication;
      if (tokens.idToken == null) {
        throw const AuthFailure(
          'Google 인증 정보를 받지 못했습니다. 잠시 후 다시 시도해주세요.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user!;
      await _syncAfterSignIn(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleAuthService().signOut();
    } catch (e) {
      // Google로 로그인하지 않은 경우에도 Firebase 로그아웃은 진행한다.
      debugPrint('Google 로그아웃 건너뜀: $e');
    }
    await _auth.signOut();
    await _sync.onSignedOut();
  }

  /// 현재 로컬 설정을 클라우드의 아이 프로필에 올린다.
  Future<void> pushSettings() => _sync.pushSettings(uid: currentUser?.uid);

  Future<void> _syncAfterSignIn(
    User user, {
    String? displayName,
    String? childName,
    int? childGrade,
  }) async {
    try {
      await _sync.onSignedIn(
        uid: user.uid,
        displayName: displayName ?? user.displayName ?? '',
        email: user.email ?? '',
        provider: user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'unknown',
        childName: childName,
        childGrade: childGrade,
      );
    } catch (e) {
      debugPrint('로그인 후 동기화 실패 (로컬 설정으로 계속 사용): $e');
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다. 로그인해주세요.';
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 6자 이상으로 입력해주세요.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'user-disabled':
        return '사용이 중지된 계정입니다.';
      case 'too-many-requests':
        return '시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      case 'account-exists-with-different-credential':
        return '같은 이메일로 다른 방식(이메일 또는 Google)으로 가입된 계정이 있습니다.';
      case 'operation-not-allowed':
        return '이 로그인 방식은 현재 사용할 수 없습니다.';
      default:
        return '인증 중 오류가 발생했습니다. (${e.code})';
    }
  }
}
