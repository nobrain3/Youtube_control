---
name: create-pr
description: "현재 브랜치의 변경사항으로 PR을 생성합니다. 기능명세서 업데이트 체크 포함."
---

# /create-pr

현재 브랜치의 변경사항으로 PR을 생성합니다.

## 사용법
```
/create-pr
```

## Instructions

사용자가 `/create-pr`을 호출하면 다음 단계를 순서대로 수행하세요:

### 1단계: 사전 확인
```bash
git status
git log main..HEAD --oneline
git diff main...HEAD --stat
```
- 현재 브랜치가 main이 아닌지 확인 (main이면 중단)
- 브랜치 이름에서 이슈 번호 추출 (예: `feature/42-description` → #42)
- 커밋되지 않은 변경사항이 있으면 사용자에게 알림

### 2단계: 기능명세서 업데이트 체크
변경된 파일 목록을 확인하여 다음 파일이 수정되었는지 검사:
- `lib/views/` 하위 파일 (UI 변경)
- `lib/services/` 하위 파일 (서비스 변경)
- `lib/models/` 하위 파일 (모델 변경)
- `lib/widgets/` 하위 파일 (위젯 변경)

위 파일이 변경되었는데 `기능명세서.md` 또는 `기능명세서_구현.md`가 변경되지 않았다면:
- 사용자에게 경고 메시지 출력
- `/update-spec` 실행을 권유
- 사용자가 계속 진행하겠다고 하면 PR 생성 계속

### 3단계: 커밋되지 않은 변경사항 처리
커밋되지 않은 변경사항이 있으면 사용자에게 물어보세요:
- 커밋하고 PR 생성할지
- 변경사항 무시하고 기존 커밋만으로 PR 생성할지

### 4단계: 푸시 및 PR 생성
```bash
git push -u origin <현재브랜치>
```

PR 생성 시 AGENTS.md의 PR 템플릿을 따릅니다:
```bash
gh pr create \
  --title "<Type>: <설명> (#<이슈번호>)" \
  --body "$(cat <<'EOF'
## Summary
<main..HEAD 커밋들을 분석하여 변경사항 요약>

## Related Issue
Closes #<이슈번호>

## Changes
- <주요 변경사항 1>
- <주요 변경사항 2>

## Test Plan
- <테스트 항목>

---
Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" \
  --base main
```

- Type은 브랜치 접두사에서 결정: feature→Feat, fix→Fix, docs→Docs, refactor→Refactor

### 5단계: 칸반보드 "Pending PR"로 이동
- 관련 이슈를 칸반보드에서 "Pending PR" (또는 "PR") 컬럼으로 이동
- 실패해도 PR 생성 결과는 유지

### 6단계: 결과 요약
다음 정보를 사용자에게 보여주세요:
- PR URL
- PR 제목
- 변경된 파일 수, 추가/삭제 라인 수
- 칸반보드 상태 변경 결과
- **중요 안내**: "PR이 생성되었습니다. 테스트 후 머지를 요청해주세요. (자동 머지는 하지 않습니다)"

### 절대 금지사항
- **PR을 자동으로 머지하지 마세요**
- 사용자가 명시적으로 "머지해"라고 요청할 때만 머지 실행
