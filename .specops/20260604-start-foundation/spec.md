<!-- FID: 20260604-start-foundation -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# `/start-foundation` 슬래시 커맨드 신설 명세 — 20260604-start-foundation

## 1. 개요

**§유형**: 신규

**목적**: specops-auto-ko 에 `/start-foundation` 슬래시 커맨드를 추가해, per-feature `/start` 사이클 이전에 실행 가능한 공통부 코드(라우팅·레이아웃·인증·공통 컴포넌트·DB 마이그레이션)를 생성하는 한국 SI 표준 "공통부 먼저 개발" 단계를 지원한다.

**배경**: 현재 specops-auto-ko 는 `/start-project`(13개 문서만 산출, L52 doc-only 계약) → `/start`(화면 단위 per-feature 구현)로 바로 진입한다. 공통부(라우팅·인증·레이아웃·DB 스키마) 없이 기능마다 인프라를 재구현하는 낭비가 발생한다. 계획 게이트(중간) 강도로 재사용을 강제한다.

**성공 판정**: `/start-foundation` 실행 후 공통부 코드가 생성되고, 이후 `/start` 기능 task 들이 `foundation-manifest.md` 를 참조해 재사용 선언 또는 미재사용 근거를 의무 기재한다.

## 2. 범위

### 포함
- `commands/start-foundation.md` 신규 — `/start-foundation [<공통부 설명>]` 슬래시 진입점 (독립 — 병렬 구현 가능)
- `templates/foundation-manifest.md` 신규 — 공통부 제공 모듈 목록 표 템플릿 (독립 — 병렬 구현 가능)
- `scripts/_internal/.structure-baseline` 수정 — commands 8→9, templates 26→27 (독립 — 병렬 구현 가능)
- `skills/specifying-ko/SKILL.md` 수정 — `<!-- entry: foundation -->` 분기 추가, Step 5.5 화면 루프 skip, §유형 라벨 `foundation` 신설 (독립 — 병렬 구현 가능)
- `skills/clarifying-ko/SKILL.md` 수정 — §유형=foundation 시 기술스택 BLOCKING 게이트 추가 (독립 — 병렬 구현 가능)
- `skills/planning-ko/SKILL.md` 수정 — foundation 산출 후 `foundation-manifest.md` 작성 지시 추가 (독립 — 병렬 구현 가능)
- `skills/decomposing-ko/SKILL.md` 수정 — `foundation-manifest.md` 존재 시 기능 task 재사용 선언 HARD GATE 추가 (독립 — 병렬 구현 가능)

### 제외 (YAGNI)
- 거버넌스 R-7 신규 규칙 (계획 게이트 선택 — R-7 과중)
- scaffold boilerplate 자동 생성 템플릿 라이브러리 (implementing-ko 가 spec 기반 생성)
- `/start-project` Phase 추가/수정 (L52 doc-only 계약 보존)
- foundation spec 전용 신규 engine skill (기존 lifecycle 분기로 처리)

## 3. 사용자 시나리오

### 주요 시나리오 — 프로젝트 공통부 구축
**사용자**: specops-auto-ko 를 사용하는 개발자 (웹앱 프로젝트 시작)
**상황**: `/start-project` 로 문서 부트스트랩 완료 후, 공통부 코드가 없는 상태
**행동**: `/start-foundation React 기반 SPA 공통부 — 라우팅, 인증, 레이아웃, API 클라이언트`
**기대 결과**: specifying-ko 가 foundation 분기로 진입 → 기술스택 BLOCKING 확정 → 공통부 구현 → `foundation-manifest.md` 산출 → 이후 `/start 로그인 기능` 시 task 마다 재사용 선언 의무화

