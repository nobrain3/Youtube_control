# YouTube 교육 컨트롤러 (YouTube Edu Controller)

아동 및 청소년의 YouTube 시청을 교육적으로 관리하고, 학습과 엔터테인먼트의 균형을 맞추는 스마트 컨트롤 앱입니다.

## 📖 프로젝트 개요

YouTube 교육 컨트롤러는 단순한 동영상 시청을 넘어 교육적 가치를 더하는 혁신적인 Flutter 앱입니다. 설정된 시간 간격마다 자동으로 동영상을 일시정지하고 AI가 생성한 교육 문제를 출제하여, 수동적인 시청을 능동적인 학습으로 전환시킵니다.

## ✨ 주요 기능

### 🎯 핵심 기능
- **자체 플레이어**: YouTube 동영상을 앱 내에서 완전 제어
- **스마트 타이머**: 15분 간격으로 자동 학습 인터럽트 (5~60분 조정 가능)
- **AI 문제 생성**: OpenAI API를 활용한 맞춤형 교육 문제
- **실시간 학습 추적**: 시청 시간, 문제 정답률, 포인트 시스템

### 📚 교육 시스템
- **연령별 맞춤 문제**: 초등/중등/고등 수준별 난이도 조정
- **과목별 문제**: 국어, 영어, 수학, 과학, 사회, 역사
- **재시도 시스템**: 최대 3회 기회 + 힌트 제공
- **상세한 해설**: 정답/오답에 관계없이 학습 내용 설명

### 🎮 게임화 요소
- **포인트 시스템**: 정답 시 포인트 획득 (시도 횟수에 따라 차등)
- **학습 통계**: 시청 시간, 정답률, 연속 학습일 추적
- **진행 상황 시각화**: 실시간 타이머 및 학습 현황 표시

## 🛠 기술 스택

### Frontend
- **Flutter 3.9.2+** - 크로스플랫폼 개발
- **Dart** - 주 프로그래밍 언어
- **Riverpod** - 상태 관리
- **Go Router** - 네비게이션 관리

### 핵심 라이브러리
- `youtube_player_flutter` - YouTube 플레이어
- `flutter_screenutil` - 반응형 UI
- `dio` - HTTP 클라이언트
- `shared_preferences` - 로컬 저장소
- `google_generative_ai` / `openai_dart` - AI 문제 생성

### API 연동
- **YouTube Data API v3** - 동영상 검색 및 메타데이터
- **OpenAI API** - AI 기반 문제 생성
- **Google Generative AI** - 백업 AI 서비스

## 📱 지원 플랫폼

- **Android** (최소 버전: API Level 24, Android 7.0)
- **iOS** (최소 버전: iOS 12.0)
- **웹** (PWA 지원)

## 🚀 설치 및 실행

### 사전 요구사항
- Flutter SDK (3.9.2 이상)
- Dart SDK
- Android Studio / Xcode (플랫폼별)
- YouTube Data API v3 키
- OpenAI API 키

### 설치 단계

1. **저장소 클론**
```bash
git clone https://github.com/your-username/youtube-edu-controller.git
cd youtube-edu-controller/youtube_edu_controller
```

2. **의존성 설치**
```bash
flutter pub get
```

3. **API 키 설정**
`lib/config/app_config.dart` 파일에서 API 키를 설정하세요:
```dart
static const String youtubeApiKey = 'YOUR_YOUTUBE_API_KEY';
static const String openaiApiKey = 'YOUR_OPENAI_API_KEY';
```

4. **앱 실행**
```bash
flutter run
```

## 📁 프로젝트 구조

```
lib/
├── config/              # 앱 설정 및 테마
│   ├── app_config.dart
│   ├── app_routes.dart
│   └── app_theme.dart
├── models/              # 데이터 모델
│   ├── question_model.dart
│   ├── study_session_model.dart
│   └── user_model.dart
├── services/            # 비즈니스 로직
│   ├── ai/
│   │   └── question_generator_service.dart
│   ├── api/
│   │   └── youtube_service.dart
│   ├── storage/
│   │   └── local_storage_service.dart
│   └── timer/
│       └── learning_timer_service.dart
├── views/               # UI 화면
│   └── screens/
│       ├── home_screen.dart
│       ├── player_screen.dart
│       ├── question_screen.dart
│       └── ...
├── widgets/             # 재사용 가능한 위젯
│   └── player/
│       └── youtube_player_widget.dart
└── main.dart            # 앱 진입점
```

## 🎯 주요 화면

### 1. 홈 화면
- YouTube 영상 검색
- 최근 시청 목록
- 학습 통계 대시보드
- 추천 영상

### 2. 플레이어 화면
- 자체 YouTube 플레이어
- 실시간 학습 타이머
- 동영상 정보 표시
- 학습 설정

### 3. 문제 화면
- AI 생성 교육 문제
- 객관식 답안 선택
- 진행률 표시
- 힌트 및 해설 시스템

## ⚙️ 설정 옵션

### 학습 타이머
- **기본 간격**: 15분
- **조정 범위**: 5~60분
- **백그라운드 동작**: 지원

### 문제 출제
- **난이도**: 자동 조정 또는 수동 설정
- **과목 선택**: 6개 주요 과목
- **재시도 횟수**: 최대 3회

### 포인트 시스템
- **정답 시**: 10~30점 (시도 횟수에 따라)
- **연속 정답**: 보너스 포인트
- **누적 포인트**: 학습 동기 부여

## 🔒 보안 및 개인정보

- **아동 개인정보 보호**: COPPA, GDPR-K 준수
- **데이터 암호화**: AES-256 적용
- **로컬 저장**: 민감 정보는 기기 내 저장
- **API 키 보안**: 환경 변수 활용

## 📊 성능 지표

- **앱 구동 시간**: 3초 이내
- **문제 로딩**: 2초 이내
- **동영상 전환**: 1초 이내
- **크래시율**: 0.1% 미만 목표

## 🚧 개발 현황

### ✅ 완료된 기능
- [x] YouTube 플레이어 위젯 (타이머 통합)
- [x] 학습 타이머 시스템 (15분 자동 일시정지)
- [x] AI 문제 생성 서비스
- [x] 문제 화면 (답안 검증 포함)
- [x] 플레이어 화면 (학습 인터럽트)
- [x] 기본 UI/UX 구조

### 🔄 개발 중
- [ ] 사용자 프로필 시스템
- [ ] 학습 세션 추적 및 통계
- [ ] 상세 설정 화면
- [ ] 콘텐츠 필터링

### 📋 계획된 기능
- [ ] 부모/교사 모드
- [ ] 실시간 모니터링
- [ ] 클라우드 동기화
- [ ] 소셜 기능

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 📞 연락처

프로젝트 관련 문의나 제안사항이 있으시면 언제든 연락해 주세요.

## 🙏 감사의 말

- Flutter 팀의 훌륭한 프레임워크
- YouTube API의 풍부한 기능
- OpenAI의 강력한 AI 기술
- 오픈소스 커뮤니티의 지원

---

**YouTube 교육 컨트롤러**로 더 똑똑하고 재미있는 학습을 시작해보세요! 🚀