<!-- FID: 20260427-sprint-contracts-regression-ac-checklist -->
<!-- OWNER_COMMAND: /maintain → analyzing-ko -->

# Impact Analysis — sprint-contracts-ko 회귀 AC 체크리스트 항목 본문

> **변경 규모 평가**: current-state.md §1 라인 합산 추정 1 ~ 5 라인 → `trivial` 후보. analyzing-ko Step 5 규약상 §1·§2 생략 가능하나, **specifying-ko line 79 인용 정합 risk** 때문에 §1 만 brief 작성. §2 는 git revert 단순 → 생략. §3 은 필수 작성.

## 1. 외부 영향 (brief)

| 영역 | 영향 종류 | 정합 필요 여부 |
|---|---|---|
| `skills/specifying-ko/SKILL.md` line 79 | "sprint-contracts-ko evaluator 가 `AC-R-*` ≥ 1 강제" 인용 | **wording 의미 변경 시 인용 동시 갱신 필요** |
| `templates/acceptance-criteria.md` line 57~71 | `## 회귀 방지 AC (유지보수 FID 필수)` 섹션 + 신규/trivial 면제 메모 | **면제 조건 변경 시 템플릿 메모 갱신 필요** |
| `skills/sprint-contracts-ko/SKILL.md` line 79 | 안티패턴 dual location | **wording 의미 변경 시 동시 수정** |
| dogfood fixture (`.specops/20260427-test-bugfix-fixture/`, `.specops/20260427-test-trivial-typo/`) | 의미 변경 영향 (간접) | brief 검토 — 본 wording 변경이 fixture AC 의미를 바꾸지 않는지 specifying-ko 단계에서 확인 |
| API / DB / 공유 모듈 | 없음 — markdown skill 본문 변경이라 런타임 영향 zero |

## 2. 마이그레이션·롤백 경로

**생략** (trivial 추정) — markdown wording 변경이라 `git revert <commit>` 단순 롤백. 마이그레이션 단계 없음.

## 3. 관련 PR·이슈 히스토리

데이터 출처: `gh pr list --search "sprint-contracts"` (gh CLI 2.83.2 사용 가능 — 한계 고백 불필요) + `git log --oneline --all -- skills/sprint-contracts-ko/SKILL.md`.

| commit | 의미 | 본 변경과의 관계 |
|---|---|---|
| `a273dc8` | `feat(B): 회귀 AC must 강제 + dogfood fixture (B1/B2/B3)` | **본 체크리스트 line 55 + 안티패턴 line 79 도입 commit** — 의미 baseline source. wording 개선 시 본 commit 의 도입 의도 (회귀 검증 근거 강제) 보존 필수 |
| `a62ccb2` | `fix(ref_upstream_fmt): 16 skill 파일 reference_upstream 포맷 정합` | 무관 (frontmatter 정합) |
| `433a624` | `feat(v0.0): P1 — skill 구조 표준화 + SessionStart 자동 주입` | 무관 (skill 구조 표준화) |

**열린 PR**: 없음 (`gh pr list --state all --search "sprint-contracts"` → No Pull Requests).

**주의**: `a273dc8` 가 본 체크리스트 도입 시 dogfood fixture 두 개 (`20260427-test-bugfix-fixture`, `20260427-test-trivial-typo`) 를 함께 add — wording 변경 시 두 fixture 의 acceptance-criteria.md 의미가 흔들리지 않는지 specifying-ko 단계에서 brief 검토 권장.

---

*작성: analyzing-ko · 2026-04-27 · FID: 20260427-sprint-contracts-regression-ac-checklist · 변경 규모: trivial 후보 (1~5 라인 추정)*
