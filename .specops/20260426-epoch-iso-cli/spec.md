<!-- FID: 20260426-epoch-iso-cli -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# epoch ↔ ISO 8601 양방향 변환 CLI 명세 — 20260426-epoch-iso-cli

## 0. specops 메타

| 필드 | 값 |
|---|---|
| **mode** | Standard |
| **결정 근거** | specifying-ko 자연어 분석 — "bash CLI 만들기", 위험 키워드 없음 |
| **override 경로** | 없음 |

## 1. 개요

**목적**: epoch 정수(초/밀리초)와 ISO 8601 문자열을 양방향으로 변환하는 bash CLI를 제공한다.

**배경**: 개발·디버깅 시 로그·API 응답의 epoch 값을 사람이 읽기 쉬운 날짜로, 또는 반대 방향으로 빠르게 변환할 필요가 있다. 외부 의존성 없이 bash만으로 동작해야 한다.

**성공 판정**: `scripts/epoch.sh 1777161600` 실행 시 `2026-04-26T00:00:00Z`가 출력되고, `scripts/epoch.sh 2026-04-26T00:00:00Z` 실행 시 `1777161600`이 출력되면 완성.

## 2. 범위

### 포함
- epoch(초, 10자리) → ISO 8601 UTC 문자열 (`YYYY-MM-DDTHH:MM:SSZ`)
- epoch(밀리초, 13자리) → ISO 8601 UTC 문자열 (`YYYY-MM-DDTHH:MM:SS.mmmZ`)
- ISO 8601 UTC 문자열 → epoch 초 정수
- ISO 8601 UTC 문자열(`.mmm` 포함) → epoch 밀리초 정수
- 입력 형태로 방향 자동 감지 (숫자 → epoch, 그 외 → ISO)
- stdin 또는 첫 번째 인자(`$1`) 입력 모두 지원
- macOS / Linux `date` 명령어 분기 자동 처리
- `--help` 플래그로 사용법 출력

### 제외 (YAGNI)
- UTC 외 타임존 지원 (`--tz` 플래그)
- 나노초 정밀도
- RFC 2822 등 ISO 8601 외 포맷 입력
- 다중 입력 (파이프 멀티라인)
- 구분자 커스터마이징

## 3. 사용자 시나리오

### 주요 시나리오 A — epoch → ISO
**사용자**: 개발자  
**상황**: API 응답의 epoch 값을 날짜로 확인하고 싶음  
**행동**: `scripts/epoch.sh 1777161600`  
**기대 결과**: `2026-04-26T00:00:00Z` 출력

### 주요 시나리오 B — ISO → epoch
**사용자**: 개발자  
**상황**: 특정 시각의 epoch 값을 쿼리 파라미터로 사용하고 싶음  
**행동**: `scripts/epoch.sh 2026-04-26T00:00:00Z`  
**기대 결과**: `1777161600` 출력

### 보조 시나리오 — stdin 파이프
**행동**: `echo "1777161600" | scripts/epoch.sh`  
**기대 결과**: `2026-04-26T00:00:00Z` 출력

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | 10자리 정수 입력을 epoch 초로 해석해 ISO 8601 UTC 문자열로 출력한다 | must |
| FR-2 | 13자리 정수 입력을 epoch 밀리초로 해석해 `.mmm` 포함 ISO 8601 UTC 문자열로 출력한다 | must |
| FR-3 | ISO 8601 UTC 문자열(`Z` 또는 `+00:00` suffix) 입력을 epoch 초 정수로 출력한다 | must |
| FR-4 | ISO 8601 UTC 문자열에 `.mmm` 밀리초 부분이 있으면 epoch 밀리초 정수로 출력한다 | must |
| FR-5 | 첫 번째 인자(`$1`) 또는 stdin 중 하나로 입력받는다 | must |
| FR-6 | macOS(`date -r`, `date -j -f`)와 Linux(`date -d @`) 를 자동으로 분기 처리한다 | must |
| FR-7 | `--help` 플래그 실행 시 사용법을 출력하고 exit 0한다 | should |
| FR-8 | 인식 불가 입력 시 stderr에 에러 메시지를 출력하고 exit 1한다 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 성능 | 단일 변환 ≤ 1초 |
| NFR-2 | 호환성 | bash 3.2+ (macOS 실측 예정 · Linux 미검증) |
| NFR-3 | 의존성 | POSIX `date`, `grep`, `sed` 외 비표준 외부 바이너리 사용 금지 |

## 6. 제약사항

- 기술 스택: bash + POSIX 표준 유틸리티
- 의존성: `date`, `grep`, `sed` (macOS/Linux 기본 탑재)
- 위치: `scripts/epoch.sh`
- 테스트: `scripts/tests/test_epoch.sh` (slug-cli 컨벤션 동일)

## 7. 가정 (5원칙 5번 — 한계 고백)

- macOS `date -r <epoch>` 와 Linux `date -d @<epoch>` 로 UTC 출력 가능 (macOS 실측 예정)
- 10자리·13자리 자릿수 기준으로 초/밀리초 구분이 실용적으로 충분함 (2001~2286년 범위 커버)
- `Z` suffix가 붙은 ISO 문자열을 `date` 명령어가 UTC로 올바르게 파싱함 (Linux 실측 예정)

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항.

- Q1: Linux에서 `date -d "2026-04-26T16:00:00Z" +%s` 가 올바르게 동작하는지 확인 필요
- Q2: 빈 입력 처리 — 빈 문자열 출력 후 exit 0 vs exit 1

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- `scripts/epoch.sh` — 구현 대상
- `scripts/tests/test_epoch.sh` — 테스트 대상
- `templates/test-conventions-bash.md` — bash 테스트 컨벤션
- ISO 8601:2004 표준

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-epoch-iso-cli · 생성 커맨드: /start*
