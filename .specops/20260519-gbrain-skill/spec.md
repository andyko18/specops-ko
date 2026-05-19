<!-- FID: 20260519-gbrain-skill -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# gbrain-ko 명세 — 20260519-gbrain-skill

## 1. 개요

**§유형**: 신규

**목적**: 개발 세션에서 얻은 인사이트를 구조화된 JSONL 형식으로 누적하고, `/gbrain` 슬래시로 조회·요약한다.

**배경**: gstack office-hours의 `gbrain` 패턴에서 영감을 받아, specops-auto-ko 세션 중 발견한 패턴·주의사항·개선점을 `learnings.jsonl`에 자동 누적한다. 현재 세션 간 인사이트가 소실되는 문제를 해결한다.

**성공 판정**: `bash scripts/gbrain-append.sh "내용"` 으로 `.specops/memory/learnings.jsonl`에 레코드가 추가되고, `/gbrain` 슬래시로 최신 10건·전체 요약을 출력할 수 있으면 완성.

## 2. 범위

### 포함
- `scripts/gbrain-append.sh` — JSONL 레코드 추가 스크립트 (독립 — 병렬 구현 가능)
- `skills/gbrain-ko/SKILL.md` — `/gbrain` 조회·요약 skill (독립 — 병렬 구현 가능)
- `commands/gbrain.md` — `/gbrain` 슬래시 진입점 (의존: skills/gbrain-ko/SKILL.md)
- `.structure-baseline` + `validate-structure.sh` 갱신 (의존: 위 3파일)

### 제외 (YAGNI)
- jq 의존 고급 필터링
- Stop hook 자동 append
- 태그 검색 CLI
- learnings.jsonl 마이그레이션 툴

## 3. 사용자 시나리오

### 주요 시나리오 — 인사이트 추가
**사용자**: Claude (세션 중 인사이트 포착)
**상황**: 구현 중 주의사항·패턴 발견
**행동**: `bash scripts/gbrain-append.sh "grep ERE 패턴이 BRE보다 이식성 높음" --fid 20260519-foo --tags bash,grep`
**기대 결과**: `.specops/memory/learnings.jsonl`에 timestamp·fid·insight·tags 포함 1줄 append

### 보조 시나리오 — 인사이트 조회
**사용자**: 사용자 또는 Claude
**상황**: `/gbrain` 슬래시 실행
**행동**: skill이 learnings.jsonl 읽기 → 최신 10건 + 전체 개수 요약 출력

### 엣지 케이스 — 파일 미존재
**상황**: learnings.jsonl 없을 때 gbrain-append.sh 실행
**기대 결과**: 파일 자동 생성 후 첫 레코드 추가

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `scripts/gbrain-append.sh "내용"` 실행 시 `.specops/memory/learnings.jsonl`에 JSONL 레코드 1줄 append | must |
| FR-2 | JSONL 레코드는 `ts`(ISO-8601)·`fid`·`insight`·`tags` 필드를 포함 | must |
| FR-3 | `learnings.jsonl` 미존재 시 자동 생성 후 추가 | must |
| FR-4 | `skills/gbrain-ko/SKILL.md`가 learnings.jsonl 읽기·최신 10건 + 전체 개수 요약 출력 프로세스를 명시 | must |
| FR-5 | `commands/gbrain.md`가 `/gbrain [--fid FID]` 슬래시로 gbrain-ko 호출 | must |
| FR-6 | `.structure-baseline` skills·commands 카운트 갱신 | must |
| FR-7 | `--fid FID` 인자로 특정 FID 레코드만 필터 출력 | should |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 호환성 | bash 3.2+ (macOS 실측 · Linux 미검증) |
| NFR-2 | 의존성 | 외부 도구 불필요 (bash + date + cat 만 사용) |
| NFR-3 | 파일 포맷 | JSONL — 한 줄 = 유효한 JSON 객체 |

## 6. 제약사항

- 기술 스택: bash 3.2+, 외부 의존성 없음
- 저장 위치: `.specops/memory/learnings.jsonl` (git 추적 대상)
- jq 미사용 — bash + grep + sed 조합

## 7. 가정

- `.specops/memory/` 디렉토리는 사전 존재 (brainstorming-ko 선례)
- JSONL 레코드는 단일 행 (멀티라인 JSON 불가)
- `--fid` 미지정 시 현재 세션 FID를 자동 추론하지 않음 (명시 전달만)

## 8. 열린 질문

없음 (Q1~Q3 명확화 완료)

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음

## 10. 참조

- `.specops/20260519-gbrain-skill/current-state.md`
- `.specops/20260519-gbrain-skill/impact-analysis.md`
- 선례: PR #17 (Visual Companion), PR #18 (improve-arch)
- gstack office-hours gbrain 패턴 (garrytan/gstack)

---

*작성: specifying-ko · 2026-05-19 · FID: 20260519-gbrain-skill · 생성 커맨드: /maintain*
