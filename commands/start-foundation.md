---
name: start-foundation
description: specops-auto-ko 한국어 자율 Lifecycle — 공통부 우선 개발 진입 슬래시. specifying-ko 를 foundation 분기로 호출
triggers:
  - "/start-foundation"
mode: ask
specops_version: 1.0.0
specops_layer: Lifecycle
reference_upstream: specops-auto-ko 독자 추가
---

# /start-foundation [<공통부 설명>]

## 목적

specops-auto-ko Lifecycle 에서 **per-feature `/start` 사이클 이전에** 실행 가능한 공통부 코드(라우팅·레이아웃·인증·공통 컴포넌트·DB 마이그레이션)를 생성하는 독립 커맨드.

한국 SI 표준 "공통부 먼저 개발" 단계를 지원한다. `/start-project`(doc-only) → **`/start-foundation`(공통 코드)** → `/start`(기능 단위) 순서로 진행.

## Process

1. `specops-auto-ko:specifying-ko` 스킬 호출 — args 첫 줄에 `<!-- entry: foundation -->` HTML 주석을 prepend 하고 나머지 args 이어붙임
2. specifying-ko 가 foundation 분기 감지 → Step 5.5 화면 루프 skip → 공통부 컴포넌트 spec 작성 (§유형=`foundation`)
3. 이후 chain: clarifying-ko(기술스택 BLOCKING 게이트) → planning-ko(foundation-manifest.md 산출) → decomposing-ko → implementing-ko → verifying-evidence-ko → requesting-code-review-ko → receiving-code-review-ko → integration-test-ko → performance-test-ko → PR

## 사용 예

```
/start-foundation React 기반 SPA 공통부 — 라우팅, 인증, 레이아웃, API 클라이언트

→ specifying-ko 호출 (args 첫 줄: <!-- entry: foundation -->)
→ foundation 분기 진입 → Step 5.5 skip → 공통부 spec 작성
→ clarifying-ko: 기술 프레임워크 BLOCKING 확정
→ planning-ko: 공통부 구현 + foundation-manifest.md 산출
→ decomposing-ko: 재사용 HARD GATE 활성
→ 이후 /start <기능> 시 각 task 가 재사용 선언 의무화
```

## 안티패턴

- **화면 단위 구현 요구** — `/start-foundation` 은 인프라·공통부 전용. 화면 단위 기능은 foundation 완료 후 `/start` 로 진행
- **specifying-ko 생략** — 공통부라도 spec → clarify → plan → decompose 체인 필수. 직접 구현 금지
- **`/start-project` 대체** — `/start-foundation` 은 foundation 코드 생성 전용. 프로젝트 문서 부트스트랩은 `/start-project` 담당

## 참조

- `skills/specifying-ko/SKILL.md` — foundation 분기 처리 (Step 5.5 skip, §유형=foundation)
- `skills/clarifying-ko/SKILL.md` — 기술스택 BLOCKING 게이트
- `skills/planning-ko/SKILL.md` — foundation-manifest.md 산출 지시
- `skills/decomposing-ko/SKILL.md` — 재사용 HARD GATE 조건
- `templates/foundation-manifest.md` — manifest 템플릿
- `commands/start.md` — 기능 단위 구현 진입 슬래시 (미러링 패턴 참조)
