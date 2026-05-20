<!-- FID: 20260519-visual-companion-server -->
<!-- OWNER_COMMAND: /maintain -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- layer: Lifecycle-Artifact -->

# 현재 시스템 분석 (Current State) — 20260519-visual-companion-server

## 1. 변경 대상 식별

- 파일: `skills/specifying-ko/SKILL.md` (Lines 309-326 — Visual Companion 섹션, 18줄)
  - 309: `## Visual Companion`
  - 326: `(Phase 1 현재 — visual-companion 상세 가이드는 v0.1+에서 포팅)`
- 신규 생성 대상: `skills/brainstorming-ko/scripts/` 디렉토리 + 5개 파일
  - `server.cjs` — Node.js WebSocket 서버
  - `start-server.sh` — 서버 시작 스크립트
  - `stop-server.sh` — 서버 종료 스크립트
  - `frame-template.html` — 브라우저 UI 프레임 (WebSocket 클라이언트)
  - `helper.js` — 콘텐츠 생성 헬퍼

**라인 범위 합산: 18줄 → 유지보수**

## 2. 호출자/의존 매핑

```
grep -rn "Visual Companion" . --include="*.md" --include="*.sh" 결과:
```
- `skills/specifying-ko/SKILL.md:101` — Step 2 체크리스트에서 "Visual Companion 제안" 참조
- `skills/specifying-ko/SKILL.md:148` — 프로세스 흐름도에서 분기점으로 참조
- `skills/specifying-ko/SKILL.md:309` — `## Visual Companion` 섹션 (수정 대상)

> 한계: brainstorming-ko/scripts/ 는 신규 디렉토리 — 현재 정적 의존 없음

## 3. 기존 테스트 커버리지

```
find scripts/tests -name "*.sh" | xargs grep -l "visual|companion" 결과:
```
- `scripts/tests/test-diff-upstream.sh` — `brainstorm` 단어 포함 (업스트림 비교용)
- Visual Companion 동작 자체를 검증하는 테스트: **없음**

> 회귀 AC 추가 권고 — 서버 시작/종료 동작 baseline 없음

## 4. 관찰 가능 동작 (Baseline)

> ⚠️ 직접 실행 불가 — 서버 스크립트 미존재. 아래는 specifying-ko SKILL.md §Visual Companion 문서 기반 baseline.

| # | 상황 | 현재 동작 | 비고 |
|---|---|---|---|
| 1 | 시각 질문 예상 시 | 텍스트 제안 메시지 출력 (`"써보시겠어요? (로컬 URL 열기 필요)"`) | 수락해도 실제 서버 없음 |
| 2 | 사용자 수락 후 | 동작 없음 — 포팅 미완성 | `(Phase 1 현재...)` 주석만 존재 |
| 3 | 브라우저 질문 분기 | 분기 로직 텍스트만 존재 | 실제 URL 제공 불가 |

## 5. 회귀 위험 메모

- `specifying-ko/SKILL.md` §Visual Companion 수정 → specifying-ko 전체 동작 영향 없음 (독립 섹션)
- 신규 `skills/brainstorming-ko/scripts/` 추가 → validate-structure.sh `file_counts` 는 `skills/*/SKILL.md` glob만 체크 — 스크립트 파일 추가는 file_counts 무영향

---

*작성: analyzing-ko · 2026-05-19 · FID: 20260519-visual-companion-server*
