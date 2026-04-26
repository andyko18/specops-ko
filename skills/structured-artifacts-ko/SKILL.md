---
name: structured-artifacts-ko
description: 모든 Lifecycle 커맨드의 Process 첫 스텝 — `.specops/<FID>/` 디렉토리 규약으로 단계 간 파일-기반 통신을 강제한다
layer: 1
reference_upstream: revfactory/harness@v1.0 skills/structured-artifacts/SKILL.md
specops_version: 0.1.0
---

# Harness 기법 1 — Structured Artifacts

## 개념

긴 실행 작업에서 에이전트 간 상태 전달을 **메시지 페이로드가 아닌 파일**로 한다. 모든 산출물은 약속된 경로 규약(`.specops/<FID>/*.md`)을 따른다.

**왜 필요한가.** 대화 메시지는 컨텍스트에 남아 오염된다. 파일은 다음 커맨드가 필요할 때만 읽는다. 이것이 "context resets"와 쌍을 이룬다.

## FID 규약

**정규식**: `^\d{8}-[a-z0-9-]+$` (예: `20260420-rss-cache`)

- 날짜: 기능 착수일 `YYYYMMDD`
- 슬러그: 영문 소문자·숫자·하이픈만. 공백·한글·대문자 금지
- 유일성: 기존 `.specops/` 하위 디렉토리와 충돌 시 뒤에 `-2`, `-3` 접미

## 디렉토리 구조

```
.specops/
├── <FID>/                         # 기능별 작업 공간
│   ├── spec.md                    # /specify 생성
│   ├── acceptance-criteria.md     # /specify 생성, /clarify 수정
│   ├── clarifications.md          # /clarify 생성
│   ├── plan.md                    # /plan 생성
│   ├── data-model.md              # /plan 생성 (선택)
│   ├── contracts/                 # /plan 생성 (선택)
│   ├── tasks.md                   # /tasks 생성, /implement 상태 마킹
│   ├── analysis.md                # /analyze 생성
│   ├── review.md                  # /code-review 생성
│   └── verify.md                  # /verify 생성
└── session-progress.md            # 전역, 모든 커맨드 append
```

`.specops/`는 프로젝트 루트의 `.gitignore`에 반드시 포함. 플러그인 레포가 아닌 **사용 프로젝트**의 `.gitignore`다.

## 체크리스트 (커맨드 Process 첫 스텝)

1. 사용자 입력에서 FID를 추출하거나 새로 생성한다 (정규식 검증).
2. `.specops/<FID>/` 디렉토리 존재 여부 확인. 없으면 생성.
3. 입력 아티팩트(커맨드별 `specops_artifact_in` 명시)가 모두 존재하는지 확인. 누락 시 **문지기로서 중단**하고 앞 단계 실행을 요청.
4. 출력 아티팩트 경로를 계산하되 **아직 쓰지 않는다**. 본 Process 완료 시에만 쓴다.
5. `session-progress.md`에 "<timestamp> <command> <FID> 시작" 한 줄 append.
6. 종료 시 "<timestamp> <command> <FID> 완료 (출력: ...)" append.

## 예시

**입력**: `/plan 20260420-rss-cache`

- 입력 아티팩트 확인: `.specops/20260420-rss-cache/spec.md`·`acceptance-criteria.md`·`clarifications.md` 존재해야 함
- `clarifications.md` 없으면 "`/clarify 20260420-rss-cache` 먼저 실행하세요" 라고 응답 후 중단
- 모두 있으면 Process 진행, 종료 시 `plan.md` 작성

## 안티패턴

- 에이전트 프롬프트에 파일 **내용**을 붙여넣기 (파일 경로만 전달해야 함 — file-based-communication 참조)
- FID 없이 작업 — 어디에 속한 작업인지 추적 불가
- 이전 단계 아티팩트를 수정 — spec은 spec이 만든 소유물, 이후 커맨드는 **읽기 전용**
- `.specops/`를 git에 커밋 — 세션별 맥락이라 팀 공유 불필요하며 프라이버시 위험
