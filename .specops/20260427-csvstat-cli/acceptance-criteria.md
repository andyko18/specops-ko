<!-- FID: 20260427-csvstat-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260427-csvstat-cli

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: 파일 인자 통계 출력

**Given** `data.csv`가 3행(헤더 포함) 2컬럼(`name,age`)이고 `name` unique=2, `age` unique=1

**When** `csvstat.py data.csv`

**Then** stdout:
```
rows: 2
columns: 2
name: 2 unique
age: 1 unique
```
exit 0

**검증 방법**: `pytest examples/tests/test_csvstat.py -v` → `test_file_arg` 케이스 PASS
**관련 FR**: FR-1, FR-5
**우선순위**: must

---

### AC-2: stdin 입력 지원

**Given** 동일 CSV 내용을 stdin으로 전달

**When** `cat data.csv | csvstat.py`

**Then** AC-1과 동일한 stdout 출력, exit 0

**검증 방법**: pytest `test_stdin` 케이스
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: 존재하지 않는 파일

**Given** `missing.csv`가 존재하지 않음

**When** `csvstat.py missing.csv`

**Then** stderr에 에러 메시지, stdout 없음, exit 1

**검증 방법**: pytest `test_missing_file` 케이스
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: 인자·stdin 없음 → usage

**Given** 터미널에서 인자 없이 실행 (stdin이 tty)

**When** `csvstat.py </dev/null`

**Then** stderr에 usage 출력, exit 1

**검증 방법**: `python3 examples/scripts/csvstat.py </dev/null; echo $?` → exit=1
**관련 FR**: FR-4
**우선순위**: must

---

### AC-5: pytest PASS

**Given** `examples/tests/test_csvstat.py` 존재

**When** `pytest examples/tests/test_csvstat.py -v`

**Then** 모든 테스트 PASS, exit 0

**검증 방법**: 직접 실행
**관련 FR**: FR-1~FR-5
**우선순위**: must

---

### AC-6: test-conventions-python.md 존재 및 4항목 규약

**Given** `templates/test-conventions-python.md` 파일

**When** 내용 확인

**Then** 다음 4항목이 명시됨:
1. 위치 규약 (`examples/tests/` 또는 프로젝트 패턴)
2. 명명 규약 (`test_<subject>.py` — underscore)
3. exec-bit 불필요 (pytest가 직접 실행)
4. 헤더 불필요 (shebang 없음이 기본)

**검증 방법**: `cat templates/test-conventions-python.md`
**관련 FR**: FR-6
**우선순위**: must

---

### AC-7: decomposing-ko HARD-GATE Python 분기

**Given** `decomposing-ko/SKILL.md` 수정 후

**When** 내용 확인

**Then** HARD-GATE 또는 테스트 컨벤션 섹션에 Python (`test_*.py`) 규약 분기가 명시됨. 기존 bash (`test-*.sh`) 규약은 그대로 유지됨.

**검증 방법**: `grep -n "test_\*\.py\|python\|pytest" skills/decomposing-ko/SKILL.md`
**관련 FR**: FR-7
**우선순위**: must

---

### AC-8: exec-bit + shebang (csvstat.py 본체)

**Given** `examples/scripts/csvstat.py`

**When** `ls -la examples/scripts/csvstat.py` + `head -1 examples/scripts/csvstat.py`

**Then** `-rwxr-xr-x` (exec-bit) + `#!/usr/bin/env python3` shebang

**검증 방법**: 직접 확인
**관련 FR**: (NFR-4)
**우선순위**: should

---

### AC-9: 빈 CSV (헤더만) 처리 — /clarify 추가

**Given** 헤더 행만 있고 데이터 행이 없는 CSV (`name,age\n`)

**When** `csvstat.py empty.csv`

**Then** stdout:
```
rows: 0
columns: 2
name: 0 unique
age: 0 unique
```
exit 0

**검증 방법**: pytest `test_empty_csv` 케이스
**관련 FR**: FR-1, FR-5
**우선순위**: must

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록

---

*작성: kohaedong · 2026-04-27 · FID: 20260427-csvstat-cli · 생성 커맨드: /specify*
*AC-9 추가: kohaedong · 2026-04-27 · /clarify*
