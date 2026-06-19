<!-- reference_upstream: github/spec-kit .specify/memory/constitution-template.md -->
<!-- OWNER_COMMAND: /init-project -->
<!-- layer: Project-Memory -->

# <PROJECT_NAME> 헌법

> AI 에이전트와 사람 모두 읽는 프로젝트의 **불변 원칙** 문서. spec-kit `.specify/memory/constitution-template.md` 패턴 차용.
> 본 파일은 `/init-project` 가 1회 생성. 이후 변경은 거버넌스 §개정 절차 준수.

**version**: 1.0.0
**ratification_date**: <YYYY-MM-DD>
**last_amended_date**: <YYYY-MM-DD>

## 원칙

### 원칙 1: <PRINCIPLE_1_NAME>

**규칙**: <한 문장 — MUST/SHOULD/MAY 명시>

**근거**: <왜 이 원칙이 필요한가 — 1~2 문장>

### 원칙 2: <PRINCIPLE_2_NAME>

**규칙**: <한 문장>

**근거**: <1~2 문장>

### 원칙 3: <PRINCIPLE_3_NAME>

**규칙**: <한 문장>

**근거**: <1~2 문장>

### 원칙 4: <PRINCIPLE_4_NAME>

**규칙**: <한 문장>

**근거**: <1~2 문장>

### 원칙 5: <PRINCIPLE_5_NAME>

**규칙**: <한 문장>

**근거**: <1~2 문장>

## 거버넌스

### 개정 절차

1. 변경 제안: PR 또는 이슈로 변경 사유와 영향 범위 명시
2. 검토: 프로젝트 메인테이너 ≥ 1 인 승인
3. 버전 증가: semver 규칙 (MAJOR: 원칙 제거/재정의, MINOR: 원칙 추가, PATCH: 문구 정정)
4. `last_amended_date` 갱신
5. 의존 문서 (PRD.md / CLAUDE.md / requirements.md) 동기화 검토

### 컴플라이언스 점검

- spec/plan/code 작성 시 본 헌법의 원칙을 모두 만족하는지 자체 검토
- specops-auto-ko Lifecycle 의 specifying-ko / planning-ko / receiving-code-review-ko 가 본 헌법을 자동 인용

## 참조

- 의존 문서: `PRD.md`, `CLAUDE.md`, `.specops/memory/requirements.md`, `.specops/memory/test-strategy.md`
- 거버넌스 원본: github/spec-kit `.specify/memory/constitution-template.md`

---

*작성: <작성자> · <YYYY-MM-DD> · 생성: /init-project (Phase 3)*
