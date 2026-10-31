# Google OAuth 앱 심사 준비 (#103)

큐타임 Google 로그인 동의 화면을 "확인된 앱"으로 만들기 위한 제출 자료와 절차.
심사를 통과하면 "Google hasn't verified this app" 경고가 사라지고 사용자 100명 제한이 풀린다.

- 대상 프로젝트: `qbeen-app` (Google 인증 플랫폼)
- 관련: #107 (YouTube API 할당량 증설 — 홈페이지·개인정보처리방침 공통)

## 1. 요청하는 스코프

| 스코프 | 구분 | 언제 요청 | 용도 |
|---|---|---|---|
| `openid`, `email`, `profile` | 기본 (심사 불필요) | Google 로그인 | 보호자 계정 생성·식별 |
| `https://www.googleapis.com/auth/youtube.readonly` | **민감** | 보호자가 설정 > 아이 채널 > "보호자 YouTube 구독에서 골라 넣기"를 누를 때만 | 보호자 구독 채널 목록을 보여주고, 보호자가 고른 채널 ID만 아이 채널 목록에 저장 |

- #104에서 `youtube.force-ssl`(쓰기)은 제거했다. 앱은 보호자 YouTube 계정에 아무것도 쓰지 않는다.
- 구독 목록은 저장하지 않는다 (고른 채널 ID만 저장).

### 스코프 사용 이유 (제출용 문안, 영문)

> QTime (큐타임) is an educational video app used on a child's device and managed by a parent account.
> We request `youtube.readonly` only when the parent explicitly taps "Import from my YouTube subscriptions"
> in Settings. We call `subscriptions.list (mine=true)` to show the parent's subscribed channels in a
> picker. The parent selects which channels their child may see, and we store only the selected channel
> IDs under the child's profile. The subscription list itself is not stored, shared, or used for any
> other purpose. We never write to the user's YouTube account. A narrower scope is not available
> because reading a user's own subscriptions requires `youtube.readonly`.

## 2. 동의 화면(브랜딩) 설정

| 항목 | 값 |
|---|---|
| 앱 이름 | 큐타임 (상표 'YouTube' 미포함 — #81) |
| 사용자 지원 이메일 | qtime.help@gmail.com |
| 앱 로고 | 120×120 PNG, 큐타임 로고 (YouTube 로고 사용 금지) |
| 애플리케이션 홈페이지 | `https://qtime.kr/` |
| 개인정보처리방침 | `https://qtime.kr/privacy` |
| 서비스 약관 | `https://qtime.kr/terms` |
| 승인된 도메인 | `qtime.kr` (홈페이지·방침과 같은 도메인) |
| 개발자 연락처 | qtime.help@gmail.com |

웹사이트 원본: `youtube_edu_controller/hosting/` (배포 방법은 그 폴더의 README).

## 3. 절차

1. [x] 도메인 `qtime.kr` 구매(가비아, 2029-10까지) → Firebase Hosting 커스텀 도메인 추가, DNS(A·TXT) 설정
2. [x] 앱 전용 이메일 `qtime.help@gmail.com` → 웹사이트 자리표시 교체 (보호책임자 김진, 시행일 2026-10-24)
3. [x] 웹사이트 배포 (`firebase deploy --only hosting --project qbeen-app`) — qtime.kr HTTPS는 Firebase 확인·인증서 발급 대기
4. [x] 앱 `AppConfig.websiteUrl` = `https://qtime.kr`
5. [x] [Google Search Console](https://search.google.com/search-console)에서 도메인 소유권 확인 (DNS TXT, nobrain85@gmail.com)
   (심사 신청 계정과 같은 Google 계정)
6. [ ] Google 인증 플랫폼 > 브랜딩: 위 2번 표대로 입력, 승인된 도메인 추가
   - [x] 앱 이름 큐타임, 홈페이지·방침·약관, 승인된 도메인 `qtime.kr`, 개발자 연락처 저장 (2026-10-31)
   - [x] `qtime.help@gmail.com`을 `qbeen-app` 프로젝트 소유자로 추가
   - [x] 사용자 지원 이메일 qtime.help@gmail.com (qtime.help 계정으로 로그인해 변경, 로그인한 계정의 이메일만 선택 가능)
   - [ ] 앱 로고 업로드 (120×120 PNG)
7. [x] Google 인증 플랫폼 > 데이터 액세스: email·profile·openid + `youtube.readonly` 추가, 사용 이유 입력 (2026-10-31)
   - [ ] 영상 녹화 전 옛 클라이언트 `Android client for com.qbeen.app (debug)`와 Firebase 앱 `QBeeN Android` 삭제
     (콘솔 안내: 프로젝트의 모든 OAuth 클라이언트가 시연 영상에 포함되어야 함. 남은 클라이언트는 Android `kr.qtime.app`, 웹)
8. [ ] 시연 영상 녹화·업로드 (YouTube 일부공개)
9. [ ] 심사 신청 → 이메일로 오는 추가 질문에 답변 (보통 수일~수주)

## 4. 시연 영상 구성 (2~3분, 영어 자막 또는 내레이션 권장)

심사자는 영상에서 아래를 확인한다. 화면에 **OAuth 클라이언트 ID가 보이는 동의 화면 주소창**이 나와야 한다.

1. 앱 실행 → 로그인 화면 → "Google로 로그인"
2. Google 계정 선택 → 기본 권한 동의 화면 (이름·이메일·프로필)
3. 홈 화면 (아이 채널 기반 추천) — 보호자 YouTube 데이터는 아직 사용하지 않음을 설명
4. 설정 > 아이 채널 > 아이가 담은 채널 > "보호자 YouTube 구독에서 골라 넣기"
5. **`youtube.readonly` 동의 화면** — 앱 이름, 요청 권한이 보이게
6. 구독 채널 선택 시트에서 채널 몇 개 선택 → "넣기"
7. 아이 채널 목록에 추가된 채널 확인 → 홈에서 그 채널 영상이 추천되는 모습
8. 설정 > Google 계정 권한 관리 → 권한 해제 경로 안내

## 5. 함께 확인할 정책

- [Google API 서비스 사용자 데이터 정책](https://developers.google.com/terms/api-services-user-data-policy)
  — 제한적 사용(Limited Use) 문구: 개인정보처리방침 3항에 포함
- 아동 대상 앱: 계정은 보호자만 생성, 아이 정보는 보호자가 입력 (개인정보처리방침 2항)
- 앱 내 계정 삭제 기능은 아직 없음 — 방침에는 "이메일 요청으로 처리, 앱 내 삭제 제공 예정"으로 명시.
  Google Play 정책(계정 생성 앱은 앱·웹에서 삭제 경로 제공)을 위해 별도 구현 필요
