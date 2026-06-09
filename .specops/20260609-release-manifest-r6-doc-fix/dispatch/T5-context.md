<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260609-release-manifest-r6-doc-fix · task: T5 -->

# Dispatch Context: T5 (FID 20260609-release-manifest-r6-doc-fix)

## 1. 담당 AC

- AC-4: CHANGELOG v1.10.0 섹션 백필

## 2. 관련 spec.md 섹션

- `.specops/20260609-release-manifest-r6-doc-fix/spec.md`
- (없음)

## 3. 테스트 명령

```bash
grep -E 'show-fid|release-ko|release\.sh' CHANGELOG.md
```

## 4. 수정 허용 파일 (whitelist)

- `CHANGELOG.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260609-release-manifest-r6-doc-fix-T5/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
