<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260604-start-foundation · task: T1 -->

# Dispatch Context: T1 (FID 20260604-start-foundation)

## 1. 담당 AC

- AC-1: `/start-foundation` 커맨드 진입

## 2. 관련 spec.md 섹션

- `.specops/20260604-start-foundation/spec.md`
- (없음)

## 3. 테스트 명령

```bash
grep -qF 'entry: foundation' commands/start-foundation.md
```

## 4. 수정 허용 파일 (whitelist)

- `commands/start-foundation.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260604-start-foundation-T1/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
