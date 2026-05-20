<!-- FID: 20260425-slug-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260425-slug-cli

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: 한글 음절 로마자 변환

**Given** 한글 음절만으로 구성된 문자열 `"안녕"`

**When** `scripts/slug.sh "안녕"` 실행

**Then** 표준 출력에 `annyeong`이 출력되고 exit code 0

**검증 방법**: `[ "$(scripts/slug.sh "안녕")" = "annyeong" ]`  
**관련 FR**: FR-1  
**우선순위**: must

---

### AC-2: 영문 대소문자 정규화

**Given** 영문 대문자가 포함된 문자열 `"Hello World"`

**When** `scripts/slug.sh "Hello World"` 실행

**Then** 표준 출력에 `hello-world`가 출력되고 exit code 0

**검증 방법**: `[ "$(scripts/slug.sh "Hello World")" = "hello-world" ]`  
**관련 FR**: FR-2, FR-3  
**우선순위**: must

---

### AC-3: 한글/영문 혼합 입력

**Given** 한글과 영문이 혼합된 문자열 `"안녕 World 2024"`

**When** `scripts/slug.sh "안녕 World 2024"` 실행

**Then** 표준 출력에 `annyeong-world-2024`가 출력되고 exit code 0

**검증 방법**: `[ "$(scripts/slug.sh "안녕 World 2024")" = "annyeong-world-2024" ]`  
**관련 FR**: FR-1, FR-2, FR-3  
**우선순위**: must

---

### AC-4: 연속 구분자 및 앞뒤 정리

**Given** 앞뒤 공백과 연속 공백이 포함된 문자열 `"  hello   world  "`

**When** `scripts/slug.sh "  hello   world  "` 실행

**Then** 표준 출력에 `hello-world`가 출력되고 exit code 0 (앞뒤 `-` 없음, 연속 `-` 없음)

**검증 방법**: `[ "$(scripts/slug.sh "  hello   world  ")" = "hello-world" ]`  
**관련 FR**: FR-4  
**우선순위**: must

---

### AC-5: stdin 입력 지원

**Given** 파이프로 전달되는 문자열 `"Hello 세계"`

**When** `echo "Hello 세계" | scripts/slug.sh` 실행 (인자 없음)

**Then** 표준 출력에 `hello-segye`가 출력되고 exit code 0

**검증 방법**: `[ "$(echo "Hello 세계" | scripts/slug.sh)" = "hello-segye" ]`  
**관련 FR**: FR-5  
**우선순위**: must

---

### AC-6: --help 플래그

**Given** 스크립트가 실행 가능한 상태

**When** `scripts/slug.sh --help` 실행

**Then** 사용법 문자열이 표준 출력에 출력되고 exit code 0

**검증 방법**: `scripts/slug.sh --help | grep -q "Usage"`  
**관련 FR**: FR-6  
**우선순위**: should

---

### AC-7: 특수문자 처리

**Given** 특수문자가 포함된 문자열 `"hello!@#world"`

**When** `scripts/slug.sh "hello!@#world"` 실행

**Then** 표준 출력에 `hello-world`가 출력되고 exit code 0

**검증 방법**: `[ "$(scripts/slug.sh "hello!@#world")" = "hello-world" ]`  
**관련 FR**: FR-3, FR-4  
**우선순위**: must

---

### AC-8: 빈 입력 처리

**Given** 빈 문자열 또는 공백만 있는 입력 (`""`, `"   "`)

**When** `scripts/slug.sh ""` 또는 `scripts/slug.sh "   "` 실행

**Then** 표준 출력에 빈 문자열이 출력되고 exit code 0

**검증 방법**: `[ "$(scripts/slug.sh "")" = "" ] && [ $? -eq 0 ]`  
**관련 FR**: FR-4, FR-5  
**우선순위**: must  
**출처**: clarifications.md Q1 (BLOCKING RESOLVED)

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

## 참조

- `skills/sprint-contracts-ko/SKILL.md` — 계약서 운용 규약
- `.specops/20260425-slug-cli/spec.md` — 기능 명세

---

*작성: kohaedong · 2026-04-25 · FID: 20260425-slug-cli · 생성 커맨드: /start*
