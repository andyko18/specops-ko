<!-- FID: 20260425-slug-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# 한국어/영문 URL Slug 변환 CLI 명세 — 20260425-slug-cli

## 0. specops 메타

| 필드 | 값 |
|---|---|
| **mode** | Standard |
| **결정 근거** | specifying-ko 자연어 분석 — "bash CLI 만들기", 위험 키워드 없음 |
| **override 경로** | 없음 |

## 1. 개요

**목적**: 한국어/영문 혼합 문자열을 URL에서 사용 가능한 slug 문자열로 변환한다.

**배경**: specops-auto-ko 프로젝트의 스크립트 도구로, 한글 문자열을 포함한 제목·태그를 URL 친화적 slug로 변환할 필요가 있다. 외부 의존성 없이 bash만으로 동작해야 한다.

**성공 판정**: `slug.sh "안녕 World 2024"` 실행 시 `annyeong-world-2024`가 출력되면 완성.

## 2. 범위

### 포함
- 한글 음절(U+AC00~U+D7A3) → 국립국어원 개정 로마자 표기법 고정 매핑 (위치 의존 연음 규칙 제외)
- 영문 대문자 → 소문자
- 숫자 → 그대로 유지
- 공백·특수문자 → `-` 치환
- 연속 `-` → 하나로 축약
- 앞뒤 `-` 제거
- stdin 또는 첫 번째 인자(`$1`) 입력 모두 지원
- `--help` 플래그로 사용법 출력

### 제외 (YAGNI)
- 위치 의존 연음 규칙 (이어지는 자음 변환 등 — URL slug 목적으로 불필요)
- 한자·일본어 등 기타 비ASCII 문자 (단순 `-` 치환)
- 다중 파일 입력 (`-f` 플래그)
- 최대 길이 truncation 옵션
- 구분자 커스터마이징 (`--separator` 플래그)

## 3. 사용자 시나리오

### 주요 시나리오
**사용자**: specops-auto-ko 사용 개발자  
**상황**: 한글 포함 문자열을 FID·파일명·URL 경로로 사용하고 싶음  
**행동**: `scripts/slug.sh "안녕 World 2024"` 실행  
**기대 결과**: `annyeong-world-2024` 출력

### 보조 시나리오
**상황**: 파이프라인에서 사용  
**행동**: `echo "Hello 세계" | scripts/slug.sh`  
**기대 결과**: `hello-segye` 출력

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | 한글 음절을 국립국어원 개정 로마자 표기법 고정 매핑으로 변환한다 | must |
| FR-2 | 영문 대문자를 소문자로 변환한다 | must |
| FR-3 | 공백 및 특수문자를 `-`로 치환한다 | must |
| FR-4 | 연속 `-`를 하나로 축약하고 앞뒤 `-`를 제거한다 | must |
| FR-5 | 첫 번째 인자(`$1`) 또는 stdin 중 하나로 입력받는다 | must |
| FR-6 | `--help` 플래그 실행 시 사용법을 출력하고 exit 0한다 | should |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 성능 | 100자 입력 기준 ≤ 1초 |
| NFR-2 | 호환성 | bash 3.2+ (macOS 실측 예정 · Linux 미검증) |
| NFR-3 | 의존성 | POSIX 표준 유틸리티(`od`, `tr`, `cat`) 외 비표준 외부 바이너리 사용 금지 |

## 6. 제약사항

- 기술 스택: bash + POSIX 표준 유틸리티
- 의존성: POSIX `od`, `tr`, `cat` (macOS/Linux 기본 탑재)
- 위치: `scripts/slug.sh` (기존 프로젝트 scripts/ 컨벤션 준수)
- 테스트: `scripts/tests/test_slug.sh` (기존 bash 테스트 컨벤션 준수)

## 7. 가정 (5원칙 5번 — 한계 고백)

- bash 3.2 환경에서 `od -An -tu1` 동작함 (macOS 실측 예정)
- 한글 음절 범위 외 유니코드(이모지, CJK 등)는 `-` 치환으로 충분
- 위치 의존 연음 규칙 미적용이 URL slug 품질에 충분함

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항.

- Q1: 숫자만으로 구성된 slug 허용 여부 (`"2024"` → `"2024"` vs 오류)
- Q2: 빈 입력 처리 — 빈 문자열 출력 후 exit 0 vs exit 1

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- `scripts/tests/` — 기존 bash 테스트 파일 패턴
- `templates/test-conventions-bash.md` — bash 테스트 컨벤션
- 국립국어원 개정 로마자 표기법 (국립국어원 공식 문서 참조)

---

*작성: kohaedong · 2026-04-25 · FID: 20260425-slug-cli · 생성 커맨드: /start*
