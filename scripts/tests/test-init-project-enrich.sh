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
t T1.b "깊게 제품 requirements"    'requirements\.md.*M1|깊게.*(requirements)'         "$CMD"
t T1.c "깊게 아키텍처 api/data"    'api-spec\.md.*data-model|깊게.*(api-spec)'         "$CMD"
t T1.d "얕게 운영 skip"            '얕게/스킵|constitution\.md.*test-strategy'         "$CMD"
t T1.e "단일 커밋"                  '부트스트랩\+enrich|단일 커밋'                       "$CMD"
# AC-2 PRD 초안 합성
t T2.a "PRD 6필드 초안 합성"        '6필드 초안'                                       "$CMD"
t T2.b "근거문서 부재 fallback"     '(메모 부재|셋 다 부재).*(수동|현행)'               "$CMD"   # 20260716 3단 탐색 진화 수용
# AC-3 사실성·상세성 계약 (Karpathy)
t T3.a "근거 N원 (3→4 진화 수용)"  '근거 [34]원'                                     "$CMD"
t T3.b "boilerplate 금지"          '(일반론|boilerplate).*금지'                        "$CMD"
t T3.c "미확정 마커"                '미확정 — 근거 필요'                               "$CMD"
t T3.d "가정: 접두"                '`가정:` 접두'                                     "$CMD"
t T3.e "개발 기준 문서 용도"        '개발 기준 문서'                                    "$CMD"
t T3.f "문서별 최소 채움/깊이 기준" '최소 (채움|깊이) 기준'                            "$CMD"
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

# T11 — Phase 11 v2 품질 계약 (FID 20260710-init-p11-quality · AC-1~AC-7)
# AC-1 인터뷰 스텝
t T11.a "Phase 11.5 인터뷰 스텝"     'Phase 11\.5'                                    "$CMD"
t T11.b "인터뷰 상한 (총≤5)"         '총 최대 5문항|최대 5문항'                         "$CMD"
t T11.c "모름/나중에 선택지 의무"    '모름/나중에'                                     "$CMD"
t T11.d "근거 4원 — 인터뷰 응답 편입" '④.*인터뷰 응답|인터뷰 응답.*④'                  "$CMD"
# AC-7 질문 선정 우선순위
t T11.e "결정급 우선 선정"           '결정급.*우선'                                    "$CMD"
# AC-2 가정 다이제스트 게이트
t T11.f "가정 전건 번호 목록"        '가정.*전건.*번호 목록|번호 목록.*가정'            "$CMD"
t T11.g "결정급 ★ 표시"             '결정급.*★'                                      "$CMD"
t T11.h "y/번호 수정 응답 규약"      '\[y/번호 수정\]'                                 "$CMD"
# AC-3 다이제스트 기록 (대화형·무인 공통, PRD 단일 출처)
t T11.i "§보강 가정 다이제스트 섹션" '§보강 가정 다이제스트'                            "$CMD"
t T11.j "무인에서도 다이제스트 기록" '무인에서도.*다이제스트|다이제스트.*무인에서도 수행' "$CMD"
# AC-4 깊이 기준 v2
t T11.k "must 빈 셀 금지"           '빈 셀 금지'                                      "$CMD"
t T11.l  "should NFR 정량화"          'NFR 정량화'                                     "$CMD"
t T11.l2 "should M2/M3 사전 분해"     'M2/M3 사전 분해'                                "$CMD"
# AC-5 무인 degrade — 양쪽 파일 동기 (전파 누락 차단)
t T11.m "무인 degrade (command)"    '인터뷰.*건별 승인.*생략|건별 승인을 생략'          "$CMD"
t T11.n "무인 degrade (e2e 동기)"   'Phase 11\.5.*생략|인터뷰.*생략'                   "$E2E_SKILL"
# AC-6 질문 스킵 주권
t T11.o "질문 스킵 주권"            '질문 스킵'                                       "$CMD"
# AC-4 must ① — M1 FR 분해 (plan-reviewer Minor 반영: 무경보 탈락 방지)
t T11.p "M1 FR 분해 필수"           '첫 마일스톤.*FR 분해|M1.*FR 분해|M1 시드를 세부 FR' "$CMD"
# AC (리뷰 fix 1) — 다이제스트 재실행 멱등 규칙
t T11.q "다이제스트 재실행 갱신 규칙"  '기존 섹션.*전건 갱신|중복 섹션 append 금지' "$CMD"
# AC (리뷰 fix 2) — V21 판정에 다이제스트 존재 assertion 배선 (bash 블록 grep 명령만 매칭)
t T11.r "V21 다이제스트 존재 검증 배선" 'grep.*§보강 가정 다이제스트' "$E2E_SKILL"
t T11.s "결정 원장 기록"            'decisions\.md|project-context\.md'               "$CMD"
t T11.t "단일 승인 게이트"          '단일 승인 게이트|1회.*요약 제시'                   "$CMD"

