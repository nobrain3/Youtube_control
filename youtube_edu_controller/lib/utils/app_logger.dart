import 'package:flutter/foundation.dart';

/// 디버그 빌드에서만 콘솔에 남기는 로그 (#109).
///
/// `print`/`debugPrint`는 릴리스 빌드에서도 logcat에 기록되므로 앱 코드는
/// 이 함수로만 로그를 남긴다. 예외 메시지 등에 섞여 들어온 API 키·토큰은
/// [redactSecrets]로 마스킹한 뒤 출력한다.
void logDebug(String message) {
  if (!kDebugMode) return;
  debugPrint(redactSecrets(message));
}

const _mask = '***';

final _secretPatterns = <RegExp, String Function(Match)>{
  // URL 쿼리(`?key=...`)나 Map.toString(`{key: ...}`)에 들어간 비밀 파라미터
  RegExp(
    r'(?<![A-Za-z0-9_])(key|api_key|apikey|access_token|id_token|refresh_token)'
    r'''(["']?\s*[:=]\s*["']?)[^\s,&}"'#]+''',
    caseSensitive: false,
  ): (m) => '${m[1]}${m[2]}$_mask',
  RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false): (m) =>
      '${m[1]}$_mask',
  // 문맥 없이 단독으로 등장한 Google API 키 / OpenAI API 키
  RegExp(r'AIza[0-9A-Za-z\-_]{35}'): (_) => _mask,
  RegExp(r'sk-[A-Za-z0-9\-_]{20,}'): (_) => _mask,
};

/// 문자열에 포함된 API 키·OAuth 토큰을 `***`로 치환한다.
String redactSecrets(String text) {
  var result = text;
  _secretPatterns.forEach((pattern, replace) {
    result = result.replaceAllMapped(pattern, replace);
  });
  return result;
}
