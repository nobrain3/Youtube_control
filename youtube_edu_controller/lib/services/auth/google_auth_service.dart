import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/youtube.readonly',
    ],
  );

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<void> initialize() async {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
    });

    // Try to sign in silently on app start
    await _googleSignIn.signInSilently();
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      return account;
    } catch (error) {
      throw Exception('Google 로그인 실패: $error');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (error) {
      throw Exception('로그아웃 실패: $error');
    }
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      _currentUser = null;
    } catch (error) {
      throw Exception('연결 해제 실패: $error');
    }
  }

  Future<String?> getAccessToken() async {
    if (_currentUser == null) return null;

    try {
      final auth = await _currentUser!.authentication;
      return auth.accessToken;
    } catch (error) {
      throw Exception('액세스 토큰 가져오기 실패: $error');
    }
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