### 보조 시나리오 — 재사용 게이트 동작
**사용자**: 동일 개발자
**상황**: foundation 완료 후 `/start` 로 개별 기능 구현
**행동**: decomposing-ko 가 기능 tasks.md 생성
**기대 결과**: 각 task 에 `**재사용 foundation**: <모듈>` 또는 `**미재사용 근거**: <사유>` 필드가 없으면 HARD GATE 차단

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `/start-foundation` 슬래시 실행 시 specifying-ko 를 `<!-- entry: foundation -->` 마커와 함께 호출한다 | must |
| FR-2 | specifying-ko 는 `<!-- entry: foundation -->` 감지 시 foundation 분기로 진입하고 Step 5.5 화면 루프를 skip 한다 | must |
| FR-3 | clarifying-ko 는 spec.md §유형=`foundation` 이고 `frontend-architecture.md` / `backend-architecture.md` 에 미해소 placeholder(`<...>`) 가 있으면 기술 프레임워크를 BLOCKING 질문으로 강제한다 | must |
| FR-4 | planning-ko 는 foundation 구현 완료 후 `.specops/memory/foundation-manifest.md` 를 산출한다 | must |
| FR-5 | decomposing-ko 는 spec.md §유형이 `foundation` 이 아니고 `foundation-manifest.md` 가 존재하면, 각 task 에 `**재사용 foundation**` 또는 `**미재사용 근거**` 필드 누락 시 HARD GATE 차단한다 | must |
| FR-6 | `commands/start-foundation.md` 신규 파일 추가 후 `validate-structure.sh` 가 PASS 한다 | must |
| FR-7 | 기존 governance·DAG 테스트가 회귀 없이 PASS 한다 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 기존 lifecycle 호환성 | `<!-- entry: foundation -->` 마커 없는 일반 `/start` 진입은 기존 동작 그대로 |
| NFR-2 | graceful skip | `.specops/memory/` 부재 프로젝트에서도 foundation 분기 정상 동작 (memory 인용 없이 진행) |
| NFR-3 | 외과적 변경 | 기존 SKILL.md 의 `reference_upstream` frontmatter 포맷 불변 |
| NFR-4 | 파일 유형 | bash 3.2+ (macOS 실측 · 신규 bash 스크립트 없음 — md 편집만) |

## 6. 제약사항

- 기술 스택: bash, markdown (신규 코드 없음 — 기존 SKILL.md/command 편집 + 신규 md 파일 2개)
- 의존성: 기존 specops-auto-ko lifecycle chain (specifying-ko → clarifying-ko → planning-ko → decomposing-ko)
- 호환성: `validate-structure.sh` `.structure-baseline` 카운트 동기화 필수 (commands 8→9, templates 26→27)
- `/start-project` L52 doc-only 계약 불변 — start-project.md 수정 금지

## 7. 가정

- `<!-- entry: foundation -->` 마커 idiom 은 기존 `<!-- entry: maintain -->` 와 동일 방식으로 specifying-ko 가 args 첫 줄에서 감지한다고 가정
- `foundation-manifest.md` 는 `.specops/memory/` 경로에 산출된다 (기존 memory 산출물과 동일 위치)
- decomposing-ko HARD GATE 는 spec.md §유형 라벨을 실시간으로 읽는 것이 아니라, task 작성 시 사용자/에이전트가 §유형을 인식해 적용한다고 가정

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항:

- Q1: `foundation-manifest.md` 가 없는 신규 프로젝트에서 기능 task 가 HARD GATE 를 만날 일이 없는가? (foundation 미사용 프로젝트 graceful skip 조건)

## 9. Advisor 협의 기록

| 일시 | 질의 요지 | advisor 권고 | 채택 여부 | 반영 위치 |
|---|---|---|---|---|
| 2026-06-04 | `/start-foundation` 독립 command vs `/start-project` phase 추가 가능 여부 | `/start-project` L52 doc-only 계약이 phase 추가를 잠금 — 독립 command 가 유일한 안전한 경로 | 채택 | §6 제약사항 |
| 2026-06-04 | 재사용 강제 강도: R-7 거버넌스 vs 계획 게이트 vs 인용만 | 계획 게이트(중간)가 "진짜 보장" 충족하면서 거버넌스 엔진 무수정 — 권장 | 채택 (사용자 확정) | §4 FR-5 |

## 10. 참조

- `commands/start.md` — 기존 진입 슬래시 (미러링 패턴)
- `commands/start-project.md` — L52 doc-only 계약 (Phase 추가 금지 근거)
- `skills/specifying-ko/SKILL.md` — foundation 분기 추가 대상
- `skills/clarifying-ko/SKILL.md` — BLOCKING 게이트 추가 대상
- `skills/planning-ko/SKILL.md` — manifest 산출 지시 추가 대상
- `skills/decomposing-ko/SKILL.md` — HARD GATE 조건 추가 대상
- `scripts/_internal/.structure-baseline` — 카운트 갱신 대상
- `DESIGN.md` — 디자인 시스템 준수

---

*작성: specops-auto-ko · 2026-06-04 · FID: 20260604-start-foundation · 생성 커맨드: /specify*
