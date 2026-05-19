<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260518-plan-doc-reviewer · task: T1 -->

# Dispatch Context: T1 (FID 20260518-plan-doc-reviewer)

## 1. 담당 AC

- AC-2: plan-document-reviewer-prompt.md 파일 존재 및 4축 포함
- AC-3: 판정 반환 형식 명시

## 2. 관련 spec.md 섹션

- `.specops/20260518-plan-doc-reviewer/spec.md`
- (없음)

## 3. 테스트 명령

```bash
bash scripts/_internal/validate-structure.sh
```

## 4. 수정 허용 파일 (whitelist)

- `skills/planning-ko/plan-document-reviewer-prompt.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260518-plan-doc-reviewer-T1/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
