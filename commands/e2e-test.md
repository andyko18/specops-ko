---
name: e2e-test
description: specops-auto-ko E2E 자동 테스트 — lifecycle 6단계를 greet-cli fixture로 완주하고 산출물 구조를 검증
triggers:
  - "/e2e-test"
mode: auto
specops_version: 0.0.0
specops_layer: E2E-Test
reference_upstream: specops-auto-ko 독자 추가 (upstream 미존재)
---

# /e2e-test

## 목적

specops-auto-ko lifecycle chain의 **완전 자동 E2E 검증**. HARD GATE 없이 내장 `greet-cli` fixture를 사용해
`specifying → clarifying → planning → decomposing → implementing → verifying-evidence` 6단계를 완주하고
9개 검증 항목을 점검한다.

## Process

1. `specops-auto-ko:e2e-test-ko` 스킬 즉시 호출
2. 스킬이 전체 lifecycle 자동 실행 + 산출물 구조 검증 수행
3. PASS/FAIL 결과 보고

## 사용 예

```
/e2e-test

→ greet-cli fixture 기반 lifecycle 자동 실행 (6단계)
→ 9개 검증 항목 점검 (V1~V9)
→ PASS=9 FAIL=0 또는 실패 항목 리포트
```

## 주의

- 이 커맨드는 실제 파일을 생성한다 (`.specops/<FID>/`, `greet-cli.sh`, `test-greet-cli.sh`)
- 완료 후 산출물은 증거로 보존됨 (명시 요청 시 `rm -rf .specops/<FID>`)
- `validate-structure.sh` 기대값이 21/5/12/3인 환경에서만 V9 PASS

## 참조

- `skills/e2e-test-ko/SKILL.md` — 실행 로직 + fixture 정의
- `scripts/_internal/validate-structure.sh` — V9 구조 검증
- `scripts/dag/parse-dag.sh` — V8 DAG 파싱 검증

---

*PoC v0.0 · 2026-05-03 · E2E 자동 테스트 진입점*
