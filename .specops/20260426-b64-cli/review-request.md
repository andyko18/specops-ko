# 코드 리뷰 요청 — 20260426-b64-cli

**FID**: 20260426-b64-cli
**BASE_SHA**: 966a6bc (tasks: 20260426-b64-cli)
**HEAD_SHA**: b6010aa (verify: evidence.md)
**변경 규모**: +334 -0 (7 files)

## WHAT_WAS_IMPLEMENTED

Base64 인코더(`b64enc.sh`)·디코더(`b64dec.sh`)·검증기(`b64val.sh`) 3종을 서로 의존 없는 독립 bash CLI로 구현. 각 CLI에 대응하는 단위 테스트 3종 포함.

## PLAN_OR_REQUIREMENTS

- spec: `.specops/20260426-b64-cli/spec.md`
- AC: `.specops/20260426-b64-cli/acceptance-criteria.md` (AC-1~AC-12)
- 구현 방식: bash + 시스템 `base64` 명령 위임 (인코더·디코더), bash 정규식 자체 구현 (검증기)
- 기존 패턴: `scripts/slug.sh` 와 동일 (`#!/usr/bin/env bash`, `set -u`, 인자+stdin 겸용, `printf` 사용)

## 검증 결과

- test-b64enc.sh: PASS=5 FAIL=0
- test-b64dec.sh: PASS=5 FAIL=0
- test-b64val.sh: PASS=7 FAIL=0
- 기존 test-slug.sh: PASS=10 FAIL=0 (회귀 없음)
- 기존 test-cvt.sh: PASS=16 FAIL=0 (회귀 없음)
- AC 충족: 12/12 (must 10/10 + should 2/2)

## 알려진 한계

AC-3 (no args + TTY stdin → usage + exit 1): 코드 구현은 정확(`[ -t 0 ]`)하나 TTY 자동 테스트 불가. `--help` 경로만 자동 검증됨.
