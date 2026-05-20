<!-- FID: 20260426-cvt-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260426-cvt-cli

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다. Evaluator는 이 계약만을 판정 기준으로 삼습니다.

## 계약 항목

### AC-1: JSON → YAML 변환

**Given** 유효한 JSON 파일 `input.json`이 존재한다

**When** `cvt --to yaml input.json`을 실행한다

**Then** stdout에 동등한 YAML이 출력되고, exit 0이다

**검증 방법**: `cvt --to yaml input.json | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin)"` 통과
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: YAML → JSON 변환

**Given** 유효한 YAML 파일 `input.yaml`이 존재한다

**When** `cvt --to json input.yaml`을 실행한다

**Then** stdout에 동등한 JSON이 출력되고, exit 0이다

**검증 방법**: `cvt --to json input.yaml | python3 -c "import sys,json; json.load(sys.stdin)"` 통과
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: stdin 파이프 입력

**Given** 유효한 JSON이 stdin으로 제공된다

**When** `cat input.json | cvt --to yaml`을 실행한다

**Then** AC-1과 동일한 YAML이 stdout에 출력되고, exit 0이다

**검증 방법**: stdout diff 비교
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: 파싱 실패 → ParseError

**Given** 구문 오류가 있는 파일 `bad.json`이 존재한다

**When** `cvt --to yaml bad.json`을 실행한다

**Then** stderr에 `ParseError:` 로 시작하는 메시지가 출력되고, exit 1이다. stdout은 비어 있다

**검증 방법**: `cvt --to yaml bad.json 2>&1 1>/dev/null | grep "^ParseError:"` 통과, `echo $?` = 1
**관련 FR**: FR-4
**우선순위**: must

---

### AC-5: --to 플래그 누락

**Given** cvt가 설치돼 있다

**When** `cvt input.json` (`--to` 없이) 실행한다

**Then** stderr에 usage 메시지가 출력되고, exit 2이다

**검증 방법**: `cvt input.json 2>&1; echo $?` → exit code 2 확인
**관련 FR**: FR-5
**우선순위**: must

---

### AC-6: 빈 입력

**Given** 빈 파일 또는 빈 stdin이 입력된다

**When** `cvt --to yaml empty.json`을 실행한다

**Then** stderr에 `ParseError:` 메시지가 출력되고, exit 1이다

**검증 방법**: `echo -n "" | cvt --to yaml; echo $?` → exit 1
**관련 FR**: FR-4
**우선순위**: must

---

### AC-7: --indent 플래그

**Given** 유효한 YAML 파일이 존재한다

**When** `cvt --to json --indent 4 input.yaml`을 실행한다

**Then** stdout JSON의 들여쓰기가 4칸이다

**검증 방법**: stdout의 첫 번째 중첩 키가 공백 4개로 시작함을 확인
**관련 FR**: FR-6
**우선순위**: should

---

### AC-8: 정상 변환 시 stderr 없음

**Given** 유효한 입력이 제공된다

**When** 변환을 실행한다

**Then** stderr는 완전히 비어 있다

**검증 방법**: `cvt --to yaml input.json 2>/tmp/err.txt; wc -c /tmp/err.txt` → 0 bytes
**관련 FR**: FR-7
**우선순위**: must

---

### AC-9: 빈 YAML → JSON ParseError (clarify Q1 추가)

**Given** 빈 파일 또는 빈 stdin이 YAML 입력으로 제공된다

**When** `cvt --to json`을 실행한다

**Then** stderr에 `ParseError:` 메시지가 출력되고, exit 1이다. stdout은 비어 있다

**검증 방법**: `echo -n "" | cvt --to json; echo $?` → exit 1, `echo -n "" | cvt --to json 2>&1 1>/dev/null | grep "^ParseError:"` 통과
**관련 FR**: FR-4
**우선순위**: must

---

### AC-10: PyYAML 미설치 DependencyError (clarify Q2 추가)

**Given** pyyaml이 설치되지 않은 환경이다

**When** `cvt --to yaml input.json`을 실행한다

**Then** stderr에 `DependencyError: pyyaml 미설치. pip install pyyaml`이 출력되고, exit 1이다

**검증 방법**: 별도 가상환경에서 pyyaml 없이 실행 후 메시지 확인
**관련 FR**: FR-4
**우선순위**: nice-to-have

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

## 참조

- `skills/sprint-contracts-ko/SKILL.md` — 계약서 운용 규약
- `spec.md` — 기능 요구사항 FR-1~FR-7

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-cvt-cli · 생성 커맨드: /specify*
