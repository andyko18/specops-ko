<!-- FID: 20260519-finishing-dev-branch-ko -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260519-finishing-dev-branch-ko

## 기능 AC

| ID | Given | When | Then | must/should |
|---|---|---|---|---|
| AC-1 | `skills/finishing-a-development-branch-ko/SKILL.md` 미존재 | 파일 생성 후 | frontmatter 6필드(name·description·layer·reference_upstream·specops_version·used_by) 전부 존재 | must |
| AC-2 | SKILL.md 생성 | `validate-structure.sh` 실행 | 전 항목 ✅ (file_counts 포함) | must |
| AC-3 | SKILL.md 생성 | `test-skill-conventions.sh` 실행 | PASS=5 FAIL=0 유지 | must |
| AC-4 | finishing SKILL.md 내용 | - | 현재 상태 확인 절차 (미커밋·미push 검증) 명시 | must |
| AC-5 | finishing SKILL.md 내용 | - | PR merged 확인 + 미머지 시 HARD GATE 명시 | must |
| AC-6 | finishing SKILL.md 내용 | - | Worktree 정리 (`git worktree remove`) 절차 명시 | must |
| AC-7 | finishing SKILL.md 내용 | - | 로컬 feature branch 삭제 (`git branch -d`, 미머지 시 `-D` 금지) 명시 | must |
| AC-8 | finishing SKILL.md 내용 | - | Remote branch 삭제는 사용자 확인(`[y/n]`) 후 실행 명시 | must |
| AC-9 | finishing SKILL.md 내용 | - | `git checkout main && git pull` main 동기화 절차 명시 | must |
| AC-10 | finishing SKILL.md 내용 | - | `## 5원칙 주입` 섹션 + `## 다음 skill` 섹션 존재 | must |

## 회귀 방지 AC (유지보수 FID 필수)

| ID | Given | When | Then | must/should |
|---|---|---|---|---|
| AC-R-1 | `skills/using-git-worktrees-ko/SKILL.md` 기존 내용 | `bash scripts/tests/test-skill-conventions.sh` 실행 | PASS=5 FAIL=0 유지 — using-git-worktrees-ko 기존 통과 항목 회귀 없음 | must |
| AC-R-2 | `scripts/_internal/.structure-baseline` 갱신 | `bash scripts/_internal/validate-structure.sh` 실행 | `file_counts: OK` (count 25 반영) | must |

---

*작성: specifying-ko · 2026-05-19 · FID: 20260519-finishing-dev-branch-ko*