# T10 — V21 스캔 규약 표기 allowlist (scan-enrich-placeholders.sh 가 SoT)
# 배경: V21 원 regex 가 `.specops/<FID>` 류 규약 표기를 검출 → 정직 보강 + 정직 스캔 = 항상 FAIL.
SCAN="$PLUGIN/scripts/_internal/scan-enrich-placeholders.sh"

# T10.a 실 부트스트랩 산출물: 규약 표기 미검출 + 실 placeholder 검출 유지 (스캔 무력화 방지)
T10DIR=$(mktemp -d) || exit 1
(
  cd "$T10DIR" && git init -q \
    && git config user.email t@t && git config user.name t
  printf '3\nskip\n1. CLI fixture\n2. dev\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\nN\n' \
    | RESUME_MODE=0 bash "$PLUGIN/scripts/_internal/init-project.sh" t10 >/dev/null 2>&1
)
scan_out=$(bash "$SCAN" "$T10DIR/PRD.md" "$T10DIR"/.specops/memory/*.md 2>/dev/null)
if [ -n "$scan_out" ] && ! printf '%s' "$scan_out" | grep -q '<FID>'; then
  printf 'PASS %-6s %s\n' "T10.a" "부트스트랩 산출물: 실 placeholder 검출 + <FID> 규약 제외"; PASS=$((PASS+1))
else
  printf 'FAIL %-6s %s\n' "T10.a" "부트스트랩 산출물: 실 placeholder 검출 + <FID> 규약 제외"; FAIL=$((FAIL+1))
fi
rm -rf "$T10DIR"

# T10.b 미확정 마커 줄 + 규약 표기만 → clean (exit 0)
T10F=$(mktemp) || exit 1
printf '항목: <미확정 — 근거 필요>\n참조: `.specops/<FID>/spec.md`\n상세: `screens/<name>.md`\n' > "$T10F"
if bash "$SCAN" "$T10F" >/dev/null 2>&1; then
  printf 'PASS %-6s %s\n' "T10.b" "마커 줄 + 규약 표기만 → clean exit 0"; PASS=$((PASS+1))
else
  printf 'FAIL %-6s %s\n' "T10.b" "마커 줄 + 규약 표기만 → clean exit 0"; FAIL=$((FAIL+1))
fi
rm -f "$T10F"

# T10.c 혼재 줄 (규약 표기 + 실 placeholder 동일 줄) → token-level 로 검출 유지
T10F=$(mktemp) || exit 1
printf -- '- 종속 .specops/<FID> 디렉토리: <목록>\n' > "$T10F"
if ! bash "$SCAN" "$T10F" >/dev/null 2>&1; then
  printf 'PASS %-6s %s\n' "T10.c" "혼재 줄 token-level 검출 (<목록> 잔존 적발)"; PASS=$((PASS+1))
else
  printf 'FAIL %-6s %s\n' "T10.c" "혼재 줄 token-level 검출 (<목록> 잔존 적발)"; FAIL=$((FAIL+1))
fi
rm -f "$T10F"

# T10.d e2e V21 블록이 스캔 스크립트 호출 (인라인 regex 이원화 방지)
t T10.d "e2e V21 스캔 스크립트 배선"  'scan-enrich-placeholders\.sh'                    "$E2E_SKILL"
# T10.e Phase 11 계약에 규약 표기 잔존 허용 명시
t T10.e "규약 표기 잔존 허용 계약"    '규약 표기'                                        "$CMD"
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
