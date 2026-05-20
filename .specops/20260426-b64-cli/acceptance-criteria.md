<!-- FID: 20260426-b64-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260426-b64-cli

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

---

### AC-1: b64enc.sh 인자 인코딩

**Given** `b64enc.sh`가 실행 권한이 있다

**When** `b64enc.sh "hello"` 실행

**Then** stdout에 `aGVsbG8=` 한 줄 출력, exit 0

**검증 방법**: `scripts/tests/test-b64enc.sh`
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: b64enc.sh stdin 인코딩

**Given** `b64enc.sh`가 실행 권한이 있다

**When** `echo -n "hello" | b64enc.sh` 실행

**Then** stdout에 `aGVsbG8=` 한 줄 출력, exit 0

**검증 방법**: `scripts/tests/test-b64enc.sh`
**관련 FR**: FR-1
**우선순위**: must

---

### AC-3: b64enc.sh 입력 없음 시 usage

**Given** `b64enc.sh`가 실행 권한이 있다

**When** `b64enc.sh` (인자 없이, stdin도 TTY) 실행

**Then** usage 메시지 출력, exit 1

**검증 방법**: `scripts/tests/test-b64enc.sh`
**관련 FR**: FR-2
**우선순위**: must

---

### AC-4: b64dec.sh 인자 디코딩

**Given** `b64dec.sh`가 실행 권한이 있다

**When** `b64dec.sh "aGVsbG8="` 실행

**Then** stdout에 `hello` 출력, exit 0

**검증 방법**: `scripts/tests/test-b64dec.sh`
**관련 FR**: FR-3, FR-4
**우선순위**: must

---

### AC-5: b64dec.sh stdin 디코딩

**Given** `b64dec.sh`가 실행 권한이 있다

**When** `echo "aGVsbG8=" | b64dec.sh` 실행

**Then** stdout에 `hello` 출력, exit 0

**검증 방법**: `scripts/tests/test-b64dec.sh`
**관련 FR**: FR-3, FR-4
**우선순위**: must

---

### AC-6: b64dec.sh 잘못된 입력 에러

**Given** `b64dec.sh`가 실행 권한이 있다

**When** `b64dec.sh "!!!invalid!!!"` 실행

**Then** stderr에 에러 메시지 출력, exit 1

**검증 방법**: `scripts/tests/test-b64dec.sh`
**관련 FR**: FR-5
**우선순위**: must

---

### AC-7: b64val.sh 유효한 Base64 검증

**Given** `b64val.sh`가 실행 권한이 있다

**When** `b64val.sh "aGVsbG8="` 실행

**Then** stdout에 `valid` 출력, exit 0

**검증 방법**: `scripts/tests/test-b64val.sh`
**관련 FR**: FR-6, FR-7, FR-8, FR-9
**우선순위**: must

---

### AC-8: b64val.sh 잘못된 문자 검증

**Given** `b64val.sh`가 실행 권한이 있다

**When** `b64val.sh "hello!"` 실행 (허용되지 않는 `!` 포함)

**Then** stdout에 `invalid: invalid characters` 출력, exit 1

**검증 방법**: `scripts/tests/test-b64val.sh`
**관련 FR**: FR-7, FR-9
**우선순위**: must

---

### AC-9: b64val.sh 잘못된 패딩 검증

**Given** `b64val.sh`가 실행 권한이 있다

**When** `b64val.sh "aGVsbG8"` 실행 (패딩 `=` 누락으로 길이 7 = 4의 배수 아님)

**Then** stdout에 `invalid: invalid padding` 출력, exit 1

**검증 방법**: `scripts/tests/test-b64val.sh`
**관련 FR**: FR-8, FR-9
**우선순위**: must

---

### AC-10: 3종 독립성

**Given** 3종 스크립트가 모두 존재한다

**When** 각 파일을 개별 확인

**Then** `source`, `import`, 다른 b64 스크립트 경로 참조가 없다

**검증 방법**: `grep -E 'source|b64enc|b64dec|b64val' scripts/b64*.sh` 로 교차 참조 없음 확인
**관련 FR**: FR-10
**우선순위**: must

---

### AC-11: b64enc.sh 빈 문자열 인코딩

**Given** `b64enc.sh`가 실행 권한이 있다

**When** `b64enc.sh ""` 실행

**Then** stdout에 빈 문자열 출력, exit 0

**검증 방법**: `scripts/tests/test-b64enc.sh`
**관련 FR**: FR-1
**우선순위**: should

---

### AC-12: b64val.sh 빈 문자열 거부

**Given** `b64val.sh`가 실행 권한이 있다

**When** `b64val.sh ""` 실행

**Then** stdout에 `invalid: empty input` 출력, exit 1

**검증 방법**: `scripts/tests/test-b64val.sh`
**관련 FR**: FR-9
**우선순위**: should

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

## 참조

- `skills/sprint-contracts-ko/SKILL.md` — 계약서 운용 규약

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-b64-cli · 생성 커맨드: /specify*
