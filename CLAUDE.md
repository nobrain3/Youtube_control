# YouTube Edu Controller - Claude 작업 가이드

## 🚀 새 세션 시작 가이드

### 1. 즉시 실행할 명령어들
```bash
cd youtube_edu_controller
git status
git log --oneline -5
flutter doctor
```

### 2. 프로젝트 현황 파악 순서
1. `Read CLAUDE.md` (이 파일) - 전체 현황 파악
2. `기능명세서.md` 확인 - 프로젝트 요구사항
3. `README.md` 확인 - 설치 및 보안 가이드
4. 작업할 기능에 따라 해당 파일들만 선택적으로 읽기

## 📋 프로젝트 현재 상태 (2026-09-19 업데이트)

### 🎯 최근 완료된 작업
- **플랫폼 전략 확정 (ADR-001)** ✅ PR #88
  - Android/iOS 모두 자체 플레이어로 통일, OS 레벨 오버레이 방식 미채택
  - 기능명세서 1.5절에 결정·근거·트레이드오프 기록
- **테스트 인프라 구축** ✅ PR #87
  - Unit Test 70개 케이스 (models/services)
  - GitHub Actions CI (PR/push 시 analyze + test)
  - `/test` 스킬 추가
- **퀴즈 정답 시 자동 복귀** ✅ PR #86 (#72)
- **YouTube API 할당량 최적화** ✅ PR #80 (#79)
  - search.list → channels.list + playlistItems.list 대체
  - 홈+Shorts 1회 로드 약 1,600 → 33 units
- **재생탭 학습타이머 UI 제거** ✅ PR #75 (#74)
- **좋아요/싫어요 버튼** ✅ PR #71 (#69)
- **전체화면 문제 오버레이 시스템** ✅
  - 전체화면 모드에서 문제 화면 오버레이로 표시
  - Stack 기반 이중 레이어 아키텍처

### 🔧 현재 기술 스택
- **Frontend**: Flutter (Dart)
- **State Management**: Riverpod
- **UI**: flutter_screenutil, go_router
- **APIs**: YouTube Data API v3, Google OAuth, OpenAI API
- **Player**: youtube_player_flutter (주) + youtube_explode_dart/chewie (대체)
- **Test/CI**: flutter_test, GitHub Actions
- **Storage**: SharedPreferences (로컬)
- **Auth**: google_sign_in

### 🌳 브랜치 상태
- **기준 브랜치**: `main` (작업 시작 전 `git checkout main && git pull` 필수)
- **열린 PR**: #88 (문서 - 플랫폼 전략 ADR)
- **칸반보드**: Done 22 / Todo 54, 진행 중 작업 없음

> 브랜치·이슈 현황은 빠르게 바뀌므로 세션 시작 시 `git branch --show-current`,
> `gh pr list`, `gh issue list`로 실제 상태를 확인할 것

## 📁 핵심 파일 구조 및 역할

### 🎯 자주 수정하는 파일들
```
youtube_edu_controller/
├── lib/
│   ├── main.dart                     # 앱 진입점, Google Auth 초기화
│   ├── config/
│   │   ├── app_config.dart          # API 키 및 앱 설정 (환경변수)
│   │   ├── app_routes.dart          # 라우팅 설정
│   │   └── app_theme.dart           # 테마 설정
│   ├── services/
│   │   ├── api/
│   │   │   └── youtube_service.dart # YouTube API 로직 ⭐ 핵심
│   │   ├── auth/
│   │   │   └── google_auth_service.dart # Google 인증 ⭐ 중요
│   │   └── storage/
│   │       └── local_storage_service.dart # 로컬 데이터
│   └── views/screens/
│       ├── home_screen.dart         # 홈화면 ⭐ 자주 수정
│       ├── player_screen.dart       # 동영상 플레이어 ⭐ 최근 대폭 수정
│       ├── question_screen.dart     # 퀴즈 화면
│       └── settings_screen.dart     # 설정 화면
├── .env                             # API 키 (Git 제외) ⚠️ 민감정보
├── .env.example                     # API 키 예시 (Git 포함)
└── README.md                        # 설치 및 보안 가이드
```

### 🔑 중요 설정 파일들
- **pubspec.yaml**: 의존성 관리
- **.gitignore**: `.env` 파일 제외 확인 필수
- **android/app/google-services.json**: Firebase 설정

## 🔐 보안 설정 현황

### API 키 관리
- **YouTube API Key**: `.env` 파일에 저장 (현재 유효한 키로 설정됨)
- **OpenAI API Key**: 코드 연동 완료. `.env`에 실제 키가 있으면 AI 문제 생성 경로로
  동작하고, 플레이스홀더(`YOUR_OPENAI_API_KEY`)면 내장 문제은행으로 폴백
  (`question_generator_service.dart:95`)
- **Git 보안**: `.env` 파일은 .gitignore로 제외됨

### 환경변수 구조
```env
# .env 파일 구조
YOUTUBE_API_KEY=your_actual_youtube_api_key_here  # Google Cloud Console에서 발급
OPENAI_API_KEY=your_openai_api_key_here  # 미설정 시 내장 문제은행으로 폴백
```

## 🐛 알려진 이슈 및 해결 상태

