import 'package:flutter_test/flutter_test.dart';
import 'package:qtime/utils/app_logger.dart';

void main() {
  // 실제 키 형식이지만 가짜 값. 저장소 secret scanning에 걸리지 않도록 런타임에 조립한다.
  final googleKey = 'AIza${'x' * 35}';
  final openAiKey = 'sk-${'a' * 40}';
  const accessToken = 'ya29.a0AfB_byC-token.value';

  group('redactSecrets', () {
    test('URL 쿼리의 key 파라미터를 마스킹한다', () {
      final uri = 'https://www.googleapis.com/youtube/v3/videos'
          '?part=snippet&key=$googleKey&regionCode=KR';

      final result = redactSecrets('HttpException: Connection closed, uri = $uri');

      expect(result, isNot(contains(googleKey)));
      expect(result, contains('key=***'));
      expect(result, contains('part=snippet'));
      expect(result, contains('regionCode=KR'));
    });

    test('Map.toString 형태의 key 값을 마스킹한다', () {
      final params = {'part': 'snippet', 'key': 'short-test-key', 'maxResults': 20};

      final result = redactSecrets('요청 파라미터: $params');

      expect(result, isNot(contains('short-test-key')));
      expect(result, contains('key: ***'));
      expect(result, contains('maxResults: 20'));
    });

    test('Bearer 토큰과 access_token 파라미터를 마스킹한다', () {
      final result = redactSecrets(
        'Authorization: Bearer $accessToken / ?access_token=$accessToken',
      );

      expect(result, isNot(contains(accessToken)));
      expect(result, contains('Bearer ***'));
      expect(result, contains('access_token=***'));
    });

    test('문맥 없이 등장한 Google·OpenAI API 키도 마스킹한다', () {
      final result = redactSecrets('google=$googleKey openai $openAiKey');

      expect(result, isNot(contains(googleKey)));
      expect(result, isNot(contains(openAiKey)));
    });

    test('비밀값이 없는 메시지와 pageToken·cacheKey는 그대로 둔다', () {
      const message = 'cacheKey=uploads_UC123 pageToken=CAoQAA 캐시 히트';

      expect(redactSecrets(message), message);
    });
  });
}
