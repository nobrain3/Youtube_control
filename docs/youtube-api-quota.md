# YouTube API 할당량 산정과 증설 신청 준비 (#107)

YouTube Data API 할당량은 **Google Cloud 프로젝트 단위**다. 앱 사용자 전체가 기본 하루 10,000 units를 나눠 쓴다.

| 호출 방식 | 할당량이 차감되는 프로젝트 |
|---|---|
| API 키 (홈·검색·영상 정보·채널 정보) | `youtube-edu-control` (`.env`의 `YOUTUBE_API_KEY`) |
| OAuth 토큰 (보호자 구독 목록) | `qbeen-app` |

## 1. 기능별 호출 비용 (2026-10 코드 기준)

| 기능 | 호출 | units | 캐시 |
|---|---|---|---|
| 홈 첫 화면 (아이 채널 있음) | channels.list 1 + playlistItems.list (아이 채널 ≤5) + videos.list 1 | 3~7 | uploads 10분 |
| └ 발견용: 같은 분야 인기 | videos.list (좋아요 분야 조회) 1 + videos.list chart (분야 ≤3, 없으면 교육·전체) | 2~5 | 30분 |
| └ 발견용: 크리에이터 추천 채널 | channelSections.list (≤3) + channels 1 + playlistItems 2 + videos 1 | 4~7 | 추천 채널 6시간 |
| 홈 첫 화면 (아이 채널 없음) | videos.list chart=mostPopular | 1 | — |
| 홈 다음 페이지 (최대 4번) | 위와 비슷 (캐시 적중 시 감소) | 3~10 | |
| 클립 탭 (아이 채널 있음) | channels 1 + playlistItems (≤10) + videos 1 | 3~12 | uploads 10분 |
| 클립 탭 (아이 채널 없음) | videos.list chart | 1 | 5분 |
| 영상 재생 | videos.list (상세) | 1 | — |
| **검색** | **search.list** | **100** | — |
| 아이 채널 관리 화면 | channels.list | 1 | — |
| 보호자 구독 가져오기 | subscriptions.list (≤4페이지) | 1~4 | — |

캐시는 앱 메모리에만 있어 앱을 다시 켜면 사라진다 (#108에서 서버 공용 캐시로 개선).

## 2. 사용자당 하루 사용량 추정

가정: 하루 앱 실행 2회, 홈 스크롤 2페이지, 클립 1회, 영상 6개 재생, 검색 2회.

| 항목 | units |
|---|---|
| 홈 (2회 × 첫 화면 ~15 + 다음 페이지 ~6) | ~42 |
| 클립 (1회) | ~8 |
| 영상 재생 (6회) | 6 |
| 검색 (2회) | 200 |
| **합계** | **~256** |

- 기본 10,000 units로는 **하루 활성 사용자 약 40명**이 한계다.
- 검색이 사용량의 약 80%를 차지한다 → 검색 캐시·횟수 제한이 가장 효과가 크다 (#108).
- 검색을 빼면 사용자당 ~56 units → 약 180명.

| 목표 DAU | 필요 units/일 (현재 구조) | #108 적용 후 목표 |
|---|---|---|
| 100 | ~26,000 | ~8,000 |
| 1,000 | ~256,000 | ~60,000 |
| 10,000 | ~2,560,000 | ~500,000 |

(#108 적용 후 수치는 인기·채널 영상 공용 캐시 + 검색어 캐시 적중률 50%를 가정한 대략값)

## 3. 증설 신청 준비 (YouTube API Services 감사·할당량 증설 양식)

신청: https://support.google.com/youtube/contact/yt_api_form
안내: https://developers.google.com/youtube/v3/guides/quota_and_compliance_audits

### 준비물
- [ ] 공개된 홈페이지·개인정보처리방침·이용약관 (#103과 공통, `youtube_edu_controller/hosting/`)
- [ ] 앱 설명, 대상(보호자·아동), API 사용 목적
- [ ] API를 쓰는 화면 스크린샷 또는 시연 영상 (홈, 검색, 재생, 아이 채널)
- [ ] 위 2번의 사용량 산정 근거와 요청 units
- [ ] 신청할 프로젝트 결정: API 키가 있는 `youtube-edu-control` 그대로 쓸지,
      `qbeen-app`으로 키를 옮겨 한 프로젝트로 합칠지 (옮기면 신청도 `qbeen-app`으로)

### 정책 준수 점검 (YouTube API Services 개발자 정책)

| 항목 | 상태 |
|---|---|
| 비공식 앱 고지, YouTube 약관·Google 개인정보처리방침 링크 (#85) | ✅ 설정 > 앱 정보, 웹사이트 |
| 'YouTube' 상표를 앱 이름·아이콘에 쓰지 않음 (#81~#84) | ✅ 큐타임 |
| 공식 임베드 플레이어로만 재생 (스트림 직접 추출 금지) | ✅ `youtube_player_flutter`. 쓰지 않던 `youtube_explode_dart`/`chewie` 대체 플레이어는 #107에서 제거 |
| API 데이터 저장: ID만 저장, 메타데이터는 표시할 때 조회 (#104) | ✅ Firestore에는 영상·채널 ID와 평가만 |
| 앱 메모리 캐시는 최대 6시간 (메타데이터 30일 보관 한도 이내) | ✅ |
| 기기 로컬 시청 기록(제목·썸네일) 보관 기간 | ⚠️ 기간 제한 없음 → 30일 이내로 정리하거나 ID만 저장하도록 개선 필요 |
| 사용자 권한 해제 경로 안내 | ✅ 설정 > 아이 채널 > Google 계정 권한 관리, 개인정보처리방침 3항 |
| 개인정보처리방침에 YouTube API 사용 고지 | ✅ 3항 |
| 디버그 로그에 API 키 노출 | ✅ #109 (PR #111): `logDebug()`는 디버그 빌드에서만 출력, 키·토큰 마스킹 |
| 아동 대상 콘텐츠 표시 (madeForKids) | ⚠️ 검토 필요: 인기 영상은 아동용 필터가 없음 |