### ✅ 해결된 이슈들
1. **영상 로딩 실패** - API 키 만료 → 새 키로 교체 완료
2. **보안 경고** - GitHub secret scanning → .env 분리 완료
3. **오류 메시지 불명확** → 사용자 친화적 메시지로 개선

### ⚠️ 현재 주의사항
1. **Flutter Hot Reload 제한**: 환경변수 변경 시 앱 재시작 필요
2. **API 할당량**: YouTube API 일일 10,000회 제한
3. **토큰 갱신**: Google 토큰 자동 갱신 로직 필요

## 🔄 워크플로우 규칙

### PR 및 이슈 관리
1. **PR 생성**: 작업 완료 후 PR만 생성 (merge는 하지 않음)
2. **이슈 상태**: PR 생성 후 관련 이슈를 **Pending PR**로 이동
3. **Merge**: 사용자가 테스트 후 직접 merge
4. **Done 이동**: 사용자가 명시적으로 요청할 때만 이슈를 **Done**으로 이동

### 브랜치 전략
- feature 브랜치에서 작업
- main 브랜치로 PR 생성
- merge는 사용자가 직접 수행

## 🎯 다음 작업 우선순위

### 1. 출시 블로커 (최우선)
- [ ] 앱 이름/브랜딩에서 'YouTube' 상표 제거 (#81)
- [ ] 'Shorts' 상표 용어를 자체 용어로 변경 (#82)
- [ ] 하단 네비게이션 구조 차별화 (#83)
- [ ] AppBar 액션 버튼 및 영상 카드 레이아웃 차별화 (#84)
- [ ] YouTube API 사용 고지 및 비공식 앱 면책 문구 추가 (#85)

### 2. 단기 개선
- [ ] 홈 화면 Shorts 필터링 개선 (#77)
- [ ] 추천 영상 동일 채널 연속 노출 방지 (#78)
- [ ] 더블탭 10초 건너뛰기/되감기 제스처 (#76)
- [ ] 퀴즈 여러 문제 한번에 출제 (#73)
- [ ] 재생 화면 댓글 보기 (#70)

### 3. 고급 작업들 (새로운 기능)
- [ ] AI 퀴즈 생성 시스템 (OpenAI API 필요)
- [ ] 학습 타이머 및 인터럽트 시스템
- [ ] 부모 통제 기능

## 🚨 트러블슈팅 가이드

### API 키 관련 오류
```bash
# 1. API 키 확인
cat .env | grep YOUTUBE_API_KEY

# 2. API 키 테스트
curl "https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&regionCode=KR&maxResults=1&key=YOUR_API_KEY"

# 3. 앱 재시작 (환경변수 변경 시)
flutter clean && flutter run
```

### Git 관련 작업
```bash
# 현재 상태 확인
git status
git log --oneline -5

# 안전한 커밋
git add .
git commit -m "설명적인 커밋 메시지"
git push origin 브랜치명
```

## 📚 참고 문서
- **기능명세서.md**: 전체 기능 요구사항 및 보안 아키텍처
- **README.md**: 설치 가이드 및 보안 설정 방법
- **Flutter 공식 문서**: https://docs.flutter.dev/
- **YouTube Data API**: https://developers.google.com/youtube/v3

## 💡 Claude 작업 팁

### 효율적인 세션 시작
1. 이 파일부터 읽어서 전체 컨텍스트 파악
2. 특정 기능 작업 시 관련 파일만 선택적으로 읽기
3. 작업 전 `git status`로 현재 상태 확인

### 토큰 절약 방법
- 전체 파일 읽기보다는 특정 함수나 클래스만 검색
- `Grep` 도구 활용해서 필요한 부분만 찾기
- 수정 후 즉시 테스트해서 재작업 최소화

## 🎬 전체화면 오버레이 시스템 아키텍처

### 핵심 구현 원리
- **전체화면 감지**: `_controller.value.isFullScreen` 사용
- **적응형 UI**: 화면 모드에 따른 조건부 렌더링
- **Stack 레이어링**: YoutubePlayerBuilder + Positioned 오버레이

### 주요 구현 파일
- **player_screen.dart**: 메인 구현 파일
  - `_showStudyPopup()`: 전체화면 모드 감지 로직
  - `_displayQuestionOverlay()`: 오버레이 표시 함수
  - `_buildQuestionOverlay()`: 오버레이 UI 구성
  - Stack 기반 이중 레이어 아키텍처

### 기술적 세부사항
```dart
// 전체화면 감지 및 조건부 표시
void _showStudyPopup() {
  if (_controller.value.isFullScreen) {
    _displayQuestionOverlay();  // 오버레이 모드
  } else {
    showDialog(...);            // 다이얼로그 모드
  }
}

// 오버레이 UI 구조
Stack(
  children: [
    YoutubePlayerBuilder(...),    // 비디오 레이어
    if (_showQuestionOverlay)     // 오버레이 레이어
      Positioned.fill(
        child: Container(...),
      ),
  ],
)
```

### 상태 관리
- `_showQuestionOverlay`: 오버레이 표시 상태
- `_currentQuestion`: 현재 문제 데이터
- `_isQuestionLoading`: 문제 로딩 상태
- 전체화면/일반 모드 자동 전환 지원

**마지막 업데이트**: 2026-09-19 by Claude Code
