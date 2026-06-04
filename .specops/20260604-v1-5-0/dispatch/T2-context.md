<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260604-v1-5-0 · task: T2 -->

# Dispatch Context: T2 (FID 20260604-v1-5-0)

## 1. 담당 AC

- AC-1: plugin.json 버전 1.5.0
- AC-2: marketplace.json 버전 1.5.0
- AC-4: validate-structure manifest 통과

## 2. 관련 spec.md 섹션

- `.specops/20260604-v1-5-0/spec.md`
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

## 3. 테스트 명령

```bash
bash -c "python3 -c \"import json; v=json.load(open('.claude-plugin/plugin.json'))['version']; exit(0 if v=='1.5.0' else 1)\""
```

## 4. 수정 허용 파일 (whitelist)

- `.claude-plugin/marketplace.json`
- `.claude-plugin/plugin.json`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `/Users/andyko/Project/0.Claude/specops-auto-ko`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
