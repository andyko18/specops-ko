# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

<PRD §1 한 줄 설명 자동 인용 — `/init-project` Phase 5 가 채움>

## specops-ko 사용

본 프로젝트는 specops-ko 한국어 자율 Lifecycle 플러그인을 사용합니다.

- **신규 기능**: `/start "<기능 설명>"`
- **유지보수**: `/maintain "<대상>"`
- **프로젝트 부트스트랩**: `/init-project [<프로젝트명>]` (이미 실행됨)
- **산출물**: `.specops/<FID>/` (기능별 lifecycle 산출물)

## 테스트 명령

<!-- 사용자가 채움. 예: -->

```bash
# npm test
# pytest
# bash scripts/tests/test-*.sh
```

## 코딩 컨벤션

<constitution.md §원칙 5개 자동 요약 인용 — `/init-project` Phase 5 가 채움>

- 원칙 1: <원칙 1 이름 — 1줄 요약>
- 원칙 2: <원칙 2 이름 — 1줄 요약>
- 원칙 3: <원칙 3 이름 — 1줄 요약>
- 원칙 4: <원칙 4 이름 — 1줄 요약>
- 원칙 5: <원칙 5 이름 — 1줄 요약>

상세: `.specops/memory/constitution.md`

## 아키텍처

`.specops/memory/*` 산출물 자동 인덱스 — `/init-project` Phase 5 가 활성 산출물만 채움:

- 헌법: `.specops/memory/constitution.md`
- 요구사항 마스터: `.specops/memory/requirements.md`
- 전체 아키텍처: `.specops/memory/architecture.md`
- 프론트 아키텍처: `.specops/memory/frontend-architecture.md` (UI/풀스택/모바일)
- 백엔드 아키텍처: `.specops/memory/backend-architecture.md` (BE/풀스택만)
- IF 설계서: `.specops/memory/api-spec.md` (BE/풀스택만)
- 소비 IF: `.specops/memory/api-spec-consumer.md` (UI·모바일: Phase 8g에서 y 선택 시)
- 테이블 설계서: `.specops/memory/data-model.md` (DB 사용 시)
- 화면 목록: `.specops/memory/screens-overview.md` (UI/풀스택/모바일)
- 테스트 전략: `.specops/memory/test-strategy.md`
- 프로젝트 컨텍스트: `.specops/memory/project-context.md`
- 결정 원장: `.specops/memory/decisions.md`

UI 프로젝트인 경우:
- 디자인 시스템: `DESIGN.md`
- 화면 목록: `.specops/memory/screens-overview.md` (상세 `screens/` 는 `/start-all` Phase 2.5 또는 `/design-screen`)

## 작업 흐름

1. **새 기능**: `/start "<기능>"` → spec → clarify → plan → decompose → implement → verify → review
2. **버그/리팩터**: `/maintain "<대상>"` → analyzing-ko → spec → ... (chain)
3. **검증**: `bash scripts/tests/test-*.sh` 또는 `<TEST_COMMAND>`

---

*생성: /init-project (Phase 5) · `.specops/memory/*` 인덱스 자동 갱신*
