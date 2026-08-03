<!-- OWNER_COMMAND: /init-project -->
<!-- layer: Project-Memory -->

# <PROJECT_NAME> 프로젝트 컨텍스트

> `/init-project` Phase 11(Light enrich) 종료 시 생성·갱신. specifying·clarifying·planning 이 FR마다 재추론하지 않도록 **한 줄 요약 SoT**.
> 상세 결정은 `.specops/memory/decisions.md` 표. PRD 가정은 `PRD.md` 말미 `## §보강 가정 다이제스트`.

## 1. 제품

| 항목 | 값 |
|---|---|
| 한 줄 | `<한 줄 설명 — PRD §1>` |
| 페르소나 | `<주요 사용자>` |
| 진입 모드 | `<신규 \| 기존문서 기반>` |

## 2. 스택·제약

| 영역 | 확정값 | 출처 |
|---|---|---|
| 프론트 | `<미확정 — 근거 필요>` | |
| 백엔드 | `<미확정 — 근거 필요>` | |
| 데이터 | `<미확정 — 근거 필요>` | |
| 인증 | `<미확정 — 근거 필요>` | |
| 배포 | `<미확정 — 근거 필요>` | |
| UI 유무 | `<있음 \| 없음>` | |

## 3. 범위 경계

- **포함**: `<M1 핵심>`
- **비포함(이번 범위 밖)**: `<명시적 out-of-scope>`

## 4. 소비 규칙

- specifying-ko: 본 파일 존재 시 spec.md §참조에 `"프로젝트 컨텍스트 — \`.specops/memory/project-context.md\`"` 인용
- clarifying-ko: `decisions.md` 확정 주제는 BLOCKING 재질문 금지 (본 요약과 충돌 시에만 재확인)

---

*생성: /init-project · Phase 11*
