---
name: start-all-auto
description: "[전체·무인] specops-auto-ko 한국어 자율 Lifecycle — requirements.md FR 표 전체 기능 무인(가역 게이트 자동통과) 일괄 구현. /start-all 무인 변형, batch PR 직전 1회만 확인"
triggers:
  - "/start-all-auto"
mode: ask
specops_version: 1.19.2
specops_layer: Lifecycle
reference_upstream: specops-auto-ko 독자 추가 (start-all + start-auto 결합)
---

# /start-all-auto [<기능 설명>]

## 목적

`/start-all` 의 **무인 변형**. 한 번 진입하면 `requirements.md` FR 표 전체를 spec→clarify→plan→decompose→implement→verify→review→security→integration→performance 까지 **가역 게이트 자동 통과**, batch PR 직전 가정 다이제스트와 함께 1회만 확인.

`/start` ↔ `/start-auto` 선례를 미러링한 `/start-all` ↔ `/start-all-auto` 대칭 진입점.

**가역 게이트는 자동 통과, 비가역 행동(batch PR 생성, 파괴적/덮어쓰기 task, security Critical/High)에서만 정지.**

## Process

Phase 0~3 오케스트레이션(batch-id 결정·`requirements.md` 탐색·FR 파싱·`feat/<BATCH_ID>` 브랜치·`queue.md` 관리)은 **`commands/start-all.md` 와 동일**. 아래는 §auto 무인 차이점만 명시한다.

1. **메타 skill 활성 확인** — `skills/using-specops-auto-ko-ko/SKILL.md` 가 세션 시작 시 이미 활성돼 있어야 함.
2. **인자 선택적** — 인자 없이 `requirements.md` FR 표 전체를 무인 순회한다(`/start-all` 미러). 인자를 주면 추가 맥락으로만 사용. (빈 인자 되물음 없음.)
3. **Phase 1 각 FR specifying 호출 args 3줄 prepend** — 각 FR 의 specifying-ko 호출 시 args 앞에 자동 주입:
   ```
   <!-- entry: batch -->
   <!-- batch-id: <BATCH_ID> -->
   <!-- auto: true -->
   <FR 원문>
   ```
   - `entry: batch` → specifying-ko batch 분기 (git-branch-create skip, `**§batch**` 라벨)
   - `auto: true` (셋째 줄) → specifying-ko batch 분기가 **추가 감지** → spec.md §1 에 `**§auto**: true` 동시 기재
   - 결과: 각 spec.md §1 = `**§유형**` + `**§batch**: <id>` + `**§auto**: true` → 다운스트림 6개 skill 무변경으로 §auto 자동통과 전파
4. **Phase 1 무인** — 각 FR clarify BLOCKING 모호점은 spec.md `**§auto**: true` 라벨 기반으로 best-guess 자동응답 + `status: ASSUMED` 기록(clarifying-ko §auto 분기). 사용자 정지 없음.
5. **Phase 2 자동통과** — 일괄 리뷰 게이트("전체 구현 진행? [y/n]")를 자동 통과(start-all.md Phase 2 §auto 분기) → Phase 3 직행.
6. **batch PR 게이트 = 가정 다이제스트** — batch PR 직전 자동 수집·제시:
   - 전 FID `clarifications.md` 의 `status: ASSUMED` 항목 (FID별 그룹)
   - 전 FID `handoffs/*.md` Decided 필드 집계
   - 전 FID spec.md "자동 결정 화면" 목록
   - 제시 후: **"위 가정 위에 N개 FR 구현됨. batch PR 생성? [y/n]"** — 단일 [y/n] 확인.

## §auto 모드 동작 (batch)

| 단계 | start-all-auto 동작 | 정지? |
|---|---|---|
| Phase 1 각 FR clarify BLOCKING | best-guess 자동응답 + `status: ASSUMED` (clarify §auto 분기, spec 라벨 기반) | ❌ |
| Phase 2 일괄 리뷰 게이트("전체 구현 진행?") | **자동 통과** → Phase 3 직행 | ❌ |
| Phase 3 implement/verify cap 초과 | systematic-debugging → 1회 재시도 → 재실패 시 정지 | ⚠️ |
| Phase 3 파괴적/덮어쓰기 task | mini HARD GATE 정지 (§auto 우회 불가) | 🛑 |
| security-review-ko Critical/High | **차단 보존** — §auto여도 자동통과 금지 (systematic-debugging 후 재실행) | 🛑 |
| batch PR 게이트 | 가정 다이제스트(전 FR ASSUMED 집계) 제시 + [y/n] 1회 | 🛑 |

## 안티패턴

| 합리화 | 거절 사유 |
|---|---|
| "자연어로 무인 추론 진행" | 진입은 슬래시(`/start-all-auto`)로만 — 메타 skill 신호 감지와 구분 |
| "FR마다 개별 PR 생성" | batch PR 1회 원칙 위반 — 전 FR 일괄 PR |
| "security Critical/High 도 §auto니 자동통과" | 비가역 불변식 위반 — 무인이어도 차단 보존 |
| "빈 인자니 기능 설명 되물음" | `/start-all` 미러 — requirements.md FR 표 전체 순회 (AC-9) |

## 참조

- `commands/start-all.md` — Phase 0~3 batch 오케스트레이션 본문 (동일 참조)
- `commands/start-auto.md` — §auto 단일기능 선례(자체 독립 본문 패턴)
- `skills/specifying-ko/SKILL.md` — batch+auto 라벨 동시기재 분기
- `skills/clarifying-ko/SKILL.md` L20 — §auto best-guess 분기(spec 라벨 grep)

---

*specops-auto-ko v1.19.2 · 2026-06-22 · 무인 배치 오케스트레이터 (requirements.md FR 전체 가역 게이트 자동통과, 비가역 정지)*
