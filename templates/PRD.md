<!-- OWNER_COMMAND: /start-project -->
<!-- layer: Project-Document -->

# <PROJECT_NAME> PRD

> Product Requirements Document — 프로젝트 전체 비전·목표·페르소나·마일스톤. `/start-project` Phase 4 가 1회 생성.
> 이후 기능별 spec.md 가 본 PRD 의 §4 마일스톤을 분해.

## 1. 프로젝트 개요

**한 줄 설명**: <한 줄 — `/start-project` Q1 입력값>

**목적**: <2~3 문장 — 이 프로젝트가 해결하는 문제>

**성공 판정**: <한 문장 — 무엇이 되면 "성공"인가>

## 2. 대상 사용자 / 페르소나

**주요 페르소나**: <`/start-project` Q2 입력값 — 1~2 문장>

**부차적 페르소나** (선택): <필요 시 추가>

## 3. 핵심 가치제안

`/start-project` Q3 입력값 — 3 개:

- <가치 1>
- <가치 2>
- <가치 3>

## 4. 핵심 기능 (마일스톤 단위)

각 마일스톤이 1~N 개의 `.specops/<FID>/spec.md` 로 분해됨:

- **M1**: <`/start-project` Q5 입력값 — 첫 마일스톤 한 줄>
- **M2**: <Q6 입력값>
- **M3**: <Q7 입력값>

## 5. 비기능 요구사항 (전사)

placeholder — `.specops/memory/requirements.md` §3 NFR 표가 상세화:

- 성능: <TODO — 응답시간·처리량>
- 가용성: <TODO — SLA>
- 보안: <TODO — 인증·암호화>
- 접근성: <TODO — WCAG 등급>
- 호환성: <TODO — 브라우저·OS·언어>

## 6. 제외 범위 (YAGNI)

명시적으로 하지 않을 것:

- <TODO 1>
- <TODO 2>

## 7. 기술 스택

- 언어/런타임: <TODO>
- 프레임워크: <TODO — `.specops/memory/architecture.md` 참조>
- 인프라: <TODO — 배포·DB·MQ>

## 8. 참조

- **헌법**: `.specops/memory/constitution.md` — 프로젝트 불변 원칙
- **요구사항 마스터**: `.specops/memory/requirements.md` — FR/NFR 표
- **전체 아키텍처**: `.specops/memory/architecture.md`
- **기능별 spec**: `.specops/<FID>/spec.md`
- **디자인 시스템**: `DESIGN.md` (UI 프로젝트만)
- **Claude Code 가이드**: `CLAUDE.md`

---

*작성: <작성자> · <YYYY-MM-DD> · 생성: /start-project (Phase 4)*
