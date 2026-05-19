<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260518-plan-doc-reviewer · task: T2 -->

# Dispatch Context: T2 (FID 20260518-plan-doc-reviewer)

## 1. 담당 AC

- AC-1: 서브에이전트 dispatch 지시 존재
- AC-R-1: 기존 planning-ko chain 무손상

## 2. 관련 spec.md 섹션

- `.specops/20260518-plan-doc-reviewer/spec.md`
- `skills/planning-ko/plan-document-reviewer-prompt.md`

## 3. 테스트 명령

```bash
bash scripts/_internal/validate-structure.sh
```

## 4. 수정 허용 파일 (whitelist)

- `skills/planning-ko/SKILL.md`
- `skills/planning-ko/plan-document-reviewer-prompt.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260518-plan-doc-reviewer-T2/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
