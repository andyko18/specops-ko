---
name: status
description: "[조회] 진행 중 FID 의 Lifecycle 단계·아티팩트 현황 표시 — show-fid-status.sh 호출 (재개 시 어디까지/뭐 남았나 확인)"
triggers:
  - "/status"
mode: ask
specops_version: 1.26.4
specops_layer: Lifecycle-Tool
reference_upstream: specops-auto-ko 독자 추가
---

# /status [<FID>]

## 목적

진행 중 FID 의 **Lifecycle 단계 + 아티팩트 현황**(✅/❌)을 표시한다. 세션 재개 시 "어디까지 했나 / 무엇이 남았나"를 즉시 확인하는 수단 — 메타skill 의 "미완 lifecycle 재개 통보"(자동 1줄) 와 짝을 이루는 능동 상세 조회.

## Process

1. **FID 결정**:
   - 인자로 `<FID>` 가 주어지면 그대로 사용.
   - 인자가 없으면 `.specops/session-progress.md` 의 **최상단 `## <FID>` 헤더**(최신 진행 FID)를 추출해 사용.
2. **현황 조회 실행**:
   ```bash
   bash scripts/show-fid-status.sh <FID>
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

- `scripts/show-fid-status.sh` — 실행 스크립트(FR-1~FR-5)
- `skills/using-specops-auto-ko-ko/SKILL.md` — "미완 lifecycle 재개 통보"(자동 통보와 짝)
- `.specops/session-progress.md` — FID 진행 이력 저장소

---

*specops-auto-ko v1.26.4 · 2026-06-27 · show-fid-status 재개 조회 연결 (심층감사 UX backlog)*
