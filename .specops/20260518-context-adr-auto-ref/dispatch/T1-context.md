<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260518-context-adr-auto-ref · task: T1 -->

# Dispatch Context: T1 (FID 20260518-context-adr-auto-ref)

## 1. 담당 AC

- AC-1: CONTEXT.md 감지 지시 존재
- AC-2: ADR 감지 지시 존재
- AC-3: graceful skip 명시

## 2. 관련 spec.md 섹션

- `.specops/20260518-context-adr-auto-ref/spec.md`
- (없음)

## 3. 테스트 명령

```bash
bash scripts/tests/test-memory-references.sh
```

## 4. 수정 허용 파일 (whitelist)

- `skills/specifying-ko/SKILL.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260518-context-adr-auto-ref-T1/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
