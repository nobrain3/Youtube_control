import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../storage/local_storage_service.dart';

/// 기능별로 따로 요청하는 YouTube 권한 (#103).
///
/// YouTube 스코프는 Google의 민감한 권한이라 로그인 때 함께 요청하면
/// 앱 심사 전까지 "Google hasn't verified this app" 경고가 뜬다.
/// 로그인은 기본 스코프로만 하고, 아래 권한은 기능을 쓸 때 요청한다.
enum YouTubePermission {
  /// 구독 채널 기반 추천 (구독 목록 읽기)
  subscriptions('https://www.googleapis.com/auth/youtube.readonly'),

  /// 좋아요/싫어요 등록·조회 (videos.rate / videos.getRating)
  rating('https://www.googleapis.com/auth/youtube.force-ssl');

  const YouTubePermission(this.scope);

  final String scope;
}

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  static const List<String> _baseScopes = ['email', 'profile'];

  GoogleSignIn? _googleSignIn;
  StreamSubscription<GoogleSignInAccount?>? _userSubscription;
  Set<String> _grantedScopes = {};

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  GoogleSignIn get _signIn => _googleSignIn ??= _createSignIn();

  /// google_sign_in v6(Android)은 액세스 토큰을 초기화 때 넘긴 스코프로만 발급한다.
  /// 그래서 허용받은 YouTube 스코프가 바뀔 때마다 새 스코프 목록으로 다시 만든다.
  GoogleSignIn _createSignIn() {
    final signIn = GoogleSignIn(
      scopes: [..._baseScopes, ..._grantedScopes],
    );
    _userSubscription?.cancel();
    _userSubscription = signIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });
    return signIn;
  }

  /// 현재 스코프 목록으로 다시 만들고 세션을 연결한다.
  /// [interactive]면 조용한 연결이 실패했을 때 Google 로그인 화면으로 동의를 마무리한다.
  Future<bool> _rebuildSignIn({bool interactive = false}) async {
    _googleSignIn = _createSignIn();
    try {
      _currentUser = await _googleSignIn!.signInSilently();
      if (_currentUser == null && interactive) {
        _currentUser = await _googleSignIn!.signIn();
      }
    } catch (error) {
      debugPrint('Google 세션 재연결 실패: $error');
      _currentUser = null;
    }
    return isSignedIn;
  }

  /// 조용한 로그인. 기록된 YouTube 스코프 때문에 실패하면(계정 설정에서 권한을
  /// 해제한 경우 등) 기록을 지우고 기본 스코프로 한 번 더 시도한다.
  Future<bool> _signInSilentlyOrResetScopes() async {
    if (await _rebuildSignIn()) return true;
    if (_grantedScopes.isEmpty) return false;
    debugPrint('기록된 YouTube 권한으로 Google 연결 실패 → 권한 기록 초기화');
    _grantedScopes = {};
    await LocalStorageService().clearGrantedYouTubeScopes();
    return _rebuildSignIn();
  }

  Future<void> initialize() async {
    _grantedScopes = LocalStorageService().getGrantedYouTubeScopes().toSet();
    // Try to sign in silently on app start
    await _signInSilentlyOrResetScopes();
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _signIn.signIn();
      _currentUser = account;
      return account;
    } catch (error) {
      throw Exception('Google 로그인 실패: $error');
    }
  }

  Future<void> signOut() async {
    try {
      await _signIn.signOut();
      _currentUser = null;
      await _clearGrantedScopes();
    } catch (error) {
      throw Exception('로그아웃 실패: $error');
    }
  }

  Future<void> disconnect() async {
    try {
      await _signIn.disconnect();
      _currentUser = null;
      await _clearGrantedScopes();
    } catch (error) {
      throw Exception('연결 해제 실패: $error');
    }
  }

  /// 다른 Google 계정으로 로그인할 수 있으므로 로그아웃 시 허용 기록을 지운다.
  Future<void> _clearGrantedScopes() async {
    if (_grantedScopes.isEmpty) return;
    _grantedScopes = {};
    await LocalStorageService().clearGrantedYouTubeScopes();
    _googleSignIn = _createSignIn();
  }

  /// Firebase에는 Google로 로그인돼 있는데 이 객체의 세션이 없을 때
  /// (앱 재시작 후 자동 로그인 실패 등) 동의 화면 없이 조용히 다시 연결한다.
  Future<bool> restoreSession() async {
    if (isSignedIn) return true;
    return _signInSilentlyOrResetScopes();
  }

  bool hasPermission(YouTubePermission permission) {
    return isSignedIn && _grantedScopes.contains(permission.scope);
  }

  /// YouTube 권한을 요청한다. 이미 허용한 권한이면 동의 화면 없이 true를 반환한다.
  /// Google로 로그인하지 않았거나 사용자가 거부하면 false.
  Future<bool> requestPermission(YouTubePermission permission) async {
    if (!await restoreSession()) return false;
    if (_grantedScopes.contains(permission.scope)) return true;

    final granted = await _signIn.requestScopes([permission.scope]);
    if (!granted) return false;

    // 새 스코프가 토큰에 들어가도록 다시 연결한다. 실패하면 이전 상태로 되돌린다.
    final previous = _grantedScopes;
    _grantedScopes = {...previous, permission.scope};
    if (!await _rebuildSignIn(interactive: true)) {
      _grantedScopes = previous;
      await _rebuildSignIn();
      return false;
    }
    await LocalStorageService().setGrantedYouTubeScopes(_grantedScopes.toList());
    return true;
  }

  /// 앱에서 해당 권한을 더 이상 쓰지 않는다. Google 계정의 허용 자체는
  /// 계정 설정(myaccount.google.com/permissions)에서 해제해야 한다.
  Future<void> removePermission(YouTubePermission permission) async {
    if (!_grantedScopes.contains(permission.scope)) return;
    _grantedScopes = {..._grantedScopes}..remove(permission.scope);
    await LocalStorageService().setGrantedYouTubeScopes(_grantedScopes.toList());
    if (isSignedIn) await _rebuildSignIn();
  }

  /// 액세스 토큰. [permission]을 주면 그 권한을 허용받지 않은 경우 null을 반환한다.
  Future<String?> getAccessToken({YouTubePermission? permission}) async {
    if (_currentUser == null) return null;
    if (permission != null && !hasPermission(permission)) return null;

    try {
      final auth = await _currentUser!.authentication;
      return auth.accessToken;
    } catch (error) {
      // 토큰 가져오기 실패 시 null 반환 (fallback 로직이 동작하도록)
      debugPrint('액세스 토큰 가져오기 실패: $error');
      return null;
    }
  }

  /// 서버가 401로 거부한 토큰을 기기 캐시에서 지우고 새 토큰을 받는다.
  /// (계정 설정에서 권한을 해제하면 폐기된 토큰이 캐시에 남아 있을 수 있다)
  Future<String?> refreshAccessToken({YouTubePermission? permission}) async {
    final account = _currentUser;
    if (account == null) return null;
    try {
      // 현재 캐시된 액세스 토큰(=거부된 토큰)을 지운다
      await account.clearAuthCache();
    } catch (error) {
      debugPrint('토큰 캐시 삭제 실패: $error');
      return null;
    }
    return getAccessToken(permission: permission);
  }

  Future<String?> getIdToken() async {
    if (_currentUser == null) return null;

    try {
      final auth = await _currentUser!.authentication;
      return auth.idToken;
    } catch (error) {
      throw Exception('ID 토큰 가져오기 실패: $error');
    }
  }
}
