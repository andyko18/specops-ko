---
name: status
description: "[조회] 진행 중 FID 의 Lifecycle 단계·아티팩트 현황 표시 — show-fid-status.sh 호출 (재개 시 어디까지/뭐 남았나 확인)"
triggers:
  - "/status"
mode: ask
specops_version: 1.51.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-ko 독자 추가
---

# /status [<FID>]

## 목적

진행 중 FID 의 **Lifecycle 단계 + 아티팩트 현황**(✅/❌) + **실제 진행 대조(reconcile)**를 표시한다. 세션 재개 시 "어디까지 했나 / 무엇이 남았나"를 즉시 확인하는 수단 — 메타skill 의 "미완 lifecycle 재개 통보"(자동 1줄) 와 짝을 이루는 능동 상세 조회.

**reconcile (v1.51.0)** — session-progress 단독은 정체 후 현실을 **과소보고**한다(dogfood test1 FR-3: `/tasks` 기록 상태에서 12커밋+dispatch T7까지 존재했으나 주 breadcrumb 만 읽어 "구현 안 됨"으로 오판 → 24h+ 방치, 실제 잔여는 5분). show-fid-status 는 **기록 frontier(session-progress) ↔ 증거 frontier(산출물·dispatch-log·git 브랜치 커밋)**를 대조해, 증거가 앞서면 `⚠️ DESYNC` 로 **진짜 재개점**과 **기록 보정 구간**을 제시한다.

## Process

1. **FID 결정**:
   - 인자로 `<FID>` 가 주어지면 그대로 사용.
   - 인자가 없으면 `.specops/session-progress.md` 의 **최상단 `## <FID>` 헤더**(최신 진행 FID)를 추출해 사용.
2. **현황 조회 실행**:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}"/scripts/show-fid-status.sh <FID>
   ```
3. 출력(Lifecycle 단계 진행 + 아티팩트 ✅/❌ 체크리스트)을 그대로 표시.

## 사용 예

```
/status

→ session-progress 최신 FID 자동 추출 → 단계·아티팩트 현황 표시
```

```
/status 20260627-greet-cli-e2e

→ 지정 FID 의 현황 표시
```

## 안티패턴

- **상태 변경** — 본 슬래시는 읽기 전용. 아티팩트 생성·수정 금지(조회만).
- **FID 형식 우회** — show-fid-status.sh 가 `YYYYMMDD-kebab-slug` 형식·디렉토리 존재를 검증(미존재 시 Error).

## 참조

- `scripts/show-fid-status.sh` — 실행 스크립트(FR-1~FR-5 + reconcile FR-6)
- `skills/using-specops-ko/SKILL.md` — "미완 lifecycle 재개 통보"(자동 통보와 짝)
- `.specops/session-progress.md` — FID 진행 이력 저장소

---

*specops-ko v1.51.0 · 2026-07-18 · reconcile 대조(기록↔증거 frontier, 정체 재개점 제시)*
