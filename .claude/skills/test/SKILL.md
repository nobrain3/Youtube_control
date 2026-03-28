---
name: test
description: Flutter 프로젝트의 분석(analyze)과 테스트를 실행하고 결과를 보고합니다.
user_invocable: true
---

# /test 스킬

Flutter 프로젝트의 코드 품질을 검증합니다.

## 실행 순서

1. `cd youtube_edu_controller && flutter analyze --no-fatal-infos` 실행
   - 에러(error) 개수와 경고(warning) 개수를 보고
2. `flutter test` 실행
   - 통과/실패 테스트 개수를 보고
3. **PR 생성 가능 여부 판단**:
   - analyze 에러 0개 **AND** 테스트 실패 0개 → "PR 생성 가능"
   - 그 외 → "PR 생성 불가" + 실패 원인 요약

## 출력 형식

```
## 테스트 결과

### flutter analyze
- 에러: N개
- 경고: N개
- 정보: N개

### flutter test
- 통과: N개
- 실패: N개
- 스킵: N개

### PR 생성 가능 여부
✅ PR 생성 가능 (에러 0, 실패 0)
또는
❌ PR 생성 불가 - [원인 요약]
```
