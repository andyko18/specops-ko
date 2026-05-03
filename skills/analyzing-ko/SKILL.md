---
name: analyzing-ko
description: 유지보수 진입 시 specifying-ko 앞에서 호출 — 변경 대상의 baseline (current-state.md) 과 외부 영향 (impact-analysis.md) 을 산출하고 사용자 검토 ★ HARD GATE 발동
layer: 1
reference_upstream: specops-auto-ko 독자 추가 (본가 obra/superpowers@v5.0.7 미존재 — brainstorming SKILL 흡수 패턴 분석 결과)
specops_version: 1.0.0
---

# Engine 스킬 — 분석 (analyzing)

## 개요

유지보수 진입 (`<!-- entry: maintain -->` args 첫 줄) 시 specifying-ko **앞에서** 호출. 기존 시스템 baseline 캡처 + 외부 영향 분석 → 두 산출물 + ★ HARD GATE → specifying-ko Step 1 [유지보수 분기] 가 본 결과를 참조 (재분석 생략).

<HARD-GATE>
두 산출물 (`current-state.md` + `impact-analysis.md`) 사용자 검토 통과 전 specifying-ko 호출 금지.
</HARD-GATE>

## 체크리스트

1. **structured-artifacts-ko 디렉토리 보장** — `.specops/<FID>/`
2. **current-state.md 작성** — `templates/current-state.md` 5 항목:
   - 변경 대상 식별 (파일·라인 범위 — §1 라인 합산이 trivial 자동 판정 source)
   - 호출자/의존 매핑
   - 기존 테스트 커버리지
   - 관찰 가능 동작 (Baseline)
   - 회귀 위험 메모
3. **impact-analysis.md 작성** — `templates/impact-analysis.md` 3 항목:
   - 외부 영향 (API / DB / 공유 모듈)
   - 마이그레이션·롤백 경로
   - 관련 PR·이슈 히스토리 요약 (gh CLI 또는 git log fallback)
4. **gh CLI 가용성 점검** (clarify Q-C 결정):
   - `gh --version` 성공 → `gh pr list`, `gh issue list` 사용
   - 실패 → `git log --merges --grep='Merge pull'` fallback + impact-analysis.md §3 에 "데이터 출처: git log (gh CLI 미가용 — 한계 고백)" 메타 명시 (5 원칙 5)
5. **변경 규모 평가** — current-state.md §1 라인 범위 합산:
   - ≤ 5 → spec.md §유형 = `trivial` 자동 (impact-analysis.md §1·§2 생략 가능, §3 만 작성)
   - > 5 → 3 항목 모두 작성
6. **★ HARD GATE** — "분석 결과 검토. 진행? [y/n]"
7. **session-progress append** — `bash scripts/session-progress-append.sh <FID> /analyze 완료 "current-state.md, impact-analysis.md"`
8. **다음 skill** — `specops-auto-ko:specifying-ko` 호출 (args 그대로 전달 — `<!-- entry: maintain -->` 첫 줄 유지)

## 5 원칙 주입

| 원칙 | 본 skill 적용 |
|---|---|
| 1 투명성 | 분석 근거 (grep 결과·gh 출력) 산출물에 인용 |
| 2 문지기 | gh 미가용 시 HARD GATE 차단 안 함 (clarify Q-C: git log fallback) |
| 4 주권 | 두 산출물 사용자 검토 후만 진행 |
| 5 한계 고백 | gh 미가용 / 동적 호출자 미식별 등 한계 명시 |

## 안티패턴

- **변경 규모 평가 생략** — trivial 자동 판정 source 가 본 단계 §1 라인 범위 메타. 생략하면 specifying-ko §유형 라벨 부정확
- **gh 강제** — clarify Q-C 결정으로 git log fallback. HARD GATE 차단 금지
- **specifying-ko 본문 중복** — 본 skill 은 분석만. 5 항목 mini-checklist 는 specifying-ko 가 흡수하지 않고 본 skill 책임 (Phase C 적용 후 specifying-ko 본문 축약)

## 다음 skill

```
Skill: specops-auto-ko:specifying-ko
```
