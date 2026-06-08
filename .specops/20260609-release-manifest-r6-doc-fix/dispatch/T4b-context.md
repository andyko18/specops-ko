<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260609-release-manifest-r6-doc-fix · task: T4b -->

# Dispatch Context: T4b (FID 20260609-release-manifest-r6-doc-fix)

## 1. 담당 AC

- AC-7: README commands 12건
- AC-8: README footer v1.10.0
- AC-9: maintain.md chain 완전 표기
- AC-10: 메타 skill chain 다이어그램 완전 표기

## 2. 관련 spec.md 섹션

- `.specops/20260609-release-manifest-r6-doc-fix/spec.md`
- (없음)

## 3. 테스트 명령

```bash
grep -E '12건|integration-test-ko' README.md commands/maintain.md skills/using-specops-auto-ko-ko/SKILL.md
```

## 4. 수정 허용 파일 (whitelist)

- `README.md`
- `commands/maintain.md`
- `skills/using-specops-auto-ko-ko/SKILL.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260609-release-manifest-r6-doc-fix-T4b/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
