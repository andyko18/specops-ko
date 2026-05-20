<!-- FID: 20260426-epoch-iso-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260426-epoch-iso-cli

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다. Evaluator는 이 계약만을 판정 기준으로 삼습니다.

## 계약 항목

### AC-1: epoch 초 → ISO 8601 변환

**Given** `scripts/epoch.sh`가 실행 가능한 상태

**When** `scripts/epoch.sh 1777161600` 실행

**Then** stdout에 `2026-04-26T00:00:00Z` 출력, exit 0

**검증 방법**: `test_epoch.sh` 자동 테스트
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: epoch 밀리초 → ISO 8601 변환

**Given** `scripts/epoch.sh`가 실행 가능한 상태

**When** `scripts/epoch.sh 1777161600123` 실행

**Then** stdout에 `2026-04-26T00:00:00.123Z` 출력, exit 0

**검증 방법**: `test_epoch.sh` 자동 테스트
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: ISO 8601 → epoch 초 변환

**Given** `scripts/epoch.sh`가 실행 가능한 상태

**When** `scripts/epoch.sh 2026-04-26T00:00:00Z` 실행

**Then** stdout에 `1777161600` 출력, exit 0

**검증 방법**: `test_epoch.sh` 자동 테스트
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: ISO 8601(밀리초 포함) → epoch 밀리초 변환

**Given** `scripts/epoch.sh`가 실행 가능한 상태

**When** `scripts/epoch.sh 2026-04-26T00:00:00.123Z` 실행

**Then** stdout에 `1777161600123` 출력, exit 0

**검증 방법**: `test_epoch.sh` 자동 테스트
**관련 FR**: FR-4
**우선순위**: must

---

### AC-5: stdin 입력 지원

**Given** `scripts/epoch.sh`가 실행 가능한 상태

**When** `echo "1777161600" | scripts/epoch.sh` 실행

**Then** stdout에 `2026-04-26T00:00:00Z` 출력, exit 0

**검증 방법**: `test_epoch.sh` 자동 테스트
**관련 FR**: FR-5
**우선순위**: must

---

### AC-6: 인식 불가 입력 에러 처리

**Given** `scripts/epoch.sh`가 실행 가능한 상태

**When** `scripts/epoch.sh "not-a-valid-input"` 실행

**Then** stderr에 에러 메시지 출력, exit 1, stdout 비어있음

**검증 방법**: `test_epoch.sh` 자동 테스트
**관련 FR**: FR-8
**우선순위**: must

---

### AC-7: --help 플래그

**Given** `scripts/epoch.sh`가 실행 가능한 상태

**When** `scripts/epoch.sh --help` 실행

**Then** stdout에 사용법 출력, exit 0

**검증 방법**: `test_epoch.sh` 자동 테스트
**관련 FR**: FR-7
**우선순위**: should

---

### AC-8: +00:00 offset 입력 지원

**Given** `scripts/epoch.sh`가 실행 가능한 상태

**When** `scripts/epoch.sh 2026-04-26T00:00:00+00:00` 실행

**Then** stdout에 `1777161600` 출력, exit 0

**검증 방법**: `test_epoch.sh` 자동 테스트
**관련 FR**: FR-3
**우선순위**: should

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

## 참조

- `skills/sprint-contracts-ko/SKILL.md` — 계약서 운용 규약
- `spec.md` — 기능 요구사항 원문

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-epoch-iso-cli · 생성 커맨드: /start*
