<!-- FID: 20260426-cvt-cli -->
<!-- OWNER_COMMAND: /request-review -->
<!-- layer: Lifecycle-Artifact -->

# 코드 리뷰 요청 — 20260426-cvt-cli

**요청일**: 2026-04-26
**BASE_SHA**: `bcbcb5e` (tasks.md 커밋 — 구현 시작 직전)
**HEAD_SHA**: `19e253c` (verify 커밋 — 현재 HEAD)
**핵심 파일**: `scripts/cvt.py` (55 LOC) · `scripts/tests/test-cvt.sh` (83 LOC)

---

## 구현 내용 (WHAT_WAS_IMPLEMENTED)

JSON ↔ YAML 양방향 변환 Python CLI `scripts/cvt.py`.

- `--to {json|yaml}` 필수 플래그로 변환 방향 지정
- stdin 파이프 + 파일 인자 양쪽 지원
- 3단계 파이프라인: 입력 읽기 → parse/validate → format 출력
- 에러 처리: `ParseError:` (구문 오류·빈 입력) / `DependencyError:` (pyyaml 미설치) / `FileNotFoundError:`
- `--indent N` 플래그 (JSON 출력 들여쓰기, 기본 2)

## 요구사항 (PLAN_OR_REQUIREMENTS)

- **spec**: `.specops/20260426-cvt-cli/spec.md` §4 FR-1~FR-7
- **AC**: `.specops/20260426-cvt-cli/acceptance-criteria.md` AC-1~AC-10
- **clarifications**: `.specops/20260426-cvt-cli/clarifications.md`
  - Q1: 빈 입력은 방향 불문 ParseError + exit 1
  - Q2: PyYAML 미설치 → DependencyError 메시지
  - Q3: YAML 다중 문서 → 첫 문서만 (yaml.safe_load 사용)

## 검증 결과 (EVIDENCE)

- **테스트**: `bash scripts/tests/test-cvt.sh` → PASS=15 FAIL=0
- **Phase B**: spec-reviewer-ko → AC-1~AC-9 전체 MET
- **Phase C**: code-reviewer-ko → READY_TO_MERGE (Critical 0, Important 3 비차단)
- **exec-bit**: cvt.py + test-cvt.sh 모두 755

## Phase C Important 3건 (비차단, 차기 이터레이션 권장)

1. `cvt.py:25` — `FileNotFoundError`만 잡고 `PermissionError` 미처리 (스택 트레이스 노출)
2. `cvt.py:17` — `--indent` 음수/대값 무검증
3. `test-cvt.sh:30` — T2.c stdin 파이프 내용 정확성 미검증

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-cvt-cli · 생성 커맨드: /request-review*
