<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260609-release-manifest-r6-doc-fix · task: T3 -->

# Dispatch Context: T3 (FID 20260609-release-manifest-r6-doc-fix)

## 1. 담당 AC

- AC-5: R-6 비활성화
- AC-6: test-rules.sh T5.c stop=2 PASS

## 2. 관련 spec.md 섹션

- `.specops/20260609-release-manifest-r6-doc-fix/spec.md`
- (없음)

## 3. 테스트 명령

```bash
bash scripts/tests/governance/test-rules.sh 2>&1 | tail -3
```

## 4. 수정 허용 파일 (whitelist)

- `hooks/rules.jsonl`
- `scripts/tests/governance/test-rules.sh`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260609-release-manifest-r6-doc-fix-T3/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
