# 🤖 AI Agent 개발 워크플로우 가이드

> **YouTube 교육 컨트롤러 프로젝트 - Claude Code Agent 작업 규칙**
>
> 이 문서는 AI Agent가 프로젝트를 지속적으로 개발할 때 따라야 할 워크플로우와 규칙을 정의합니다.

---

## 📋 목차

1. [프로젝트 구조](#프로젝트-구조)
2. [개발 워크플로우](#개발-워크플로우)
3. [GitHub 프로젝트 관리](#github-프로젝트-관리)
4. [커밋 메시지 규칙](#커밋-메시지-규칙)
5. [PR 생성 규칙](#pr-생성-규칙)
6. [코드 작성 규칙](#코드-작성-규칙)
7. [테스트 규칙](#테스트-규칙)

---

## 🗂 프로젝트 구조

### 기본 정보
- **프로젝트명**: YouTube 교육 컨트롤러 (YouTube Edu Controller)
- **기술 스택**: Flutter 3.9.2+, Dart, Riverpod
- **저장소**: https://github.com/nobrain3/Youtube_control
- **칸반보드**: https://github.com/users/nobrain3/projects/2
- **메인 브랜치**: `main`

### 디렉토리 구조
```
youtube_edu_controller/
├── lib/
│   ├── config/              # 앱 설정
│   ├── models/              # 데이터 모델
│   ├── services/            # 비즈니스 로직
│   │   ├── ai/              # AI 서비스
│   │   ├── api/             # API 서비스
│   │   ├── auth/            # 인증 서비스
│   │   ├── storage/         # 로컬 저장소
│   │   └── timer/           # 타이머 서비스
│   ├── views/screens/       # UI 화면
│   ├── widgets/             # 재사용 위젯
│   └── main.dart
├── 기능명세서.md             # 기능 명세서
├── 기능명세서_구현.md         # 구현 현황
└── AGENTS.md                # 이 파일
```

---

## 🔄 개발 워크플로우

### 전체 프로세스

```
1. 이슈 선택
   ↓
2. 이슈를 "In Progress"로 이동
   ↓
3. Feature 브랜치 생성
   ↓
4. 기능 구현
   ↓
5. 테스트 (선택)
   ↓
6. 커밋 & 푸시
   ↓
7. PR 생성
   ↓
8. PR을 칸반보드 "PR" 컬럼으로 이동
   ↓
9. PR Merge
   ↓
10. 이슈를 "Done" 컬럼으로 이동
```

### 단계별 상세 가이드

#### 1️⃣ 이슈 선택
```bash
# 현재 열려있는 이슈 확인
gh issue list --limit 10

# 특정 이슈 상세 확인
gh issue view <issue-number>
```

**규칙:**
- 우선순위가 높은 이슈부터 처리 (High > Medium > Low)
- 연관된 이슈들은 함께 처리 고려
- 이슈 번호를 기억해두기 (커밋, PR에 사용)

---

#### 2️⃣ 이슈를 "In Progress"로 이동

```bash
# GitHub CLI로 프로젝트 필드 업데이트
gh project item-edit --id <ITEM_ID> --field-id <FIELD_ID> --project-id <PROJECT_ID> --value "In Progress"
```

**또는 수동으로:**
- GitHub 웹에서 칸반보드 접속
- 이슈를 "Todo" → "In Progress"로 드래그

**규칙:**
- 구현 시작 전에 **반드시** 상태 변경
- 동시에 여러 이슈를 In Progress로 두지 않기

---

#### 3️⃣ Feature 브랜치 생성

```bash
# 브랜치 네이밍: feature/<issue-number>-<brief-description>
git checkout -b feature/<issue-number>-<description>

# 예시
git checkout -b feature/69-like-dislike-buttons
git checkout -b feature/70-comments-viewer
```

**브랜치 네이밍 규칙:**
- `feature/<issue-number>-<description>`: 새 기능
- `fix/<issue-number>-<description>`: 버그 수정
- `refactor/<description>`: 리팩토링
- `docs/<description>`: 문서 업데이트
- `test/<description>`: 테스트 추가

---

#### 4️⃣ 기능 구현

**구현 순서:**
1. **모델 생성** (필요 시)
   - `lib/models/` 에 데이터 모델 추가
   - `fromJson()`, `toJson()` 메서드 구현

2. **서비스 로직 구현**
   - `lib/services/` 에 비즈니스 로직 추가
   - API 연동, 데이터 처리 등

3. **UI 구현**
   - `lib/views/screens/` 또는 `lib/widgets/` 에 UI 추가
   - State Management (Riverpod) 활용

4. **통합 테스트**
   - 실제 앱에서 동작 확인
   - 에러 핸들링 확인

**코드 작성 시 주의사항:**
- 기존 코드 스타일 유지
- 주석은 필요한 경우만 추가 (복잡한 로직)
- 에러 핸들링 철저히
- Null-safety 준수

**📝 기능명세서 업데이트 필수:**
- UI 변경 시 (버튼 추가/제거, 레이아웃 변경 등)
- 새 기능 추가 시
- 기존 기능 삭제/변경 시
- API 연동 변경 시
- **업데이트 대상**: `기능명세서.md` + `기능명세서_구현.md`
- **커밋 메시지**: 코드 변경과 함께 커밋하거나 별도 커밋

---

#### 5️⃣ 테스트 (선택)

```bash
# Flutter 앱 실행
cd youtube_edu_controller
flutter run

# 특정 기기에서 실행
flutter run -d <device-id>

# 핫 리로드로 빠르게 테스트
# (앱 실행 중 'r' 키)
```

**테스트 체크리스트:**
- [ ] 기능이 정상 동작하는가?
- [ ] 에러가 발생하지 않는가?
- [ ] UI가 의도한 대로 표시되는가?
- [ ] 로그인/로그아웃 시나리오 테스트
- [ ] 네트워크 오류 시나리오 테스트

---

#### 6️⃣ 커밋 & 푸시

```bash
# 변경된 파일 확인
git status

# 파일 스테이징
git add <files>

# 커밋 (규칙에 맞게)
git commit -m "$(cat <<'EOF'
<Type>: <Subject>

<Body>

Related: #<issue-number>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

# 원격 저장소에 푸시
git push -u origin feature/<issue-number>-<description>
```

**커밋 메시지 규칙은 아래 섹션 참조**

---

#### 7️⃣ PR 생성

```bash
gh pr create \
  --title "<Type>: <Brief Description> (#<issue-number>)" \
  --body "$(cat <<'EOF'
## 📝 Summary
<변경 사항 요약>

## 🔗 Related Issue
Closes #<issue-number>

## ✅ Changes
- [ ] <주요 변경 사항 1>
- [ ] <주요 변경 사항 2>
- [ ] <주요 변경 사항 3>

## 📸 Screenshots (if applicable)
<스크린샷 또는 N/A>

## 🧪 Test Plan
- [ ] <테스트 항목 1>
- [ ] <테스트 항목 2>

## 📚 Additional Notes
<추가 설명 또는 N/A>
EOF
)" \
  --base main \
  --head feature/<issue-number>-<description>
```

**PR 생성 후:**
- PR 번호 확인 및 기록
- 칸반보드로 이동하여 상태 변경 준비

---

#### 8️⃣ PR을 "PR" 컬럼으로 이동

```bash
# PR을 프로젝트에 추가 (자동으로 추가되지 않은 경우)
gh project item-add 2 --owner nobrain3 --url <PR_URL>

# 상태를 "PR"로 변경 (수동 또는 자동화)
```

**규칙:**
- PR 생성 즉시 칸반보드 업데이트
- 원본 이슈는 "In Progress" 유지 (PR이 대신 표시됨)

---

#### 9️⃣ PR Merge

**⚠️ 중요: 자동 머지 절대 금지**
- **AI가 자동으로 PR을 머지하지 않습니다**
- PR 생성 후 사용자가 직접 테스트하고 확인합니다
- **사용자가 명시적으로 "머지해"라고 요청할 때만 머지를 실행합니다**
- 테스트 없이 머지하면 버그가 프로덕션에 배포될 수 있습니다

**사용자 테스트 대기:**
```bash
# PR 생성 후 대기
echo "PR이 생성되었습니다. 사용자가 테스트 후 머지를 요청할 때까지 대기합니다."

# 사용자가 "머지해"라고 명시적으로 요청한 경우에만:
gh pr merge <pr-number> --squash --delete-branch
```

**Merge 전 체크리스트 (사용자가 직접 확인):**
- [ ] 로컬 또는 개발 환경에서 테스트 완료
- [ ] 기능이 정상 동작하는지 확인
- [ ] UI가 의도한 대로 표시되는지 확인
- [ ] 에러가 발생하지 않는지 확인
- [ ] 다양한 시나리오 테스트 (로그인/로그아웃 등)
- [ ] CI/CD 통과 (설정된 경우)
- [ ] 코드 리뷰 완료 (필요 시)
- [ ] 충돌 해결 완료

---

#### 🔟 이슈를 "Done"으로 이동

```bash
# 이슈 닫기 (PR merge 시 자동으로 닫힘)
gh issue close <issue-number>

# 칸반보드에서 "Done"으로 이동 (수동)
```

**규칙:**
- PR이 머지되면 자동으로 이슈가 닫힘
- 칸반보드에서 "Done" 컬럼으로 이동 확인
- 구현 현황 문서 업데이트

---

## 🎯 GitHub 프로젝트 관리

### 프로젝트 보드 구조

**칸반보드 컬럼:**
1. **Backlog** - 아직 작업 시작 전
2. **Todo** - 작업 예정
3. **In Progress** - 현재 작업 중
4. **PR** - Pull Request 생성됨
5. **Done** - 완료

### 이슈 상태 관리 규칙

| 상태 | 설명 | 조건 |
|------|------|------|
| Backlog | 백로그 | 새로 생성된 이슈 |
| Todo | 작업 예정 | 우선순위 정해짐 |
| In Progress | 작업 중 | 구현 시작 |
| PR | PR 생성 | PR이 생성됨 |
| Done | 완료 | PR이 머지됨 |

### 이슈 라벨 사용

```bash
# 이슈에 라벨 추가
gh issue edit <issue-number> --add-label "enhancement,ui"

# 사용 가능한 라벨
- enhancement: 새 기능
- bug: 버그 수정
- documentation: 문서 작업
- ui: UI 관련
- api: API 관련
- high-priority: 높은 우선순위
- medium-priority: 중간 우선순위
- low-priority: 낮은 우선순위
```

---

## 📝 커밋 메시지 규칙

### 기본 형식

```
<Type>: <Subject>

<Body>

Related: #<issue-number>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Type 종류

| Type | 설명 | 예시 |
|------|------|------|
| `Feat` | 새 기능 추가 | Feat: 좋아요/싫어요 버튼 추가 |
| `Fix` | 버그 수정 | Fix: 댓글 로딩 오류 수정 |
| `Refactor` | 코드 리팩토링 | Refactor: YouTube API 서비스 개선 |
| `Style` | 코드 스타일 변경 | Style: 플레이어 UI 정렬 수정 |
| `Docs` | 문서 업데이트 | Docs: 기능명세서 업데이트 |
| `Test` | 테스트 추가/수정 | Test: 댓글 서비스 테스트 추가 |
| `Chore` | 기타 작업 | Chore: 의존성 업데이트 |
| `Perf` | 성능 개선 | Perf: 이미지 캐싱 최적화 |

### Subject 규칙
- 50자 이내로 간결하게
- 명령형 어조 사용 ("추가했다" → "추가")
- 마침표 사용 안 함
- 한글 또는 영어 (일관성 유지)

### Body 규칙
- 선택사항 (간단한 커밋은 생략 가능)
- 변경 이유와 주요 변경 사항 설명
- 각 줄은 72자 이내로 작성
- 불릿 포인트로 여러 항목 나열 가능

### 예시

```bash
# 좋은 예시
git commit -m "$(cat <<'EOF'
Feat: 재생 화면에 좋아요/싫어요 버튼 추가

- YouTube API videos.rate 엔드포인트 연동
- YouTube API videos.getRating으로 현재 상태 조회
- 로그인 사용자만 사용 가능하도록 제한
- 버튼 클릭 시 애니메이션 효과 추가

Related: #69

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

# 나쁜 예시
git commit -m "update"
git commit -m "fix bug"
git commit -m "added some features"
```

---

## 🔀 PR 생성 규칙

### PR 제목 형식

```
<Type>: <Brief Description> (#<issue-number>)
```

**예시:**
- `Feat: 재생 화면에 좋아요/싫어요 버튼 추가 (#69)`
- `Fix: 댓글 로딩 오류 수정 (#71)`
- `Refactor: YouTube API 서비스 구조 개선 (#72)`

### PR 본문 템플릿

```markdown
## 📝 Summary
<변경 사항을 1-2문장으로 요약>

## 🔗 Related Issue
Closes #<issue-number>

## ✅ Changes
- [ ] <주요 변경 사항 1>
- [ ] <주요 변경 사항 2>
- [ ] <주요 변경 사항 3>

## 📸 Screenshots (if applicable)
<스크린샷 첨부 또는 N/A>

## 🧪 Test Plan
- [ ] <테스트 항목 1>
- [ ] <테스트 항목 2>
- [ ] <테스트 항목 3>

## 📚 Additional Notes
<추가 설명이 필요한 경우 작성, 없으면 N/A>

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### PR 생성 시 주의사항

1. **Base 브랜치 확인**: `main` 브랜치로 머지되는지 확인
2. **Title 명확하게**: 무엇을 했는지 한 눈에 파악 가능하도록
3. **이슈 링크**: `Closes #<number>` 또는 `Related: #<number>` 사용
4. **스크린샷 첨부**: UI 변경이 있는 경우 필수
5. **Self-Review**: PR 생성 후 직접 코드 리뷰
6. **Draft PR**: 아직 완료되지 않은 경우 Draft로 생성

---

## 💻 코드 작성 규칙

### Flutter/Dart 코딩 스타일

1. **Naming Conventions**
   - Class: `PascalCase` (예: `CommentModel`)
   - Method/Variable: `camelCase` (예: `getComments()`)
   - Constants: `lowerCamelCase` (예: `apiKey`)
   - Private: `_camelCase` (예: `_privateMethod()`)

2. **File Structure**
   ```dart
   // 1. Imports
   import 'package:flutter/material.dart';

   // 2. Main Class
   class MyWidget extends StatelessWidget {
     // 3. Fields
     final String title;

     // 4. Constructor
     const MyWidget({Key? key, required this.title}) : super(key: key);

     // 5. Methods
     @override
     Widget build(BuildContext context) {
       // ...
     }
   }
   ```

3. **State Management (Riverpod)**
   ```dart
   // Provider 정의
   final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
     return MyNotifier();
   });

   // 사용
   final myState = ref.watch(myProvider);
   ```

4. **에러 핸들링**
   ```dart
   try {
     // API 호출 등
   } catch (e) {
     debugPrint('Error: $e');
     // 사용자에게 에러 메시지 표시
   }
   ```

### YouTube API 서비스 패턴

```dart
// lib/services/api/youtube_service.dart
class YouTubeService {
  final Dio _dio;

  Future<List<Comment>> getComments({
    required String videoId,
    String order = 'relevance',
    int maxResults = 20,
    String? pageToken,
  }) async {
    try {
      final response = await _dio.get(
        '/commentThreads',
        queryParameters: {
          'part': 'snippet',
          'videoId': videoId,
          'order': order,
          'maxResults': maxResults,
          if (pageToken != null) 'pageToken': pageToken,
        },
      );

      return (response.data['items'] as List)
          .map((item) => Comment.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to load comments: $e');
    }
  }
}
```

---

## 🧪 테스트 규칙

### 테스트 우선순위

1. **필수 테스트**
   - API 연동 기능
   - 중요한 비즈니스 로직
   - 에러 핸들링

2. **권장 테스트**
   - UI 위젯 테스트
   - State Management 테스트

3. **선택 테스트**
   - 통합 테스트
   - E2E 테스트

### 수동 테스트 체크리스트

새 기능 구현 시 다음을 확인:

- [ ] 기능이 정상 동작하는가?
- [ ] 로그인/로그아웃 상태에서 모두 동작하는가?
- [ ] 네트워크 오류 시 적절한 메시지가 표시되는가?
- [ ] UI가 다양한 화면 크기에서 정상인가?
- [ ] 다크 모드에서 UI가 정상인가?
- [ ] 메모리 누수가 없는가?
- [ ] 앱이 크래시하지 않는가?

---

## 📚 추가 참고 자료

### 프로젝트 문서
- [기능명세서.md](./기능명세서.md) - 전체 기능 명세
- [기능명세서_구현.md](./기능명세서_구현.md) - 구현 현황
- [README.md](./README.md) - 프로젝트 개요

### 외부 문서
- [Flutter 공식 문서](https://flutter.dev/docs)
- [Riverpod 공식 문서](https://riverpod.dev/)
- [YouTube Data API v3](https://developers.google.com/youtube/v3/docs)
- [GitHub CLI 문서](https://cli.github.com/manual/)

---

## 🔧 유용한 명령어 모음

### Git 명령어
```bash
# 브랜치 목록 확인
git branch -a

# 브랜치 전환
git checkout <branch-name>

# 변경 사항 확인
git status
git diff

# 최신 상태로 동기화
git pull origin main

# 브랜치 삭제
git branch -d <branch-name>
```

### GitHub CLI 명령어
```bash
# 이슈 관련
gh issue list
gh issue view <number>
gh issue create
gh issue close <number>

# PR 관련
gh pr list
gh pr view <number>
gh pr create
gh pr merge <number> --squash

# 프로젝트 관련
gh project list --owner nobrain3
gh project item-add 2 --owner nobrain3 --url <URL>
```

### Flutter 명령어
```bash
# 앱 실행
flutter run

# 빌드
flutter build apk
flutter build ios

# 테스트
flutter test

# 의존성 관리
flutter pub get
flutter pub upgrade
```

---

## ✅ 워크플로우 체크리스트

매 작업 시작 시 확인:

- [ ] 이슈 번호 확인
- [ ] 이슈를 "In Progress"로 이동
- [ ] Feature 브랜치 생성
- [ ] 기능 구현
- [ ] **📝 기능명세서 업데이트** (UI/기능 변경 시 필수!)
- [ ] 로컬 테스트
- [ ] 커밋 메시지 규칙 준수
- [ ] PR 생성
- [ ] PR을 "PR" 컬럼으로 이동
- [ ] **🚨 사용자 테스트 대기** (중요! AI는 자동으로 머지하지 않음)
- [ ] 사용자가 "머지해"라고 요청하면 PR 머지
- [ ] 이슈를 "Done"으로 이동

---

## 🤝 협업 규칙

### AI Agent 간 인수인계

새로운 세션에서 작업을 이어받을 때:

1. **현재 상태 파악**
   ```bash
   git status
   gh issue list --state open
   gh pr list --state open
   ```

2. **진행 중인 작업 확인**
   - 칸반보드에서 "In Progress" 항목 확인
   - 최근 커밋 메시지 확인
   - 기능명세서_구현.md 확인

3. **컨텍스트 복원**
   - 관련 이슈 읽기
   - 관련 파일 읽기
   - 이전 커밋 내역 확인

4. **작업 재개**
   - 이전 작업 완료 또는 새 작업 시작
   - 이 문서(AGENTS.md)의 워크플로우 따르기

---

## 📌 중요 원칙

1. **항상 이슈 기반으로 작업**: 이슈 없이 코드 변경 금지
2. **작은 단위로 커밋**: 하나의 커밋에 하나의 논리적 변경
3. **명확한 커밋 메시지**: 6개월 후에도 이해 가능하도록
4. **테스트 후 커밋**: 항상 동작하는 코드만 푸시
5. **PR 단위는 작게**: 리뷰하기 쉬운 크기로 (500줄 이내 권장)
6. **📝 기능명세서 필수 업데이트**: UI나 기능이 추가/변경/삭제될 때마다 반드시 `기능명세서.md`와 `기능명세서_구현.md`를 함께 업데이트
7. **칸반보드 최신 유지**: 상태 변경 시 즉시 반영
8. **🚨 자동 머지 절대 금지**: PR 생성 후 사용자가 테스트하고 명시적으로 "머지해"라고 요청할 때까지 대기

---

**Last Updated:** 2026-03-14
**Version:** 1.0.0
**Author:** Claude Code Assistant
