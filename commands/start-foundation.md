---
name: start-foundation
description: "[공통부·대화형] specops-ko 한국어 자율 Lifecycle — 공통부 우선 개발 진입. specifying-ko 를 foundation 분기로 호출"
triggers:
  - "/start-foundation"
mode: ask
specops_version: 1.72.0
specops_layer: Lifecycle
reference_upstream: specops-ko 독자 추가
---

# /start-foundation [<공통부 설명>]

## 목적

specops-ko Lifecycle 에서 **per-feature `/start` 사이클 이전에** 실행 가능한 공통부 코드(라우팅·레이아웃·인증·공통 컴포넌트·DB 마이그레이션)를 생성하는 독립 커맨드.

한국 SI 표준 "공통부 먼저 개발" 단계를 지원한다. `/init-project`(doc-only) → **`/start-foundation`(공통 코드)** → `/start`(기능 단위) 순서로 진행.

## Process

0. **init 원장 우선** — `.specops/memory/project-context.md`·`decisions.md`가 있으면 clarifying이 이미 확정된 스택·인증·배포를 **재질문하지 않는다**(clarifying-ko 결정 원장 HARD). init 없이 진입했고 architecture placeholder만 있으면 기존 BLOCKING 게이트 유지.
1. `specops-ko:specifying-ko` 스킬 호출 — args 첫 줄에 `<!-- entry: foundation -->` HTML 주석을 prepend 하고 나머지 args 이어붙임
2. specifying-ko 가 foundation 분기 감지 → Step 5.5 **셸 전용**(allowlist `app-shell`·`layout`·`login` + `<!-- foundation-shell -->`, 기능 화면 금지) → **Step 5.6 인터페이스 design-first** — 이번 공통부가 **API 엔드포인트(제공)·DB 스키마(테이블·필드)·클라이언트 영속 데이터(localStorage·IndexedDB) 중 하나를 신설·변경할 때만** 적용한다(`specifying-ko` Step 5.6 적용 조건 — 순수 UI·CLI 로직만이면 skip). 공통부는 DB 스키마·공통 API 의 **본진**이라 design-first 가 가장 중요하다 → 공통부 컴포넌트 spec 작성 (§유형=`foundation`)
3. 이후 chain: clarifying-ko(기술스택 BLOCKING 게이트 — 원장에 없으면) → planning-ko(foundation-manifest.md 산출) → decomposing-ko → implementing-ko → verifying-evidence-ko → requesting-code-review-ko → receiving-code-review-ko → security-review-ko → integration-test-ko → performance-test-ko → PR

## 사용 예

```
/start-foundation React 기반 SPA 공통부 — 라우팅, 인증, 레이아웃, API 클라이언트

→ specifying-ko 호출 (args 첫 줄: <!-- entry: foundation -->)
→ foundation 분기 진입 → Step 5.5 셸(app-shell 등) → 공통부 spec 작성
→ Step 5.6: 공통 API·테이블을 api-spec.md·data-model.md 에 먼저 반영 (foundation-baseline 마커 안에)
→ clarifying-ko: 기술 프레임워크 BLOCKING 확정
→ planning-ko: 공통부 구현 + foundation-manifest.md 산출
→ decomposing-ko: 재사용 HARD GATE 활성
→ 이후 /start <기능> 시 각 task 가 재사용 선언 의무화
```

## 안티패턴

- **기능 화면을 foundation에서 설계** — `dashboard`/`home` 등 allowlist 밖 `screens/*` 금지. 셸(`app-shell`·`layout`·`login`)만. 기능 화면은 `/start-all` Phase 2.5-A
- **화면 단위 기능 구현 요구** — `/start-foundation` 은 인프라·공통부 전용. 기능 FR은 foundation 완료 후 `/start`·`/start-all`
- **specifying-ko 생략** — 공통부라도 spec → clarify → plan → decompose 체인 필수. 직접 구현 금지
- **`/init-project` 대체** — `/start-foundation` 은 foundation 코드 생성 전용. 프로젝트 문서 부트스트랩은 `/init-project` 담당
- **§batch 라벨 병기** — foundation FID 에 `**§batch**` 를 쓰지 않는다(hybrid 금지). requirements 의 `[공통]` FR 은 `/start-all` 이 SKIP 하므로 batch queue 에 넣을 필요 없음

## 참조

- `skills/specifying-ko/SKILL.md` — foundation 분기 처리 (Step 5.5 셸 전용, §유형=foundation)
- `skills/clarifying-ko/SKILL.md` — 기술스택 BLOCKING 게이트
- `skills/planning-ko/SKILL.md` — foundation-manifest.md 산출 지시
- `skills/decomposing-ko/SKILL.md` — 재사용 HARD GATE 조건
- `templates/foundation-manifest.md` — manifest 템플릿
- `commands/start.md` — 기능 단위 구현 진입 슬래시 (미러링 패턴 참조)
- `scripts/_internal/check-fr-table.sh` — `[공통]` → `foundation-scope` SKIP (start-all Phase 0)
- `scripts/_internal/check-foundation-manifest.sh` — **verify HARD 게이트**. §유형=foundation FID 완료 시 `.specops/memory/foundation-manifest.md` 존재·채움을 검사해 미산출이면 `VERIFY: FAIL` (`run-verification.sh` 가 호출)
- `scripts/_internal/check-spec-label-compat.sh` — **verify HARD 게이트**. `§유형=foundation` 과 `§batch` hybrid 라벨을 금지 (emit-context·verify 양쪽에서 FAIL)

---

*specops-ko v1.72.0 · 2026-06-04 · foundation 분기 진입 슬래시*
