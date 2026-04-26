# Dispatch Context: T1 (FID 20260426-test-feature)

## 1. 담당 AC

- AC-1: Given 입력 X / When 실행 / Then 결과 Y
- AC-3: Given 빈 입력 / When 실행 / Then exit 0

## 2. 관련 spec.md 섹션

- `.specops/20260426-test-feature/spec.md` §3.2 입력 검증 (line 47-89)
- `.specops/20260426-test-feature/acceptance-criteria.md` AC-1, AC-3

## 3. 테스트 명령

```bash
bash scripts/tests/test-feature.sh
```

기대: `PASS=2 FAIL=0`

## 4. 수정 허용 파일 (whitelist)

- `src/feature.sh`
- `scripts/tests/test-feature.sh`

## 5. 작업 디렉터리

- `.worktrees/20260426-test-feature-T1/`
