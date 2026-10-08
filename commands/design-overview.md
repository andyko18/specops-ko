---
name: design-overview
disable-model-invocation: true
description: 설계 통합 뷰 — /init-project 산출 설계 문서를 읽기 전용 HTML 한 장으로 묶는다 (시스템 구성도·프로세스 흐름·ERD 그림 · 추적표 · 미확정/가정 목록)
triggers:
  - "/design-overview"
mode: ask
specops_version: 2.10.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-ko 독자 추가
---

# /design-overview [--check]

## 목적

`/init-project` 가 만든 설계 문서는 루트와 `.specops/memory/` 에 흩어져 있다. 사람이 전체 설계를 한 번에 훑을 수 있도록 **읽기 전용 HTML 한 장**(`.specops/design-overview.html`)으로 묶는다.

- **한눈에 보기** — 문서·요구·프로세스·미확정·가정 개수
- **시스템 구성도** — `architecture.md` 의 다이어그램(없으면 §2 통신 표)을 그림으로
- **업무 프로세스 흐름** — `process-design.md` 의 프로세스마다 트리거 → 행위자 → 화면 → API → 테이블 → 결과, 예외
- **추적표** — 프로세스 ↔ 요구(FR) ↔ 화면 ↔ API ↔ 테이블. 어느 프로세스에도 연결되지 않은 요구를 따로 알린다
- **결정이 필요한 항목** — 전 문서의 `<미확정 …>`·`<TODO …>`·`가정:` 을 한 표로
- **문서 본문** — 각 문서 전문(표·목록·코드·ERD 그림), 왼쪽 목차

## 원칙

- **원본은 계속 마크다운이다.** 이 HTML 은 생성물이고 lifecycle 은 읽지 않는다. 고칠 때는 `.md` 를 고치고 다시 생성한다 — HTML 을 직접 고치지 않는다.
- **LLM 이 쓰지 않는다.** 스크립트가 `.md` 를 그대로 변환한다 — 옮기다 내용이 달라질 일이 없고 토큰도 들지 않는다.
- **외부 리소스 0** — CDN 스크립트·폰트·이미지를 참조하지 않는다. 폐쇄망에서 파일만 열어도 보인다. 의존은 `python3` 표준 라이브러리뿐.
- **기본은 로컬** — 새로 init 한 프로젝트는 `.specops/.gitignore` 가 이 파일을 무시한다. 공유하려면 파일을 직접 전달한다. **설계 문서에 내부 URL·계정 정보가 있으면 그대로 실린다** — 전달 전에 확인한다.

## Process

1. 생성:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}"/scripts/design-overview.sh
   ```
   출력 1줄(`DESIGN-OVERVIEW: <경로> (문서 N개 · 지문 …)`)의 경로를 사용자에게 알린다. 설계 문서가 없으면 rc 2 — `/init-project` 를 먼저 안내한다.
2. `--check` — 생성하지 않고 기존 HTML 이 원본과 같은 지문인지만 본다:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}"/scripts/design-overview.sh --check
   ```
   `FRESH`(rc 0) · `STALE`/`MISSING`(rc 1 — 다시 생성).

## 한계

- 그림은 문서가 담은 mermaid 의 부분집합(`graph TD|LR`·`erDiagram`)만 그린다. 그 밖의 문법(sequence·state 등)은 **원문 코드 그대로** 보여 준다 — 틀린 그림을 그리지 않는다.
- 자동 배치라 노드가 많으면 선이 겹칠 수 있다. 그림 아래 "원문(mermaid)" 을 펼치면 원본을 볼 수 있다.
- 채우지 않은 골격(`<프로세스명>` 등)은 프로세스로 세지 않는다. 미확정 목록은 `<미확정 …>`·`<TODO …>`·`가정:` 표기만 모은다(일반 placeholder 판정은 `scan-enrich-placeholders.sh` 소관).
- 낡음은 자동으로 알리지 않는다 — `--check` 로 확인한다.

## 참조

- `scripts/design-overview.sh` — 진입 스크립트
- `scripts/_internal/design-overview/` — 변환기(`md.py`)·그림(`diagrams.py`)·조립(`build.py`)
- `commands/init-project.md` — 부트스트랩 종결 뒤 자동 생성

---

*specops-ko v2.10.0 · 2026-10-08 · 설계 통합 뷰(읽기 전용 생성물)*
