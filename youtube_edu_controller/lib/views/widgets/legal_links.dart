import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';

/// 이용약관·개인정보처리방침 페이지를 연다 (#103).
Future<void> openLegalPage(BuildContext context, String url) async {
  final launched =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('페이지를 열 수 없습니다')),
    );
  }
}

/// "계속하면 이용약관과 개인정보처리방침에 동의하게 됩니다" 안내 (Google 로그인용).
class LegalConsentNotice extends StatelessWidget {
  const LegalConsentNotice({super.key, this.prefix = '계속하면 큐비엔의 '});

  final String prefix;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    final link = base?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: '이용약관',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openLegalPage(context, AppConfig.termsUrl),
          ),
          const TextSpan(text: '과 '),
          TextSpan(
            text: '개인정보처리방침',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openLegalPage(context, AppConfig.privacyPolicyUrl),
          ),
          const TextSpan(text: '에 동의하게 됩니다.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
