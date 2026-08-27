# 사례 연구 — argus batch 정체 분석 (2026-08-27)

> **대상**: `Argus` 프로젝트, FID 36건 (§batch 25건)
> **관측 시점**: 2026-08-27 (queue 마지막 갱신 2026-08-26 08:24)
> **분석자**: specops-ko v1.80.0
> **성격**: 실사용 데이터 기반 사후 분석. 본문 수치는 전부 실측이다.

---

## 1. 한 줄 결론

**단일 모드 체인은 정상이다. batch 모드가 마지막 관문 직전에서 죽고, 그 사실이 조용히 감춰진다.**

---

## 2. 관측

```
FID 36건 중 §batch 25건 · §auto 0 · §lite 0
queue.md:  IMPL_DONE 31 · DONE 0 · SKIP 3      ← 마지막 갱신 8/26 08:24

session-progress 단계별 실행 횟수
  /implement       52
  /specify         37
  /verify          35
  /plan            33
  /clarify         32
  /receive-review  23
  /request-review  22
  /tasks           20
  ─────────────────────  ← 절벽
  /security-review  1
  /integration-test 1
  /performance-test 1
  /lifecycle (PR)   1
```

**그 1건은 batch 가 아니다.** `20260827-investor-flow-empty-fix` 는 단일 `/maintain` 이고 analyze → specify → clarify → plan → tasks → implement → verify → request/receive-review → security → integration → performance → PR 을 **전부 완주**했다.

→ 체인 설계 자체는 작동한다. 문제는 batch 층이다.

---

## 3. 문제 A — batch 가 Phase 3 완료로 재개되지 않는다 (관측된 원인)

FR 31건이 **정확히 같은 경계**에서 멈췄다. 개별 이탈이라면 분포가 흩어져야 한다.

`IMPL_DONE` 다음 단계는 Phase 3 완료 — batch 레벨 보안(Step A) → 통합(Step B) → 성능(Step C) → batch PR. 이를 강제하는 장치가 **없다**.

| 층위 | 강제 수단 |
|---|---|
| FID 체인 | `hooks/chain.yaml` + 각 SKILL.md `## 다음 skill` + 훅 + `chain_consistency` 게이트 (3중 SoT) |
| **batch 오케스트레이션** | **`commands/start-all.md` 산문뿐** |

FID 체인은 세 겹으로 잠겨 있는데, 그 위를 도는 batch 루프는 **모델이 31개 FR 을 도는 내내 루프를 놓지 않아야만** 성립한다. 세션이 끝나면 재개시킬 주체가 없다. `/status` 는 FID 단위이고 batch 진행률을 복원하는 경로가 사실상 없다.

> **일반화**: chain 에 teeth 를 넣을 때, 그 chain 을 **호출하는 상위 루프**에도 같은 질문을 해야 한다 — "여기서 세션이 끊기면 누가 이어받나".

---

## 4. 문제 B — 라벨 형식 드리프트가 하류 teeth 를 무력화 (잠복 트랩)

### 4-1. 원인 사슬

```
생성기  scripts/_internal/init-batch-queue.sh:107
        → | FR-4 | TBD | ... | PENDING |            (맨 문자열)

갱신자  모델이 queue.md 를 손으로 편집
        → | FR-4 | ... | **IMPL_DONE** |            (굵게)

독자    scripts/batch-state.sh:92
        → /^(IMPL_DONE|MERGED)/                     ← ^ 앵커. `*` 로 시작해 불일치
```

`**IMPL_DONE**` 을 쓰는 코드는 **저장소 어디에도 없다** (`grep -rn '\*\*IMPL_DONE\*\*' scripts/ commands/ skills/ templates/` → 0건). `commands/start-all.md` 가 산문으로 "Status를 `IMPL_DONE`으로 갱신"이라 지시하고, 모델이 강조 표기를 덧붙였다.

**기계가 쓴 값을 모델이 손으로 이어 쓰고, 다시 기계가 엄격히 읽는다. 정규화 지점이 없다.**

### 4-2. 파급 — 독자가 셋이다

