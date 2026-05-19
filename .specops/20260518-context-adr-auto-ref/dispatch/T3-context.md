<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260518-context-adr-auto-ref · task: T3 -->

# Dispatch Context: T3 (FID 20260518-context-adr-auto-ref)

## 1. 담당 AC

- AC-5: validate-structure.sh PASS
- AC-R-1: 기존 9종 memory 감지 무손상

## 2. 관련 spec.md 섹션

- `.specops/20260518-context-adr-auto-ref/spec.md`
- `skills/specifying-ko/SKILL.md`
- `scripts/tests/test-memory-references.sh`

## 3. 테스트 명령

```bash
bash scripts/_internal/validate-structure.sh
```

## 4. 수정 허용 파일 (whitelist)

- `scripts/tests/test-memory-references.sh`
- `skills/specifying-ko/SKILL.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/20260518-context-adr-auto-ref-T3/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
