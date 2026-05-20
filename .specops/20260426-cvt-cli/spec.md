<!-- FID: 20260426-cvt-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# cvt — JSON ↔ YAML 양방향 변환 CLI 명세 — 20260426-cvt-cli

## 1. 개요

**목적**: JSON과 YAML 사이를 stdin/stdout 파이프로 양방향 변환하고, 구문 유효성을 검증한다.

**배경**: 개발 환경에서 JSON↔YAML 변환은 반복적으로 필요하지만 범용 CLI 도구가 없어 매번 스크립트를 작성하거나 온라인 도구에 의존한다. specops-auto-ko dogfood 2번째 CLI로 3단계 파이프라인 패턴을 검증한다.

**성공 판정**: `cvt --to yaml input.json`과 `cat input.yaml | cvt --to json`이 정확히 변환되고, 잘못된 입력에 대해 명확한 에러 메시지와 비정상 종료 코드를 반환하면 완성.

## 2. 범위

### 포함
- JSON → YAML 변환
- YAML → JSON 변환
- stdin 파이프 입력 지원
- 파일 인자 입력 지원
- 구문 유효성 검증 (파싱 성공 여부)
- `--indent N` 플래그 (JSON 출력 들여쓰기)
- 에러 시 stderr + exit 1/2

### 제외 (YAGNI)
- JSON Schema / 사용자 정의 스키마 검증
- TOML 포맷 지원
- 다중 파일 배치 변환
- 파일 출력 (`-o output.yaml`)
- 컬러 출력

## 3. 사용자 시나리오

### 주요 시나리오
**사용자**: 개발자
**상황**: API 응답 JSON을 YAML 설정 파일로 변환해야 함
**행동**: `cat response.json | cvt --to yaml > config.yaml`
**기대 결과**: config.yaml에 올바른 YAML이 기록됨, exit 0

### 보조 시나리오
**상황**: CI에서 YAML 설정을 JSON으로 변환해 jq로 처리
**행동**: `cvt --to json config.yaml | jq '.key'`
**기대 결과**: JSON stdout이 jq로 파이프됨

### 에러 시나리오
**상황**: 깨진 JSON 파일 입력
**행동**: `cvt --to yaml bad.json`
**기대 결과**: stderr에 `ParseError: <원인>`, exit 1

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `--to yaml` 플래그로 JSON 입력을 YAML로 변환한다 | must |
| FR-2 | `--to json` 플래그로 YAML 입력을 JSON으로 변환한다 | must |
| FR-3 | stdin 파이프 및 파일 인자 양쪽에서 입력을 받는다 | must |
| FR-4 | 파싱 실패 시 stderr에 `ParseError: <원인>` 출력 + exit 1 | must |
| FR-5 | `--to` 플래그 누락 시 usage 출력 + exit 2 | must |
| FR-6 | `--indent N` 플래그로 JSON 출력 들여쓰기를 설정한다 (기본 2) | should |
| FR-7 | 정상 변환 결과는 stdout에만, stderr는 비워둔다 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 성능 | 변환 응답 ≤ 200ms (1MB 이하 입력 기준 · 실측 미확인) |
| NFR-2 | 호환성 | Python 3.8+ (실측 미확인) · bash 3.2+ (macOS 실측) |
| NFR-3 | 의존성 | python3 표준 설치 + pyyaml (`pip install pyyaml`) |
| NFR-4 | 실행 권한 | cvt.py exec-bit 755 |

## 6. 제약사항

- 기술 스택: Python 3, bash (테스트 스크립트)
- 의존성: PyYAML (`pyyaml`)
- 호환성: Unix 파이프 (stdin/stdout) 준수

## 7. 가정 (5원칙 5번 — 한계 고백)

- PyYAML이 실행 환경에 설치돼 있다고 가정 (설치 미확인 시 에러 메시지 별도 처리 없음)
- 입력 인코딩은 UTF-8로 가정
- 1MB 이하 입력 기준 NFR-1 성능 — 대용량 스트리밍은 미검증

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항.

- Q1: PyYAML 미설치 시 에러 메시지를 별도로 안내할 것인가, 아니면 Python ImportError 그대로 노출할 것인가?
- Q2: YAML 다중 문서 (`---` 구분자 복수) 입력 시 동작을 정의할 것인가?

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- FID: `20260425-slug-cli` — dogfood 선행 사례 (bash CLI)
- 템플릿: `templates/spec.md`

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-cvt-cli · 생성 커맨드: /specify*
