<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260604-start-foundation · task: T8 -->

# Dispatch Context: T8 (FID 20260604-start-foundation)

## 1. 담당 AC

- AC-7: 거버넌스·DAG 회귀 없음

## 2. 관련 spec.md 섹션

- `.specops/20260604-start-foundation/spec.md`
- (없음)

## 3. 테스트 명령

```bash
bash -c 'bash scripts/tests/governance/test-rules.sh 2>&1 | grep -q FAIL=0 && bash scripts/tests/dag/test-parse-dag.sh 2>&1 | grep -q FAIL=0'
```

## 4. 수정 허용 파일 (whitelist)



> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260604-start-foundation-T8/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
