<!-- FID: 20260604-v1-5-0 -->
<!-- OWNER_COMMAND: /tasks -->
<!-- MUTABLE_BY: /implement (상태 마킹만) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# v1.5.0 릴리스 태스크 목록 — 20260604-v1-5-0

> 각 태스크는 TDD 5 스텝(RED → 검증 → GREEN → 검증 → COMMIT)을 따릅니다.

**관련 플랜**: `.specops/20260604-v1-5-0/plan.md`
**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5

---

## AC → Task 매핑

| AC | must/should | Task(s) |
|---|---|---|
| AC-1 | must | T2 |
| AC-2 | must | T2 |
| AC-3 | must | T1 |
| AC-4 | must | T2 |
| AC-5 | must | T3 |

**must AC 커버리지**: 5/5 (100%)

---

## 태스크 1: CHANGELOG.md [Unreleased] → [1.5.0]

**AC 매핑**: AC-3
**파일**:
- Modify: `CHANGELOG.md`

- [ ] **스텝 1: RED — 실패 테스트 확인**

```bash
grep -qF "## [1.5.0]" CHANGELOG.md; echo "exit: $?"
```

예상: `exit: 1` (아직 [1.5.0] 섹션 없음)

- [ ] **스텝 2: FAIL 검증**

exit code 1 확인.

- [ ] **스텝 3: GREEN — CHANGELOG 편집**

**3a.** 현재 `## [Unreleased]` 블록(라인 5~13) 전체를 다음으로 교체:

```markdown
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

**3b.** 파일 맨 끝 링크 블록 교체:

```
[Unreleased]: https://github.com/kohaedong/specops-auto-ko/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/kohaedong/specops-auto-ko/releases/tag/v1.0.0
```

- [ ] **스텝 4: PASS 검증**

```bash
grep -qF "## [1.5.0]" CHANGELOG.md && echo "PASS: 1.5.0 섹션" || echo "FAIL"
grep -qF "v1.5.0...HEAD" CHANGELOG.md && echo "PASS: unreleased 링크" || echo "FAIL"
grep -qF "[1.5.0]: https://" CHANGELOG.md && echo "PASS: 1.5.0 링크" || echo "FAIL"
```

예상: 세 줄 모두 PASS

- [ ] **스텝 5: COMMIT**

```bash
git add CHANGELOG.md
git commit -m "chore(release): CHANGELOG [Unreleased] → [1.5.0] — 2026-06-04"
```

---

## 태스크 2: plugin.json + marketplace.json 버전 bump

**AC 매핑**: AC-1, AC-2, AC-4
**파일**:
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **스텝 1: RED — 실패 테스트 확인**

```bash
python3 -c "import json; v=json.load(open('.claude-plugin/plugin.json'))['version']; exit(0 if v=='1.5.0' else 1)"; echo "exit: $?"
```

예상: `exit: 1` (현재 1.4.0)

- [ ] **스텝 2: FAIL 검증**

exit code 1 확인.

- [ ] **스텝 3: GREEN — 버전 값 교체**

**plugin.json** — `"version"` 값 `"1.4.0"` → `"1.5.0"`:

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

**marketplace.json** — `plugins[0].version` 필드만 `"1.4.0"` → `"1.5.0"` (나머지 불변)

- [ ] **스텝 4: PASS 검증**

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

- [ ] **스텝 5: COMMIT**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): plugin.json + marketplace.json 버전 1.4.0 → 1.5.0"
```

---

## 태스크 3: README.md 버전 현행화

**AC 매핑**: AC-5 (governance 회귀 없음 — README 수정이 거버넌스 테스트를 깨지 않음 확인)
**파일**:
- Modify: `README.md`

- [ ] **스텝 1: RED — 실패 테스트 확인**

```bash
grep -cF "v1.5.0" README.md; echo "exit: $?"
```

예상: `0` → `exit: 1` (현재 v1.4.0만 존재)

- [ ] **스텝 2: FAIL 검증**

count=0 확인.

- [ ] **스텝 3: GREEN — README 편집**

**변경 1** — 라인 3 헤더:
```
변경 전: **Claude Code 전용 한국어 자율 Lifecycle 플러그인** (v1.4.0)
변경 후: **Claude Code 전용 한국어 자율 Lifecycle 플러그인** (v1.5.0)
```

**변경 2** — 파일 맨 끝 footer:
```
변경 전: · **최신: v1.4.0 (2026-06-01)**
변경 후: · **최신: v1.5.0 (2026-06-04)**
```

- [ ] **스텝 4: PASS 검증**

```bash
grep -cF "v1.5.0" README.md
bash scripts/tests/governance/test-rules.sh 2>&1 | tail -1
```

예상:
```
2
==== Results: PASS=70 FAIL=0 ====
```

- [ ] **스텝 5: COMMIT**

```bash
git add README.md
git commit -m "docs(release): README.md v1.4.0 → v1.5.0 현행화"
```

---

## 진행 상태

총 태스크 수: 3
완료: 0 / 3
차단: 0

## 의존 그래프

```mermaid
graph TD
  T1[T1: CHANGELOG.md 정리]
  T2[T2: JSON 버전 bump]
  T3[T3: README 현행화]
```

```yaml
tasks:
  - id: T1
    test_command: "bash -c \"grep -qF '## [1.5.0]' CHANGELOG.md\""
    depends_on: []
    inputs: [CHANGELOG.md]
    outputs: [CHANGELOG.md]
    ac: [AC-3]
  - id: T2
    test_command: "bash -c \"python3 -c \\\"import json; v=json.load(open('.claude-plugin/plugin.json'))['version']; exit(0 if v=='1.5.0' else 1)\\\"\""
    depends_on: []
    inputs: [.claude-plugin/plugin.json, .claude-plugin/marketplace.json]
    outputs: [.claude-plugin/plugin.json, .claude-plugin/marketplace.json]
    ac: [AC-1, AC-2, AC-4]
  - id: T3
    test_command: "bash -c \"grep -qF 'v1.5.0' README.md\""
    depends_on: []
    inputs: [README.md]
    outputs: [README.md]
    ac: [AC-5]
```

---

## 참조

- `skills/tdd-ko/SKILL.md` — TDD 5스텝
- `.specops/20260604-v1-5-0/plan.md` — 관련 플랜
- `scripts/dag/parse-dag.sh` — DAG 파서

---

*작성: specops-auto-ko · 2026-06-04 · FID: 20260604-v1-5-0 · 생성 커맨드: /tasks*