| 소비자 | 매칭식 | 결과 |
|---|---|---|
| `scripts/batch-state.sh:92` | `/^(IMPL_DONE\|MERGED)/` | 31건 전부 "미완" 오판 |
| `scripts/_internal/collect-assumptions.sh:26` | `\|[[:space:]]*IMPL_DONE[[:space:]]*\|` | 대상 0건 |
| `scripts/_internal/record-batch-gate.sh:49` | 동일 | **`IMPL_DONE FID 0건` → exit 1** |

`record-batch-gate.sh` 는 batch 레벨 보안·통합·성능 판정을 **전 IMPL_DONE FID 로 전파**한다. `gh pr create` 의 `RELEASE_READY` 가 전 FID 각각에 이 게이트를 요구하므로, **Step A 를 정상 수행해도 전파가 실패해 PR 이 막힌다.**

### 4-3. 가장 나쁜 부분 — 조용히 통과한다

동일 queue 를 라벨만 정규화해 대조 실행한 결과:

| queue 상태 | `batch-state.sh` 기본 모드 |
|---|---|
| `**IMPL_DONE**` (실제) | `[미완]` 목록만 출력. **산출물 검사·review-skip 검사는 대상 0건 → 무발화** |
| `IMPL_DONE` (정규화) | 산출물 누락 **13건** + review-skip 무효 **3건** 즉시 노출 |

`batch-state.sh` 주석 L45 가 정확히 이 위험을 경고한다:

> `DONE` 처럼 비슷하지만 다른 라벨을 쓰면 **검사 대상 0건 → 조용히 통과**한다. dogfood 20260721 test1 이 정확히 그랬다.

그런데 **그 경고를 실행하는 라벨 검사(L54)가 `--gate` 모드에만 있다.** 기본 모드에는 없다. 경고는 남겼는데 상시 감시는 안 켠 것이다.

`--gate` 모드로 돌리면:

```
BATCH-GATE: BLOCK — per-FR 산출물·진행기록·라벨 결함 (위 목록 참조)
```

이 차단은 인라인 `SPECOPS_GOVERNANCE_BYPASS` 로 열리지 않는다 (설계상 세션 env 만 — batch PR 은 비가역이라 security Critical 과 동급).

### 4-4. A 와 B 의 관계 — 분리해서 청구한다

- **A 가 실제로 작업을 멈췄다.** 31 FR 이 IMPL_DONE 에서 정지, 8/26 이후 진전 없음.
- **B 는 PR 을 시도했다면 막았을 함정이다.** argus 는 Phase 3 완료에 도달한 적이 없어 아직 B 를 만나지 않았다.

둘은 독립된 결함이며, "A 가 멈췄고 B 가 다음에 멈췄을 것" 이 정확한 서술이다.

---

## 5. 문제 C — review-skip 이 근거 없이 통과 (3건)

| FID | review-skip.md 주장 | 실제 B/C 리포트 |
|---|---|---|
| `20260825-redis-caching` | end-loaded | 1건 (T1-C T2-B T2-C 누락) |
| `20260826-stock-detail-page` | end-loaded · B PASS · C READY_TO_MERGE | **0건** |
| `20260826-home-page` | end-loaded · B PASS · C READY_TO_MERGE | **0건** |

규약(`commands/start-all.md` Phase 3 스텝 3)은 end-loaded skip 조건으로 **"전 tid `reviews/<tid>-[BC]-report.md` 존재"** 를 요구하고, `batch-state.sh:157` 이 실제로 검사한다. **문제 B 때문에 그 검사가 대상 0건으로 돌지 않았을 뿐이다.**

이는 `docs/architecture.md` §6-2 "기록의 진실성은 검사하지 못한다"의 실제 발현이다. 모델이 자기 면제표를 발급했고, 그걸 잡을 장치가 라벨 드리프트로 꺼져 있었다.

---

## 6. 부수 관찰 (우선순위 낮음)

| 항목 | 실측 | 해석 |
|---|---|---|
| `/plan` 33 → `/tasks` 20 | 40% 유실 | batch Phase 1 재진입 패턴일 수 있어 **단정 못 함** — 별도 조사 필요 |
| R-1 위반 38건 | **33건이 07-30 하루 집중** | 초기 정착기. 08-27 은 3건 — 현재 계통적 문제 아님 |
| `/analyze` 3회 | 유지보수 진입 희소 | 대부분 신규 기능. `/maintain` 의 영향분석·회귀 AC 강점이 덜 쓰임 |
| REVIEW-PRESENCE 4건 | Phase B/C 미수행 기록 | 문제 C 와 같은 뿌리 |

