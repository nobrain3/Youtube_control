# 큐타임 웹사이트 (#103, #107)

Google OAuth 앱 심사와 YouTube API 할당량 심사에 필요한 공개 페이지입니다.
Firebase Hosting(`qbeen-app`)으로 배포합니다.

| 경로 | 파일 | 용도 |
|---|---|---|
| `/` | `index.html` | 앱 홈페이지 (OAuth 동의 화면의 "애플리케이션 홈페이지") |
| `/privacy` | `privacy.html` | 개인정보처리방침 |
| `/terms` | `terms.html` | 이용약관 |

## 자리표시 (2026-10-24 채움)

| 자리표시 | 내용 |
|---|---|
| `__CONTACT_EMAIL__` | qtime.help@gmail.com |
| `__OPERATOR_NAME__` | 김진 |
| `__EFFECTIVE_DATE__` | 2026년 10월 24일 |

남은 자리표시 확인:

```bash
grep -rn "__[A-Z_]*__" hosting/
```

## 배포

```bash
npx -y firebase-tools@latest deploy --only hosting --project qbeen-app
```

도메인 `qtime.kr`은 Firebase 콘솔 > Hosting > 커스텀 도메인 추가로 연결하고,
앱의 `AppConfig.websiteUrl`과 Google 인증 플랫폼의 승인된 도메인을 같은 값으로 맞춥니다.
