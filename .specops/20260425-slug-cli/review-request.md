# 코드 리뷰 요청 — 20260425-slug-cli

**요청 일시**: 2026-04-25
**FID**: 20260425-slug-cli

## WHAT_WAS_IMPLEMENTED

한국어/영문 혼합 문자열을 URL slug로 변환하는 pure bash CLI (`scripts/slug.sh`).

- `od -An -tu1`로 입력을 바이트 배열로 변환
- UTF-8 코드포인트 계산 (bash 정수 산술)
- 한글 음절(U+AC00~U+D7A3) → 국립국어원 개정 로마자 표기법 고정 매핑 (초/중/종성 배열)
- ASCII 대문자 → 소문자, 영숫자 외 → `-`, 연속 dash 축약, 앞뒤 dash 제거
- 첫 번째 인자 또는 stdin 지원
- `--help` 플래그

## PLAN_OR_REQUIREMENTS

`.specops/20260425-slug-cli/spec.md` + `acceptance-criteria.md` (AC-1~AC-8, must 7개)

## BASE_SHA

187ad2d836af0135755affa4d659e619cc07d18c

## HEAD_SHA

1f8d53f55f5992e2408dfa479027a182917ce7b0

## DESCRIPTION

4개 커밋 (Task 1~4), 2개 파일 신규 생성, +178행.
내부 Phase B(스펙 준수) PASS, Phase C(코드 품질) READY_TO_MERGE (Critical 0).
테스트: PASS=9 FAIL=0.
