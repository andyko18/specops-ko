<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260609-release-manifest-r6-doc-fix · task: T2 -->

# Dispatch Context: T2 (FID 20260609-release-manifest-r6-doc-fix)

## 1. 담당 AC

- AC-1: release.sh가 plugin.json 버전을 bump한다
- AC-2: release.sh가 marketplace.json 버전을 bump한다
- AC-R-1: test-release.sh 전체 PASS

## 2. 관련 spec.md 섹션

- `.specops/20260609-release-manifest-r6-doc-fix/spec.md`
- `scripts/tests/test-release.sh`

## 3. 테스트 명령

```bash
bash scripts/tests/test-release.sh 2>&1 | tail -3
```

## 4. 수정 허용 파일 (whitelist)

- `scripts/release.sh`
- `scripts/tests/test-release.sh`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260609-release-manifest-r6-doc-fix-T2/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
