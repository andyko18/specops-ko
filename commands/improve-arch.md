---
name: improve-arch
description: 코드베이스 아키텍처 분석 슬래시 — improve-codebase-architecture-ko 호출. deep module 원칙 기준 split/merge 권고안 제시.
triggers:
  - "/improve-arch"
mode: ask
specops_version: 1.0.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-auto-ko 독자 추가 (mattpocock improve-codebase-architecture 한국어 재창작)
---

# /improve-arch [<경로>]

## 목적

코드베이스 파일/모듈 경계를 정적 분석해 deep module 원칙 위반(책임 과부하·과잉 분해)을 탐지하고 split/merge 권고안을 제시한다.

## Process

1. **즉시 `specops-auto-ko:improve-codebase-architecture-ko` 호출** — 전달된 `<경로>`를 분석 대상으로 제공
2. 4단계 정적 분석 진행 (find + wc + grep)
3. 권고안 stdout 출력
4. 필요 시 `/maintain <파일>` 진입 안내

## 사용 예

```
/improve-arch src/

→ improve-codebase-architecture-ko 호출
→ src/ 내 소스 파일 스캔 (.ts .js .py .sh .go)
→ split/merge 권고 테이블 출력
```

```
/improve-arch
(인자 없음 — 현재 디렉토리)
```

## 안티패턴

- **리팩터링 직접 실행** — 본 슬래시는 분석만. 변경은 `/maintain <파일>` 진입
- **대용량 프로젝트 전체 스캔** — 필요한 하위 경로만 지정 권장

## 참조

- `skills/improve-codebase-architecture-ko/SKILL.md` — 실행 skill
- John Ousterhout "A Philosophy of Software Design" — deep module 원칙

---

*specops-auto-ko v1.0.0 · 2026-05-19 · mattpocock improve-codebase-architecture 한국어 재창작*
