<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260609-release-manifest-r6-doc-fix · task: T4a -->

# Dispatch Context: T4a (FID 20260609-release-manifest-r6-doc-fix)

## 1. 담당 AC

- AC-3: 현재 manifest desync 즉시 수정
- AC-R-2: validate-structure.sh 전체 PASS

## 2. 관련 spec.md 섹션

- `.specops/20260609-release-manifest-r6-doc-fix/spec.md`
- (없음)

## 3. 테스트 명령

```bash
bash scripts/_internal/validate-structure.sh 2>&1 | grep manifest
```

## 4. 수정 허용 파일 (whitelist)

- `.claude-plugin/marketplace.json`
- `.claude-plugin/plugin.json`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260609-release-manifest-r6-doc-fix-T4a/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
