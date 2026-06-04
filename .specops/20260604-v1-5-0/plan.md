# specops-auto-ko v1.5.0 릴리스 구현 플랜

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: CHANGELOG.md·plugin.json·marketplace.json·README.md 4파일을 v1.5.0으로 갱신해 릴리스한다.

**아키텍처**: 신규 코드 없음. 텍스트·JSON 값 편집만. 3 태스크 독립 — 병렬 가능. 검증은 grep + python3 명령.

**기술 스택**: bash, python3 (json 모듈)

---

## 파일 구조

```
수정:
  CHANGELOG.md                        ← T1 (Unreleased→1.5.0 이동)
  .claude-plugin/plugin.json          ← T2 (version bump)
  .claude-plugin/marketplace.json     ← T2 (version bump)
  README.md                           ← T3 (버전 참조 현행화)
```

---

## Task 1: CHANGELOG.md 정리 — [Unreleased] → [1.5.0]

**파일**: 수정 `CHANGELOG.md`

**관련 AC**: AC-3

- [ ] **Step 1: RED — 실패 테스트 확인**

```bash
grep -F "## [1.5.0]" CHANGELOG.md; echo "exit: $?"
```

예상: 매칭 없음 → `exit: 1`

- [ ] **Step 2: FAIL 검증**

exit code 1 확인.

- [ ] **Step 3: GREEN — CHANGELOG 편집**

**3a. `## [Unreleased]` 블록 → `## [1.5.0] — 2026-06-04`로 교체**

변경 전:
```
## [Unreleased]

### Removed
- **stale 브랜치 정리** ...

### Docs
- 거버넌스 R-6 문서 누락 정정 ...

---
```

변경 후 (동일 위치를 아래 내용으로 교체):
```
## [Unreleased]

---

## [1.5.0] — 2026-06-04

### Added
- **ui-ux-pro-max 통합 포인터** — `commands/design-screen.md` Step 2.5 (design system 자동 자문)
  + `skills/specifying-ko/SKILL.md` Step 5.5 하위 절차 (화면 설계 전 design system 자문 안내). available-skills 에 `ui-ux-pro-max:ui-ux-pro-max` 가 없으면 graceful skip
- **로그인 화면 dogfood** — `screens/login.html` (HTML5/CSS3/인라인 JS, 다크 테마, 320px+ 반응형, AC-5 비밀번호 토글, role=alert·aria-invalid·aria-pressed 접근성)
  + `scripts/tests/test-login-screen.sh` (grep-F 기반 HTML 구조 검증 11체크, AC-1~AC-5)

### Removed
- **stale 브랜치 정리** (2026-06-01) — 이전 세션 잔재인 머지 완료 브랜치 6종(로컬 5 + remote 5 ref) 삭제: `chore/commands-cleanup`·`chore/v1.3.0-bump`·`feat/20260522-harness-ref-skills`·`feat/20260526-bash-redirect-evidence`·`feat/20260526-e2e-test-ko-split`·`fix/cleanup-stacked-prs`. 전 산출물이 main 에 반영됐음을 확인 후 삭제 (MERGED 8 + squash-머지 추정 2, 유실 0). 로컬·원격 모두 `main` 단독 상태로 복원

### Docs
- 거버넌스 R-6 문서 누락 정정 — `CLAUDE.md`·`README.md` "5규칙 R-1~R-5" → "6규칙 R-1~R-6" + R-6 행/설명 추가. `posttool-governance.sh` 설명 R-1~R-5 → R-1~R-3 정정. 하드코딩 PASS 카운트 제거 (#43)

---
```

**3b. 버전 비교 링크 갱신** (파일 맨 끝):

변경 전:
```
[Unreleased]: https://github.com/kohaedong/specops-auto-ko/compare/v1.4.0...HEAD
[1.4.0]: ...
```

변경 후:
```
[Unreleased]: https://github.com/kohaedong/specops-auto-ko/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.4.0...v1.5.0
[1.4.0]: ...
```

- [ ] **Step 4: PASS 검증**

```bash
grep -F "## [1.5.0]" CHANGELOG.md && echo "PASS" || echo "FAIL"
grep -F "[1.5.0]: https://github.com" CHANGELOG.md && echo "link PASS" || echo "link FAIL"
grep -F "v1.5.0...HEAD" CHANGELOG.md && echo "unreleased-link PASS" || echo "FAIL"
```

예상: 세 줄 모두 PASS

- [ ] **Step 5: COMMIT**