---

## 7. 개선안 (영향 순)

### 7-1. 라벨을 **읽는 쪽**에서 정규화 — 1순위

독자가 3곳인데 수정 지점은 정규화 한 곳으로 수렴한다. 작성자(모델 손편집)를 고치는 건 강제가 불가능하다.

```awk
gsub(/^\*\*|\*\*$/, "", st); gsub(/^[ \t]+|[ \t]+$/, "", st)
```

가장 값싸고 가장 크게 막는다. 백틱·전각공백 등 다른 장식도 같은 지점에서 흡수한다.

### 7-2. 라벨 검사를 기본 모드로 승격

지금은 `--gate` 전용이라 **하류 teeth 가 꺼진 사실을 PR 시도 전까지 아무도 모른다.** 조용한 통과를 막으려고 만든 검사가 정작 조용한 구간에서 돌지 않는다.

### 7-3. 상태 갱신을 스크립트화

모델이 마크다운 표를 손으로 고치는 한 이 클래스는 재발한다.

```bash
scripts/_internal/queue-set-status.sh <queue> <FR-ID> IMPL_DONE
```

### 7-4. batch 재개 teeth

`/status` 가 batch queue 를 읽어 `IMPL_DONE 31/31 — Phase 3 완료 미실행` 을 보고하거나, SessionStart reconcile 이 batch 미완을 감지해 재개점을 제시해야 한다. **문제 A 를 구조적으로 막는 유일한 방법.**

### 7-5. review-skip 무효 3건 실사

리뷰 근거가 없는 FID 3건. 프론트 화면 위주라 실사 비용이 낮다.

---

## 8. 이 사례가 남기는 교훈

> **게이트가 읽는 값을 사람(또는 모델)이 손으로 쓰면, 형식 드리프트가 게이트를 조용히 끈다.**

같은 날(2026-08-27) 고친 `20260827-mutation-conf-stale` 과 **정확히 같은 병**이다:

| | mutation conf | argus queue |
|---|---|---|
| 기계가 쓴 키 | 줄 번호 | 상태 라벨 |
| 사람/모델이 이어 씀 | 예외 목록 18행 | Status 컬럼 31행 |
| 기계가 엄격히 읽음 | `grep -Fq "target\|line\|pattern\|"` | `/^IMPL_DONE/` |
| 어긋났을 때 | 점수 무음 하락 (64%→50%) | teeth 무음 해제 (검사 0건) |
| 소리가 났나 | **안 남** | **안 남** |

처방도 같다 — **정합을 확인하는 반대 방향 검사를 쌍으로 두고, 그 검사를 상시 모드에서 돌린다.**

---

## 9. 재현 방법

```bash
cd <argus>
PLUGIN=~/.claude/plugins/cache/specops-ko/specops-ko/1.80.0

# 현재 상태 — 산출물·skip 검사가 무발화
bash "$PLUGIN"/scripts/batch-state.sh .specops/batch-20260729

# 게이트 모드 — 라벨 오염으로 BLOCK
bash "$PLUGIN"/scripts/batch-state.sh --gate .specops/batch-20260729

# 라벨 정규화 후 대조 — 숨어 있던 결함 16건 노출
mkdir -p .specops/_tmp && sed 's/| \*\*\([A-Z_]*\)\*\* |/| \1 |/g' \
  .specops/batch-20260729/queue.md > .specops/_tmp/queue.md
bash "$PLUGIN"/scripts/batch-state.sh .specops/_tmp
rm -rf .specops/_tmp
```

> `rc` 를 볼 때 파이프(`| tail`) 뒤의 `$?` 는 **tail 의 코드**다. 본 분석 중 한 번 이 함정에 걸려 rc=0 으로 오독했다. `OUT=$(cmd); RC=$?` 로 잡을 것.

---

*specops-ko v1.80.0 기준 · 2026-08-27*
