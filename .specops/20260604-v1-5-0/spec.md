<!-- FID: 20260604-v1-5-0 -->
<!-- OWNER_COMMAND: /specify -->
<!-- layer: Lifecycle-Artifact -->

# specops-auto-ko v1.5.0 릴리스 스펙

**§유형**: 신규

## 1. 개요

**목표**: v1.4.0 이후 누적된 미배포 작업(ui-ux-pro-max 통합, 로그인 화면 dogfood, docs 정정)을 v1.5.0으로 번들링해 릴리스한다.

**아키텍처**: 신규 코드 없음. CHANGELOG.md 정리 + plugin.json·marketplace.json 버전 bump 3파일 변경.

**기술 스택**: bash, JSON 편집

---

## 2. 범위

### 포함

- `CHANGELOG.md` 업데이트 (독립 — 병렬 구현 가능)
  - `[Unreleased]` → `[1.5.0] — 2026-06-04` 이동
  - ui-ux-pro-max 통합·login screen dogfood·기존 unreleased 항목 기재
  - 신규 `[Unreleased]` 섹션 추가
  - 버전 비교 링크 갱신
- `.claude-plugin/plugin.json` 버전 bump `1.4.0` → `1.5.0` (독립 — 병렬 구현 가능)
- `.claude-plugin/marketplace.json` 버전 bump `1.4.0` → `1.5.0` (독립 — 병렬 구현 가능)

### 제외

- 신규 기능 개발
- specops_version frontmatter 개별 파일 갱신 (관련 없음 — 각 스킬의 개정 시 업데이트)
- PR #46 머지 작업 (현 브랜치가 이미 해당 커밋 포함)

---

## 3. 기능 요구사항

| FR | 설명 | 우선순위 |
|---|---|---|
| FR-1 | CHANGELOG.md — `[Unreleased]` 블록을 `[1.5.0] — 2026-06-04`로 이동. 내용: ui-ux-pro-max 통합 Added + login screen dogfood Added + 기존 Removed/Docs 항목 유지 | must |
| FR-2 | CHANGELOG.md — 이동 후 빈 `## [Unreleased]` 섹션 추가 (맨 위) | must |
| FR-3 | CHANGELOG.md — 버전 비교 링크에 `[1.5.0]` 라인 추가, `[Unreleased]` 링크를 `v1.5.0...HEAD`로 갱신 | must |
| FR-4 | `.claude-plugin/plugin.json` — `"version"` 값 `"1.5.0"` | must |
| FR-5 | `.claude-plugin/marketplace.json` — 플러그인 배열 `"version"` 값 `"1.5.0"` | must |

---

## 4. 비기능 요구사항

| NFR | 설명 |
|---|---|
| NFR-1 | `bash scripts/_internal/validate-structure.sh` → `manifest OK (both=1.5.0)` |
| NFR-2 | `bash scripts/tests/governance/test-rules.sh` → PASS=70 (회귀 없음) |
| NFR-3 | JSON 파일 파싱 오류 없음 (valid JSON 유지) |

---

## 5. 1.5.0 CHANGELOG 내용 정의

```markdown
## [1.5.0] — 2026-06-04

### Added
- **ui-ux-pro-max 통합 포인터** — `commands/design-screen.md` Step 2.5 (design system 자동 자문)
  + `skills/specifying-ko/SKILL.md` Step 5.5 하위 절차 (화면 설계 전 design system 자문 안내). available-skills 에 `ui-ux-pro-max:ui-ux-pro-max` 가 없으면 graceful skip
- **로그인 화면 dogfood** — `screens/login.html` (HTML5/CSS3/인라인 JS, 다크 테마, 320px+ 반응형, AC-5 비밀번호 토글, role=alert·aria-invalid·aria-pressed 접근성)
  + `scripts/tests/test-login-screen.sh` (grep-F 기반 HTML 구조 검증 11체크, AC-1~AC-5)

### Removed
- **stale 브랜치 정리** (2026-06-01) — 이전 세션 잔재인 머지 완료 브랜치 6종 삭제

### Docs
- 거버넌스 R-6 문서 누락 정정 — `CLAUDE.md`·`README.md` "5규칙 R-1~R-5" → "6규칙 R-1~R-6" (#43)
```

---

## 6. 파일 구조

```
변경:
  CHANGELOG.md                        ← FR-1/2/3
  .claude-plugin/plugin.json          ← FR-4
  .claude-plugin/marketplace.json     ← FR-5
```

---

## 7. 자체 검토 (5원칙 체크리스트)

- [x] **플레이스홀더 없음** — TBD/TODO 없음
- [x] **내부 일관성** — 3파일 변경이 모두 1.5.0으로 일치
- [x] **범위 집중** — 버전 bump 이외 변경 없음
- [x] **모호성 없음** — 1.5.0 CHANGELOG 내용 §5에 명시

---

## 8. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음. 버전 bump 3파일 + CHANGELOG 정리는 명확한 단순 작업.

---

## 참조

- `DESIGN.md` — 디자인 시스템 (해당 없음 — 비UI 작업)
- `CHANGELOG.md` — 현재 [Unreleased] 내용
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — 버전 관리 대상

---

*작성: specops-auto-ko · 2026-06-04 · FID: 20260604-v1-5-0 · /specify*
