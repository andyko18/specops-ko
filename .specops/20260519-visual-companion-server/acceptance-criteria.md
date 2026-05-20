<!-- FID: 20260519-visual-companion-server -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260519-visual-companion-server

## 계약 항목

### AC-1: server.cjs 존재 및 WebSocket 서버 기동

**Given** `skills/brainstorming-ko/scripts/server.cjs` 파일 존재

**When** `node skills/brainstorming-ko/scripts/server.cjs` 실행

**Then** "Visual Companion server listening on port 4242" 메시지 출력, port 4242에서 연결 대기

**검증 방법**: `node skills/brainstorming-ko/scripts/server.cjs & sleep 1 && lsof -i :4242 | grep LISTEN && kill %1`
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: server.cjs broadcast

**Given** server.cjs 기동 상태, 클라이언트 2개 연결

**When** 클라이언트 1이 메시지 전송

**Then** 클라이언트 2가 동일 메시지 수신

**검증 방법**: `bash scripts/tests/test-visual-companion.sh` T2
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: start-server.sh — 서버 시작 + PID 저장

**Given** `skills/brainstorming-ko/scripts/start-server.sh` 실행 권한 있음

**When** `bash skills/brainstorming-ko/scripts/start-server.sh` 실행

**Then** `.vc-server.pid` 파일 생성, 파일에 서버 PID 기록, port 4242 LISTEN 상태

**검증 방법**: `bash scripts/tests/test-visual-companion.sh` T3
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: stop-server.sh — 서버 종료

**Given** start-server.sh로 서버 기동 후 `.vc-server.pid` 존재

**When** `bash skills/brainstorming-ko/scripts/stop-server.sh` 실행

**Then** 서버 프로세스 종료, `.vc-server.pid` 파일 삭제, port 4242 더 이상 LISTEN 안 함

**검증 방법**: `bash scripts/tests/test-visual-companion.sh` T4
**관련 FR**: FR-5
**우선순위**: must

---

### AC-5: frame-template.html — WebSocket 연결 코드 포함

**Given** `skills/brainstorming-ko/scripts/frame-template.html` 존재

**When** 파일 내용 검사

**Then** `ws://localhost:4242` 연결 코드 + `#content` div + innerHTML 렌더링 코드 포함

**검증 방법**: `bash scripts/tests/test-visual-companion.sh` T5
**관련 FR**: FR-6, FR-7
**우선순위**: must

---

### AC-6: helper.js — sendToVisualCompanion export

**Given** `skills/brainstorming-ko/scripts/helper.js` 존재

**When** 파일 내용 검사

**Then** `sendToVisualCompanion` 함수 정의 포함, 서버 미기동 시 오류 처리 코드 포함

**검증 방법**: `bash scripts/tests/test-visual-companion.sh` T6
**관련 FR**: FR-8, FR-9
**우선순위**: must

---

### AC-7: specifying-ko §Visual Companion 포팅 주석 제거

**Given** `skills/specifying-ko/SKILL.md` 현재 line 326에 포팅 주석 존재

**When** 구현 완료 후 파일 검사

**Then** `"Phase 1 현재 — visual-companion 상세 가이드는 v0.1+에서 포팅"` 문자열 더 이상 없음, 대신 실제 사용 가이드 텍스트 존재

**검증 방법**: `bash scripts/tests/test-visual-companion.sh` T7
**관련 FR**: FR-10
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수)

### AC-R-1: specifying-ko 기존 동작 무영향

**Given** `skills/specifying-ko/SKILL.md` 수정 후

**When** `bash scripts/tests/test-skill-conventions.sh` 실행

**Then** `PASS=5 FAIL=0` (기존 검증 무영향)

**검증 방법**: `bash scripts/tests/test-skill-conventions.sh`
**관련 FR**: FR-10
**우선순위**: must

---

### AC-R-2: validate-structure.sh 무영향

**Given** 신규 scripts/ 파일 추가 후

**When** `bash scripts/_internal/validate-structure.sh` 실행

**Then** 전 항목 ✅ (file_counts 변경 없음 — `skills/*/SKILL.md` glob 외 파일)

**검증 방법**: `bash scripts/_internal/validate-structure.sh`
**관련 FR**: 전체
**우선순위**: must

---

*작성: specifying-ko [유지보수 분기] · 2026-05-19 · FID: 20260519-visual-companion-server*