```bash
git add CHANGELOG.md
git commit -m "chore(release): CHANGELOG [Unreleased] → [1.5.0] — 2026-06-04"
```

---

## Task 2: plugin.json + marketplace.json 버전 bump

**파일**: 수정 `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**관련 AC**: AC-1, AC-2, AC-4

- [ ] **Step 1: RED — 실패 테스트 확인**

```bash
python3 -c "import json; v=json.load(open('.claude-plugin/plugin.json'))['version']; print(v); exit(0 if v=='1.5.0' else 1)"
echo "exit: $?"
```

예상: `1.4.0` 출력 → `exit: 1`

- [ ] **Step 2: FAIL 검증**

exit code 1 확인.

- [ ] **Step 3: GREEN — 버전 값 교체**

**plugin.json** — `"version": "1.4.0"` → `"version": "1.5.0"`:

```json
{
  "name": "specops-auto-ko",
  "version": "1.5.0",
  "description": "한국어 자율 Lifecycle 플러그인 (Claude Code 전용) — 슬래시 1회 또는 자연어 진입 후 메타 skill이 단계·skill을 자동 chain",
  "author": {
    "name": "andyko18",
    "email": "222357127+andyko18@users.noreply.github.com"
  },
  "license": "UNLICENSED",
  "keywords": [
    "korean",
    "autonomous",
    "lifecycle",
    "superpowers",
    "skill-chain",
    "spec-driven",
    "harness",
    "downstream-project"
  ]
}
```

**marketplace.json** — `plugins[0].version` `"1.4.0"` → `"1.5.0"` (해당 필드만 수정)

- [ ] **Step 4: PASS 검증**

```bash
python3 -c "import json; v=json.load(open('.claude-plugin/plugin.json'))['version']; print('plugin:', v)"
python3 -c "import json; v=json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version']; print('marketplace:', v)"
bash scripts/_internal/validate-structure.sh 2>&1 | grep manifest
```

예상:
```
plugin: 1.5.0
marketplace: 1.5.0
✅ manifest: OK (both=1.5.0)
```

- [ ] **Step 5: COMMIT**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): plugin.json + marketplace.json 버전 1.4.0 → 1.5.0"
```

---

## Task 3: README.md 버전 현행화

**파일**: 수정 `README.md`

**관련 AC**: 없음 (DESIRABLE — validate-structure 외 별도 AC 없음)

- [ ] **Step 1: RED — 현재 상태 확인**

```bash
grep -F "v1.5.0" README.md; echo "exit: $?"
```

예상: 매칭 없음 → `exit: 1`

- [ ] **Step 2: FAIL 검증**

exit code 1 확인.

- [ ] **Step 3: GREEN — README 편집**

**변경 1** — 라인 3:
```
변경 전: **Claude Code 전용 한국어 자율 Lifecycle 플러그인** (v1.4.0)
변경 후: **Claude Code 전용 한국어 자율 Lifecycle 플러그인** (v1.5.0)
```

**변경 2** — 파일 맨 끝 footer:
```
변경 전: · **최신: v1.4.0 (2026-06-01)**
변경 후: · **최신: v1.5.0 (2026-06-04)**
```

- [ ] **Step 4: PASS 검증**

```bash
grep -F "v1.5.0" README.md
```

예상: 두 라인 출력 (헤더 + footer)

- [ ] **Step 5: COMMIT**

```bash
git add README.md
git commit -m "docs(release): README.md v1.4.0 → v1.5.0 현행화"
```

---

## 7. 자체 검토 (5원칙 체크리스트)

- [x] **스펙 커버리지** — FR-1(CHANGELOG T1), FR-2(CHANGELOG T1), FR-3(CHANGELOG T1 링크), FR-4(T2 plugin.json), FR-5(T2 marketplace.json) + Q1(T3 README) 모두 커버
- [x] **플레이스홀더 없음** — 모든 스텝에 실제 명령·내용 포함
- [x] **타입 일관성** — 버전 문자열 `"1.5.0"` 3곳 일관
- [x] **모호성 없음** — 편집 위치와 before/after 내용 명시

---

## 8. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음. 텍스트 편집 + JSON 값 교체로 결정론적 작업. TDD 검증 명령 모두 실측 기반.

---

## 참조

- `.specops/20260604-v1-5-0/spec.md` — 요구사항 원본
- `.specops/20260604-v1-5-0/acceptance-criteria.md` — AC-1~5
- `scripts/_internal/validate-structure.sh` — manifest 검증 자동화

---

*작성: specops-auto-ko · 2026-06-04 · FID: 20260604-v1-5-0*
