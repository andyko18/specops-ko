# 검증 증거 — 20260519-gbrain-skill

**검증일**: 2026-05-19
**검증자**: verifying-evidence-ko

## 실행 명령 + 출력

### 1. test-gbrain.sh (AC-1~AC-7, 리뷰 피드백 반영 후)

```
$ bash scripts/tests/test-gbrain.sh

PASS: T1.a gbrain-append.sh 존재
PASS: T1.b usage 출력 exit 1
PASS: T2.a JSONL 레코드 추가
PASS: T2.b JSONL insight 값 round-trip
PASS: T2.c insight 큰따옴표 포함 JSONL 유효
PASS: T3.a 파일 미존재 시 자동 생성
PASS: T4.a SKILL.md frontmatter 6 필드
PASS: T5.a SKILL.md 조회 프로세스 언급
PASS: T6.a commands/gbrain.md 존재
PASS: T6.b commands/gbrain.md gbrain-ko 언급
PASS: T7.a --fid 레코드 기록
PASS=11 FAIL=0
exit 0
```

### 2. validate-structure.sh (AC-R-1)

```
$ bash scripts/_internal/validate-structure.sh

✅ directories: OK
✅ file_counts: OK
✅ meta_injection: OK
✅ frontmatter: OK
✅ no_superpowers: OK
✅ manifest: OK (both=1.2.0)
ℹ️  ref_upstream_fmt: struct=33/33
exit 0
```

## AC 커버리지

| AC | must/should | 상태 |
|---|---|---|
| AC-1 | must | ✅ PASS (T1.a, T1.b) |
| AC-2 | must | ✅ PASS (T2.a) |
| AC-3 | must | ✅ PASS (T3.a) |
| AC-4 | must | ✅ PASS (T4.a) |
| AC-5 | must | ✅ PASS (T5.a) |
| AC-6 | must | ✅ PASS (T6.a, T6.b) |
| AC-7 | should | ✅ PASS (T7.a) |
| AC-R-1 | must | ✅ PASS (validate-structure.sh 전 항목 ✅) |

**must AC 커버리지**: 7/7 (100%)
**should AC 커버리지**: 1/1 (100%)

## 브랜치 커밋 목록

```
843b1f0 chore(gbrain): .structure-baseline skills 24→25, commands 8→9 갱신
dde9e58 fix(gbrain): SKILL.md grep -F 플래그 추가 — FID_FILTER 정규식 주입 방지
671c87a feat(gbrain): skills/gbrain-ko/SKILL.md + commands/gbrain.md
1fdcd4b fix: gbrain-append.sh — --fid/--tags 누락 값 무한루프 수정
fb13738 feat: scripts/gbrain-append.sh — JSONL 레코드 추가
7cd75aa test(red): test-gbrain.sh 작성 — AC-1~AC-7 정적 검증 9케이스
```

## known limitation (plan.md §1 명시)

- insight 값에 큰따옴표 포함 시 JSONL 비유효 — YAGNI (이스케이프 미구현)
- SKILL.md 내 grep 기반 JSON 파싱 — jq 미사용 단순 구현
