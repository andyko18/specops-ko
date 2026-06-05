---
name: start-batch
description: specops-auto-ko 한국어 자율 Lifecycle — requirements.md FR 표 전체 기능 일괄 구현 슬래시. 3-Phase 오케스트레이터
triggers:
  - "/start-batch"
mode: ask
specops_version: 1.0.0
specops_layer: Lifecycle
reference_upstream: specops-auto-ko 독자 추가
---

# /start-batch

## 목적

`requirements.md` FR 표의 **전체 기능**을 단일 세션에서 일괄 구현하는 오케스트레이터.

`/start-project`(doc-only) → `/start-foundation`(공통 코드) → **`/start-batch`(전체 기능 일괄 구현)** 순서로 진행. `/start`의 단일 기능 루프를 FR 단위로 자동 반복한다.

## Process

### Phase 0 — 준비

1. **batch-id 결정** (실행 날짜 기준):
   ```
   BATCH_ID = "batch-<YYYYMMDD>"   예: batch-20260605
   ```
2. **requirements.md 탐색** (`.specops/memory/requirements.md` 우선, 없으면 루트):
   - 탐색 순서: `.specops/memory/requirements.md` → `requirements.md`
   - 두 곳 모두 없으면: "`requirements.md`가 없습니다. `/start-project`를 먼저 실행하세요." 출력 후 **중단**
3. **FR 목록 파싱**:
   ```bash
   grep -E '^\| FR-[0-9]+ \|' <requirements.md 경로>
   ```
   FR 행 0건이면: "FR 표가 비어 있습니다. `requirements.md`에 FR 표를 작성 후 재실행하세요." 출력 후 **중단**
4. **batch 브랜치 생성** (1회, 재진입 시 skip):
   ```bash
   # 이미 존재하면 switch, 없으면 create
   git show-ref --verify --quiet "refs/heads/feat/$BATCH_ID" \
     && git checkout "feat/$BATCH_ID" \
     || git checkout -b "feat/$BATCH_ID"
   ```
5. **queue.md 초기화** — `.specops/$BATCH_ID/queue.md` 생성 (재진입 시 기존 파일 재사용):
   `.specops/$BATCH_ID/queue.md` 이미 존재하면 → **기존 파일 재사용** (초기화 스킵, PENDING/PLAN_DONE 상태 보존).
   없으면 신규 생성:
   ```
   | FR-ID | FID | FR 설명(1줄) | Status |
   |---|---|---|---|
   | FR-1 | TBD | <FR 설명> | PENDING |
   | FR-2 | TBD | <FR 설명> | PENDING |
   ...
   ```
   FID 컬럼은 Phase 1에서 `BATCH-PHASE1-DONE: <FID>` 수신 후 실제 FID로 갱신됨.

### Phase 1 — 전 FR spec→decompose (대화형)

각 FR에 대해 **순서대로** 반복 (queue.md PENDING 항목):

1. `specops-auto-ko:specifying-ko` 호출 — args 정확히 아래 형식:
   ```
   <!-- entry: batch -->
   <!-- batch-id: <BATCH_ID> -->
   <FR 원문 — FR-N 행의 설명 부분>
   ```
2. specifying-ko → clarifying-ko → planning-ko → decomposing-ko 체인 자동 진행 (FID는 specifying-ko Step 0이 결정)
3. decomposing-ko 출력에서 `BATCH-PHASE1-DONE: <FID>` 감지 → queue.md 해당 FR의 FID 컬럼을 `TBD`에서 실제 `<FID>`로 갱신 + Status를 `PLAN_DONE`으로 갱신
4. 다음 PENDING FR 반복

> **HARD GATE**: clarifying-ko의 BLOCKING 질문은 사용자 응답 필수. Phase 1은 대화형이다.

### Phase 2 — 일괄 리뷰 (단일 게이트)

1. 전 FID의 `.specops/<FID>/spec.md`, `plan.md`, `tasks.md` 핵심 내용 요약 제시
2. 단일 게이트: **"전체 구현 진행? [y/n]"**
   - `n` → **중단**. 아티팩트 보존, `feat/<BATCH_ID>` 브랜치 보존. `/start-batch` 재진입 시 Phase 3부터 재개 가능
   - `y` → Phase 3 진입

### Phase 3 — per FR 순차 구현 (무중단)

queue.md의 PLAN_DONE 항목을 **순서대로** 처리 (IMPL_DONE은 skip):

1. `specops-auto-ko:implementing-ko` 호출 (FID 기준)
2. 완료 → `specops-auto-ko:verifying-evidence-ko` 호출
3. 완료 → `specops-auto-ko:requesting-code-review-ko` 호출
4. 완료 → `specops-auto-ko:receiving-code-review-ko` 호출
5. receiving-code-review-ko의 "PR 생성? [y/n]" → **n (decline)** — per-FR PR 생성 금지
6. queue.md 해당 FR → `IMPL_DONE` 갱신
7. 다음 PLAN_DONE FR 반복

> **HARD GATE**: implementing-ko HARD GATE cap 초과 시에만 사용자 개입 요청. 그 외 실패는 `specops-auto-ko:systematic-debugging-ko`로 처리 후 재개.

### Phase 3 완료 — batch PR 생성

전 FID IMPL_DONE 확인 후:
```bash
git push -u origin "feat/$BATCH_ID"
```
```bash
gh pr create \
  --base main \
  --head "feat/$BATCH_ID" \
  --title "feat: $BATCH_ID 전체 기능 일괄 구현" \
  --body "$(cat <<'EOF'
## Summary
- /start-batch로 requirements.md FR 전체 기능 일괄 구현

## FR 목록
queue.md 상태 전이 요약 (PENDING→PLAN_DONE→IMPL_DONE) 직접 기재

## Test plan
- [ ] 전 FR verifying-evidence-ko PASS 확인
- [ ] validate-structure.sh 전 항목 ✅

🤖 Generated with specops-auto-ko /start-batch
EOF
)"
```

## 안티패턴

- **requirements.md FR 표 없이 실행** — `/start-project` 먼저 실행해 `requirements.md`에 FR 표 작성 후 `/start-batch` 진입
- **spec 생략 요구** — 각 FR에 대해 specifying-ko → clarifying-ko → planning-ko → decomposing-ko 체인 필수. Phase 1 생략 금지
- **per-FR PR 생성** — Phase 3에서 per-FR "PR 생성?" 에 반드시 **n으로 decline**. 최종 batch PR 1개만 생성. `receiving-code-review-ko`는 이 게이트를 사용자에게 직접 묻는다 — 오케스트레이터가 명시적으로 decline해야 하며, 사용자가 y로 답하면 per-FR PR이 생성되어 설계 의도와 어긋남
- **Phase 2 건너뜀** — 일괄 리뷰 게이트는 필수. 사용자 확인 없이 Phase 3 진입 금지

## 참조

- `skills/specifying-ko/SKILL.md` — batch 분기 (Step 0 git-branch-create skip, §batch 라벨)
- `skills/decomposing-ko/SKILL.md` — Phase 1 정지점 (BATCH-PHASE1-DONE)
- `commands/start-foundation.md` — 미러링 패턴
- `commands/start.md` — 단일 기능 진입 슬래시
- `templates/requirements.md` — FR 표 포맷 참조

---

*specops-auto-ko v1.7.0 · 2026-06-05 · 3-Phase 일괄 구현 오케스트레이터*
