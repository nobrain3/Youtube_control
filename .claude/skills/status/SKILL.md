---
name: status
description: "프로젝트 현황을 한눈에 보여줍니다 - Git 상태, 이슈, PR, 칸반보드 요약."
---

# /status

프로젝트 현황을 한눈에 보여줍니다.

## 사용법
```
/status
```

## Instructions

사용자가 `/status`를 호출하면 다음 정보를 수집하여 깔끔하게 정리해서 보여주세요:

### 1단계: 정보 수집 (병렬 실행)
다음 명령어들을 **동시에** 실행하세요:

```bash
# Git 상태
git status --short
git branch --show-current
git log --oneline -5

# 열린 이슈
gh issue list --state open --limit 20

# 열린 PR
gh pr list --state open

# 칸반보드 현황
gh project item-list 2 --owner nobrain3 --format json
```

### 2단계: 정보 정리 및 출력
다음 형식으로 출력하세요:

```
## 프로젝트 현황

### Git 상태
- 현재 브랜치: <브랜치명>
- 커밋되지 않은 변경: <있음/없음> (파일 수)
- 최근 커밋: <최근 5개 커밋 요약>

### 열린 이슈 (<개수>)
| # | 제목 | 라벨 | 상태 |
|---|------|------|------|
| 이슈번호 | 제목 | 라벨 | 칸반보드 상태 |

### 열린 PR (<개수>)
| # | 제목 | 브랜치 | 상태 |
|---|------|--------|------|
| PR번호 | 제목 | 브랜치 | 리뷰 상태 |

### 칸반보드 요약
- In Progress: <개수> 건
- Pending PR: <개수> 건
- Todo: <개수> 건

### 다음 작업 추천
<현재 상태를 기반으로 다음에 할 작업을 추천>
```

### 다음 작업 추천 로직
- In Progress 이슈가 있으면 → 해당 작업 계속 진행 권유
- Pending PR이 있으면 → 테스트 및 머지 권유
- 둘 다 없으면 → Todo 중 우선순위 높은 이슈 시작 권유
- 커밋되지 않은 변경사항이 있으면 → 커밋 또는 정리 권유
