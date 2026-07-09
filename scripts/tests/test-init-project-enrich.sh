#!/usr/bin/env bash
# test-init-project-enrich.sh — /init-project Phase 11 LLM 보강 패스 계약 스캔
# FID: 20260709-init-project-llm-enrich · AC-1~AC-6 + FR-8
# 계약: 지시문 "존재" 검증 (품질은 e2e V21 placeholder 스캔 + 수동 리뷰 담당)
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CMD="$PLUGIN/commands/init-project.md"
BM_SKILL="$PLUGIN/skills/brainstorming-ko/SKILL.md"
BM_CMD="$PLUGIN/commands/brainstorming.md"
E2E_SKILL="$PLUGIN/skills/e2e-test-ko/SKILL.md"
PASS=0; FAIL=0
t() { # $1=id $2=desc $3=ERE pattern $4=file
  if grep -qE "$3" "$4"; then
    printf 'PASS %-6s %s\n' "$1" "$2"; PASS=$((PASS+1))
  else
    printf 'FAIL %-6s %s\n' "$1" "$2"; FAIL=$((FAIL+1))
  fi
}
# AC-1 Phase 11 정의
t T1.a "Phase 11 섹션 존재"        'Phase 11'                                        "$CMD"
t T1.b "그룹① 제품"                '제품.*(PRD|requirements)'                         "$CMD"
t T1.c "그룹② 아키텍처"            '아키텍처.*(architecture|api-spec)'                "$CMD"
t T1.d "그룹③ 운영"                '운영.*(test-strategy|CLAUDE|README)'              "$CMD"
t T1.e "보강분 재커밋"              'chore\(init\): Phase 11 LLM 보강'                 "$CMD"
# AC-2 PRD 초안 합성
t T2.a "PRD 6필드 초안 합성"        '6필드 초안'                                       "$CMD"
t T2.b "메모 부재 fallback"         '메모 부재.*(수동|현행)'                            "$CMD"
# AC-3 사실성·상세성 계약 (Karpathy)
t T3.a "근거 3원"                  '근거 3원'                                         "$CMD"
t T3.b "boilerplate 금지"          '(일반론|boilerplate).*금지'                        "$CMD"
t T3.c "미확정 마커"                '미확정 — 근거 필요'                               "$CMD"
t T3.d "가정: 접두"                '`가정:` 접두'                                     "$CMD"
t T3.e "개발 기준 문서 용도"        '개발 기준 문서'                                    "$CMD"
t T3.f "문서별 최소 채움 기준"      '최소 채움 기준'                                    "$CMD"
# AC-4 --enrich
t T4.a "--enrich 분기"             '\-\-enrich'                                      "$CMD"
t T4.b "멱등 — 잔존 문서만"         '잔존 문서만'                                      "$CMD"
# AC-5 무인 자동수락
t T5.a "무인 자동수락"              '자동수락'                                         "$CMD"
t T5.b "e2e·auto 명시"             '(e2e|§auto).*자동수락|자동수락.*(e2e|§auto)'       "$CMD"
# AC-6 brainstorming 안내 동기
t T9.a "brainstorming skill 동기"   'Phase 11'                                        "$BM_SKILL"
t T9.b "brainstorming command 동기" 'Phase 11'                                        "$BM_CMD"
# FR-8 e2e V21 배선 (nice-to-have)
t T9.c "e2e V21 placeholder 스캔"   'V21'                                             "$E2E_SKILL"
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
