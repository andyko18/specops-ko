<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260604-v1-5-0 · task: T1 -->

# Dispatch Context: T1 (FID 20260604-v1-5-0)

## 1. 담당 AC

- AC-3: CHANGELOG.md에 [1.5.0] 섹션 존재

## 2. 관련 spec.md 섹션

- `.specops/20260604-v1-5-0/spec.md`
- `CHANGELOG.md`

## 3. 테스트 명령

```bash
bash -c "grep -qF '## [1.5.0]' CHANGELOG.md"
```

## 4. 수정 허용 파일 (whitelist)

- `CHANGELOG.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `/Users/andyko/Project/0.Claude/specops-auto-ko`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
