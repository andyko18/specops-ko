<!-- FID: 20260426-b64-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# Base64 CLI 3종 명세 — 20260426-b64-cli

## 1. 개요

**목적**: Base64 인코딩·디코딩·검증을 각각 독립된 bash CLI로 제공한다.

**배경**: 파이프라인에서 Base64 변환·검증을 외부 도구 없이 프로젝트 내 스크립트로 처리하고 싶다. 기존 `slug.sh` · `cvt.py`와 동일한 scripts/ 컨벤션을 따른다.

**성공 판정**: 3종 CLI가 각각 독립 파일로 존재하고, 인자+stdin 입력·한 줄 출력·패딩 검증이 모두 동작하면 완성이다.

## 2. 범위

### 포함
- `b64enc.sh` — Base64 인코딩 (인자 또는 stdin, 줄바꿈 없는 단일 줄 출력)
- `b64dec.sh` — Base64 디코딩 (인자 또는 stdin, macOS/Linux 자동 감지)
- `b64val.sh` — Base64 문자셋 + 패딩 규칙 검증 (인자 또는 stdin)
- 각 CLI 단위 테스트 (`scripts/tests/test-b64*.sh`)

### 제외 (YAGNI)
- URL-safe Base64 (`-` `_` 변형)
- Base64 스트림 처리 (대용량 파일 청크)
- `--wrap` 줄바꿈 옵션
- 파일 직접 지정 (`-f` 플래그)

## 3. 사용자 시나리오

### 주요 시나리오 — 인코딩
**사용자**: CLI 개발자  
**상황**: 문자열을 Base64로 인코딩해 파이프라인에 전달하려 한다  
**행동**: `b64enc.sh "hello"` 또는 `echo -n "hello" | b64enc.sh`  
**기대 결과**: `aGVsbG8=` 한 줄 출력 (`echo -n` 기준 — `echo`는 `\n` 포함으로 결과가 다름)

### 보조 시나리오 — 디코딩
**사용자**: CLI 개발자  
**상황**: Base64 문자열을 원문으로 복원하려 한다  
**행동**: `b64dec.sh "aGVsbG8="` 또는 `echo "aGVsbG8=" | b64dec.sh`  
**기대 결과**: `hello` 출력

### 보조 시나리오 — 검증
**사용자**: CLI 개발자  
**상황**: 입력값이 유효한 Base64인지 판단하려 한다  
**행동**: `b64val.sh "aGVsbG8="` 또는 `echo "invalid!" | b64val.sh`  
**기대 결과**: 유효 시 `valid` + exit 0, 무효 시 `invalid: <이유>` + exit 1

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | b64enc.sh: 인자 있으면 인자, 없으면 stdin을 Base64 인코딩해 줄바꿈 없는 단일 줄로 출력 | must |
| FR-2 | b64enc.sh: 인자도 stdin도 없으면 usage 출력 후 exit 1 | must |
| FR-3 | b64dec.sh: 인자 있으면 인자, 없으면 stdin을 Base64 디코딩해 출력 | must |
| FR-4 | b64dec.sh: macOS(`base64 -D`)와 Linux(`base64 -d`) 자동 감지 | must |
| FR-5 | b64dec.sh: 디코딩 실패 시 stderr에 에러 메시지 출력 후 exit 1 | must |
| FR-6 | b64val.sh: 인자 있으면 인자, 없으면 stdin을 검증 | must |
| FR-7 | b64val.sh: 허용 문자셋(`[A-Za-z0-9+/=]`) 검사 | must |
| FR-8 | b64val.sh: 패딩 규칙 검사 — 길이 4의 배수, `=`는 끝에만 (최대 2개) | must |
| FR-9 | b64val.sh: 유효 시 `valid` stdout + exit 0, 무효 시 `invalid: <이유>` stdout + exit 1 | must |
| FR-10 | 3종 CLI는 서로 `source` 또는 `import` 없이 완전 독립 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 호환성 | bash 3.2+ (macOS 실측 · Linux 미검증) |
| NFR-2 | 외부 의존 | `base64` 명령 (macOS/Linux 기본 탑재) |
| NFR-3 | 독립성 | 3종 파일 간 상호 의존 없음 |

## 6. 제약사항

- 기술 스택: bash
- 의존성: `base64` 시스템 명령 (macOS/Linux 기본 탑재)
- 호환성: 기존 `scripts/` 컨벤션 준수 (`#!/usr/bin/env bash`, `set -u`)

## 7. 가정 (5원칙 5번 — 한계 고백)

- `base64` 명령이 실행 환경에 존재한다고 가정 (미설치 환경 미처리)
- macOS/Linux 이외 OS(Windows WSL 등)는 검증 범위 외

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항.

- Q1: 빈 문자열 입력 시 인코더/검증기 동작 — 유효 처리 vs 에러?
- Q2: 검증기에서 줄바꿈 문자(`\n`) 포함된 입력 처리 방식?

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- 기존 CLI 패턴: `scripts/slug.sh`
- 관련 FID: `20260426-cvt-cli` (Python 변환 CLI)

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-b64-cli · 생성 커맨드: /specify*
