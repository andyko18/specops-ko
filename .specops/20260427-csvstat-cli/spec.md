<!-- FID: 20260427-csvstat-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# csvstat CLI + Python 지원 인프라 명세 — 20260427-csvstat-cli

## 1. 개요

**목적**: specops-auto-ko Lifecycle을 Python 프로젝트에 적용 가능하게 하고, `csvstat.py` CSV 통계 CLI로 실검증한다.

**배경**: 현재 `decomposing-ko` HARD-GATE와 `templates/test-conventions-bash.md`가 bash 전용으로 하드코딩되어 있어, Python 프로젝트를 Lifecycle으로 dogfood하면 shebang·exec-bit 검증에서 차단된다. `test-conventions-python.md` 신규 추가 + HARD-GATE 언어 분기로 이를 해소하고, CSV 통계 CLI(`csvstat.py`)를 7th dogfood 대상으로 삼아 실검증한다.

**성공 판정**: pytest로 `csvstat.py`를 테스트하는 전체 Lifecycle(spec→plan→decompose→implement→verify→review)이 FAIL 없이 완주된다.

## 2. 범위

### 포함

#### Layer 1 — 플러그인 인프라 (독립 — 병렬 구현 가능)
- `templates/test-conventions-python.md` 신규 생성 — pytest 4항목 규약
- `skills/decomposing-ko/SKILL.md` 수정 — HARD-GATE 언어 분기 및 Python 테스트 컨벤션 표 추가

#### Layer 2 — 7th dogfood (의존: Layer 1)
- `examples/scripts/csvstat.py` 신규 생성 — CSV 통계 CLI (stdlib `csv` 모듈만 사용)
- `examples/tests/test_csvstat.py` 신규 생성 — pytest 테스트

### 제외 (YAGNI)
- pandas 또는 외부 라이브러리 의존
- Node.js 테스트 컨벤션 (별도 FID)
- CSV 필터링·집계 연산 (단순 통계만)
- `--json` 출력 플래그

## 3. 사용자 시나리오

### 주요 시나리오 — 파일 인자
**사용자**: CLI 개발자
**상황**: CSV 파일의 구조를 빠르게 파악하고 싶음
**행동**: `csvstat.py data.csv`
**기대 결과**: 행 수, 컬럼 수, 각 컬럼의 unique 값 수가 stdout에 출력됨

### 보조 시나리오 — stdin
**행동**: `cat data.csv | csvstat.py`
**기대 결과**: 동일 출력

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | csvstat.py가 파일 인자로 CSV를 받아 통계를 stdout에 출력한다 | must |
| FR-2 | csvstat.py가 stdin으로 CSV를 받아 통계를 stdout에 출력한다 | must |
| FR-3 | 존재하지 않는 파일 인자 시 stderr에 usage + exit 1 | must |
| FR-4 | 인자·stdin 없음(터미널 stdin) 시 stderr에 usage + exit 1 | must |
| FR-5 | 출력 포맷: `rows: N`, `columns: N`, 각 컬럼별 `<name>: N unique` | must |
| FR-6 | `templates/test-conventions-python.md`가 pytest 4항목 규약을 문서화한다 | must |
| FR-7 | decomposing-ko HARD-GATE가 `.py` 테스트 파일을 Python 규약으로 검증한다 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 언어 | Python 3.6+ (macOS 실측 미확인 정확 버전) |
| NFR-2 | 의존성 | stdlib만 (`csv`, `sys`, `os` 모듈) |
| NFR-3 | 테스트 프레임워크 | pytest (pip install pytest 필요) |
| NFR-4 | exec-bit | `csvstat.py` 스크립트 본체에 `chmod +x` + `#!/usr/bin/env python3` shebang |

## 6. 제약사항

- 기술 스택: Python 3, pytest
- 의존성: stdlib only (no pandas, no numpy)
- 기존 인터페이스: `examples/scripts/` + `examples/tests/` 디렉토리 패턴 유지
- decomposing-ko 변경 시 기존 bash 프로젝트 HARD-GATE 동작 불변 (회귀 없음)

## 7. 가정

- python3가 PATH에 있다 (실측: cvt.py 동작 확인됨)
- pytest가 설치되어 있다 (혹은 `pip install pytest`로 설치 가능)
- csvstat.py의 출력 첫 행은 항상 `rows: N`

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항.

- Q1: `csvstat.py` 빈 CSV(헤더만) 입력 시 동작? → `rows: 0` + `columns: N` + 각 컬럼 `0 unique`? exit 0?
- Q2: 헤더 없는 CSV(첫 행이 데이터) 처리? → 첫 행을 헤더로 간주

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- 선행 dogfood: `.specops/20260426-b64-cli/` (6th dogfood 패턴)
- Python 예시: `examples/scripts/cvt.py`
- 기존 bash 컨벤션: `templates/test-conventions-bash.md`

---

*작성: kohaedong · 2026-04-27 · FID: 20260427-csvstat-cli · 생성 커맨드: /specify*
