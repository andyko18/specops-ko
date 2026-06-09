# T1 Phase C — code-reviewer-ko feedback

**결과**: FAIL
**Critical**: 0건
**Important**: 2건

## 이슈 목록

### [Important] commands/design-screens.md:76 — commit 타입 비표준
Step 3-5의 commit 메시지 타입 `"design:"` 은 git-workflow.md 허용 타입(feat/fix/refactor/docs/test/chore/perf/ci)에 없음. 단수 커맨드(`design-screen.md`)의 `"feat(screens):"` 와도 불일치.

**수정**: `git commit -m "design: {name} 화면 설계 추가"` → `git commit -m "feat(screens): {name} 화면 설계 추가"`

### [Important] commands/design-screens.md:75-77 — screens-overview.md git add 누락
Step 3-5의 `git add` 에 `.specops/memory/screens-overview.md 2>/dev/null || true` 가 없음. 단수 커맨드 Step 5는 이 줄을 포함하며, 스캐폴딩 스크립트가 screens-overview.md 를 갱신하므로 커밋에 포함해야 함.

**수정**: git add 블록에 다음 줄 추가:
```bash
git add .specops/memory/screens-overview.md 2>/dev/null || true
```
