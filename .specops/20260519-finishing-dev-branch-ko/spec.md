<!-- FID: 20260519-finishing-dev-branch-ko -->
<!-- OWNER_COMMAND: /specify -->
<!-- layer: Lifecycle-Artifact -->

# finishing-a-development-branch-ko 명세 — 20260519-finishing-dev-branch-ko

## 1. 개요

**§유형**: 유지보수

**목적**: feature branch 작업 완료 후 worktree 정리 → branch 삭제 → main 동기화를 체계적으로 강제하는 `finishing-a-development-branch-ko` SKILL.md 신규 생성.

**배경**: `using-git-worktrees-ko`가 `integrates_with: specops-auto-ko:finishing-a-development-branch-ko`로 짝 스킬을 선언하고 있으나 파일이 존재하지 않는다. 데드 링크 상태로 worktree 작업 완료 후 정리 절차가 미정의. PR 머지 이후 잔류 worktree·feature branch 정리를 가이드하는 스킬이 필요하다.

**성공 판정**: `skills/finishing-a-development-branch-ko/SKILL.md`가 생성되고, `validate-structure.sh` + `test-skill-conventions.sh` 전 항목이 PASS됨.

## 2. 범위

### 포함

- `skills/finishing-a-development-branch-ko/SKILL.md` 신규 생성 (의존: 없음 — 독립)
- `scripts/_internal/.structure-baseline` count 24→25 갱신 (의존: SKILL.md 생성)

### 포함 (SKILL.md 내용 구성)

- **현재 상태 확인** — 브랜치명·미커밋·미push 변경 유무
- **PR 상태 확인** — `gh pr view` 기반 merged 확인 + 미머지 경고
- **Worktree 정리** — `.worktrees/<FID>*/` 대상 `git worktree remove`
- **Feature branch 삭제** — `git branch -d feat/<FID>` (미머지 시 `-D` 금지)
- **Remote branch 삭제** — `git push origin --delete feat/<FID>` (사용자 확인 후)
- **main 동기화** — `git checkout main && git pull`
- **정리 확인** — worktree list + branch list 출력

### 제외 (YAGNI)

- PR 생성 로직 — `receiving-code-review-ko`가 담당
- merge conflict 해결 — 별도 흐름
- CI/CD 상태 확인 — 이번 스킬 범위 밖

## 3. 사용자 시나리오

### 주요 시나리오

**사용자**: implementing-ko 완료 후 PR 머지까지 마친 개발자  
**상황**: `feat/<FID>` 브랜치에 작업이 완료됐고, PR이 main에 머지됨  
**행동**: `specops-auto-ko:finishing-a-development-branch-ko` 스킬 호출  
**기대 결과**: worktree 삭제 → feature branch 삭제 → main pull 순서로 정리 완료, git 상태 클린

### 보조 시나리오

**PR 미머지 상태**: HARD GATE — `-D` 강제 삭제 금지, 사용자에게 PR 상태 확인 요청

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | 현재 브랜치가 feat/ 브랜치인지, 미커밋·미push 변경이 없는지 확인한다 | must |
| FR-2 | `gh pr view` 로 PR merged 상태를 확인하고, 미머지 시 경고 출력 후 중단한다 | must |
| FR-3 | `.worktrees/<FID>*/` 패턴으로 worktree를 감지하고 `git worktree remove` 실행한다 | must |
| FR-4 | `git branch -d feat/<FID>` 로 로컬 feature branch를 삭제한다. 미머지 시 `-D` 금지 | must |
| FR-5 | remote branch 삭제는 사용자 확인(`[y/n]`) 후 실행한다 | must |
| FR-6 | `git checkout main && git pull` 로 main 동기화한다 | must |
| FR-7 | 정리 완료 후 `git worktree list` + `git branch` 출력으로 잔류 없음을 검증한다 | should |
| FR-8 | gh CLI 미가용 시 PR 상태 확인 fallback을 제공한다 (git log 기반) | should |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 안전성 | `git branch -D` 강제 삭제는 사용자 명시 승인 없이 절대 금지 |
| NFR-2 | 투명성 | 각 단계 실행 전 "무엇을 하려 하는지" 1줄 출력 |
| NFR-3 | 호환성 | bash 3.2+ (macOS 실측), gh CLI 없는 환경 graceful fallback |

## 6. 제약사항

- 기술 스택: bash 스크립트 (SKILL.md 문서, 실행 코드 아님)
- 의존성: git, gh CLI (선택)
- 호환성: 기존 layer:2 SKILL.md frontmatter 포맷 + `## 5원칙 주입` + `## 다음 skill` 필수
- 파일명 규약: `skills/finishing-a-development-branch-ko/SKILL.md`

## 7. 가정

- PR은 `gh pr create`로 생성됐고 remote에 `origin`이 있음
- Worktree 디렉터리 패턴은 `.worktrees/<FID>-<task-id>/`
- feature branch 명명: `feat/<FID>`

## 8. 열린 질문

- Q1: `## 다음 skill`은 무엇으로 지정해야 하는가? finishing이 Lifecycle 최종 단계이므로 "chain 종료" 명시가 적합한지.

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음. 설계가 단순 SKILL.md 생성이며 기존 패턴 명확함.

## 10. 참조

- 분석 산출물: `.specops/20260519-finishing-dev-branch-ko/current-state.md`
- 분석 산출물: `.specops/20260519-finishing-dev-branch-ko/impact-analysis.md`
- 짝 스킬: `skills/using-git-worktrees-ko/SKILL.md`
- upstream 참조: `obra/superpowers@v5.0.7 skills/finishing-a-development-branch/SKILL.md`

---

*작성: specifying-ko · 2026-05-19 · FID: 20260519-finishing-dev-branch-ko · 생성 커맨드: /maintain*
