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

## 📋 프로젝트 현재 상태 (2024-02-14 업데이트)

### 🎯 최근 완료된 작업
- **영상 로딩 오류 수정** ✅
  - API 키 만료 문제 해결
  - YouTube API 검증 로직 추가
  - 상세한 오류 메시지 구현
  - 디버그 로깅 시스템 추가
- **보안 강화** ✅
  - .env 파일 API 키 관리
  - Git 보안 설정 완료
  - README 보안 가이드 작성
  - 기능명세서 보안 요구사항 추가

### 🔧 현재 기술 스택
- **Frontend**: Flutter (Dart)
- **State Management**: Riverpod
- **UI**: flutter_screenutil, go_router
- **APIs**: YouTube Data API v3, Google OAuth
- **Storage**: SharedPreferences (로컬)
- **Auth**: google_sign_in

### 🌳 브랜치 상태
- **현재 브랜치**: `fix/fullscreen-video`
- **최근 커밋**: 보안 강화 및 API 키 관리 시스템
- **다음 작업**: main으로 PR 생성 대기

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
│       ├── player_screen.dart       # 동영상 플레이어
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
- **OpenAI API Key**: 아직 설정 안됨 (향후 AI 퀴즈 기능용)
- **Git 보안**: `.env` 파일은 .gitignore로 제외됨

### 환경변수 구조
```env
# .env 파일 구조
YOUTUBE_API_KEY=AIzaSyCmnB-W11Remgn4nP6H8_NRArD26BGYKWc  # 현재 유효
OPENAI_API_KEY=YOUR_OPENAI_API_KEY  # 아직 미설정
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

### 1. 즉시 가능한 작업들
- [ ] 현재 브랜치 main으로 PR 생성
- [ ] 홈화면 영상 카드 UI 개선
- [ ] 설정 화면 API 키 설정 기능 추가
- [ ] Shorts 재생 페이지 구현

### 2. 중급 작업들 (API 이해 필요)
- [ ] 개인화된 추천 알고리즘 개선
- [ ] 사용자 시청 기록 저장/복원
- [ ] 구독 채널 기반 콘텐츠 필터링

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

**마지막 업데이트**: 2024-02-14 by Claude Code
