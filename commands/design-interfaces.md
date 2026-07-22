---
name: design-interfaces
description: 기능 설명·화면으로 복수 인터페이스를 일괄 설계 — 목록 자동판단·승인 게이트·순차 대화 루프
triggers:
  - "/design-interfaces"
mode: ask
specops_version: 1.37.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-ko 독자 추가
---

# /design-interfaces [기능 설명]

여러 인터페이스를 한 번에 설계하는 오케스트레이터. ① 필요 인터페이스 목록을 자동 판단하고 ② 승인 게이트를 거쳐 ③ 각 인터페이스를 `/design-interface` 대화 루프로 순차 설계한다. 분업 기준은 `§인터페이스 설계 3경로 분업`(단수 `commands/design-interface.md`) 참조.

## Step 1: 인터페이스 목록 자동 판단 + 승인 게이트

**목록 근거**:
1. **화면 Interactions** (1차): `screens/*.md` 의 `## Interactions` 스캔 → 필요 엔드포인트/테이블 도출
2. **requirements.md FR 표** (보완): 화면에 안 드러난 백엔드 FR(배치·웹훅 등)도 포함
3. **클라이언트 스토리지 앱**: 화면 영속화 Interaction(예: "저장 → localStorage") 이면 data-model 엔티티도 목록에 포함 (서버 없는 프론트)

목록 제시 → `[y/수정]` 승인 게이트. `y` 시 Step 2 진행.

## Step 2: 인터페이스별 순차 대화 루프

각 인터페이스에 대해 `/design-interface {name}` 의 Step 2~4(대화 → 마스터 append → 커밋)를 순차 수행한다 (커밋은 인터페이스별 또는 루프 종료 후 1회 일괄 — 재량). 채택 섹션 덮어쓰기 금지·별도 산출물 금지 규약 동일.

## 참조
- `commands/design-interface.md` — 단수(분업표 단일출처)
- `templates/api-spec.md`·`api-spec-consumer.md`·`data-model.md`

---

*specops-ko v1.37.0 · 2026-07-10 · 복수 인터페이스 일괄 설계 오케스트레이터*
