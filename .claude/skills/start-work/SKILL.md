---
name: start-work
description: "이슈 번호로 작업 시작 - 브랜치 생성, 칸반보드 이동을 자동화합니다."
argument-hint: "<이슈번호>"
---

# /start-work <이슈번호>

작업 시작 워크플로우를 자동화합니다.

## 사용법
```
/start-work 42
```

## Instructions

사용자가 `/start-work <이슈번호>`를 호출하면 다음 단계를 순서대로 수행하세요:

### 1단계: 이슈 확인
```bash
gh issue view <이슈번호>
```
- 이슈가 존재하는지 확인
- 이슈 제목, 라벨, 상태를 파악
- 이슈가 이미 닫혀있으면 사용자에게 알리고 중단

### 2단계: main 브랜치에서 새 브랜치 생성
- 현재 변경사항이 있으면 사용자에게 경고 (stash 또는 commit 권유)
- main 브랜치를 최신으로 pull
- 이슈 라벨에 따라 브랜치 접두사 결정:
  - `bug` 라벨 → `fix/<이슈번호>-<설명>`
  - `documentation` 라벨 → `docs/<이슈번호>-<설명>`
  - 그 외 (enhancement 등) → `feature/<이슈번호>-<설명>`
- 이슈 제목에서 브랜치 설명을 영문 kebab-case로 생성 (한글이면 적절히 영문 변환)
```bash
git checkout main
git pull origin main
git checkout -b <prefix>/<이슈번호>-<description>
```

### 3단계: 칸반보드 "In Progress"로 이동
```bash
# 프로젝트 아이템 ID 조회
gh project item-list 2 --owner nobrain3 --format json | jq '.items[] | select(.content.number == <이슈번호>)'
```
- 아이템 ID와 Status 필드 ID를 조회하여 "In Progress"로 이동
- 칸반보드 이동이 실패해도 브랜치 생성은 유지 (경고만 출력)

### 4단계: 결과 요약
다음 정보를 사용자에게 보여주세요:
- 이슈 제목과 번호
- 생성된 브랜치 이름
- 칸반보드 상태 변경 결과
- 다음 할 일 안내 (코드 작업 시작)
