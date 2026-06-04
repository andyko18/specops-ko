<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260604-start-foundation · task: T5 -->

# Dispatch Context: T5 (FID 20260604-start-foundation)

## 1. 담당 AC

- AC-3: clarifying-ko 기술스택 BLOCKING 게이트

## 2. 관련 spec.md 섹션

- `.specops/20260604-start-foundation/spec.md`
- `skills/clarifying-ko/SKILL.md`

## 3. 테스트 명령

```bash
bash -c 'grep -qF foundation skills/clarifying-ko/SKILL.md && grep -qF BLOCKING skills/clarifying-ko/SKILL.md'
```

## 4. 수정 허용 파일 (whitelist)

- `skills/clarifying-ko/SKILL.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260604-start-foundation-T5/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
