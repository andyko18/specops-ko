#!/usr/bin/env bash
# specops-ko governance-capture 공용 함수 라이브러리
# source 로 로드하여 사용. 실행 파일 아님.
#
# Sourced library — strict mode 는 caller 에 위임 (set -u/-e 생략).
# Requires: jq 1.6+, bash 3.2+, coreutils (date, grep, sed, cut, mkdir).
_GOV_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_VERIFICATION_STATE_SH="$_GOV_LIB_DIR/../scripts/_internal/verification-state.sh"
_RECORD_METRIC_SH="$_GOV_LIB_DIR/../scripts/_internal/record-metric.sh"
_CHECK_TASK_RECEIPT_SH="$_GOV_LIB_DIR/../scripts/_internal/check-task-receipt.sh"

: "${_SPECOPS_SCOPE_FILES:=}"   # is_docs_only_change 가 판정한 커밋 범위 (계측용, set -u 가드)

# 커밋 메시지에서 태스크 ID 추론 — `T12` 또는 `Task: T12`. 없으면 빈 문자열.
_infer_commit_task() {
  local cmd="${1:-}" hit
  # ① 명시 선언 `Task: T#` 우선 — 산문보다 앞선다.
  #    구 구현은 `Task:...|T[0-9]+` 교대(alternation)를 한 번에 스캔해 **문서 순서상 먼저 나온
  #    쪽**을 집었다. 그래서 제목이 "출력층 (T1~T4 집약)" 이고 본문에 `Task: T4` 인 커밋이
  #    T1 으로 오인돼, 훅이 안내한 receipt 탈출구가 열리지 않았다
  #    (20260807 실사용 검증 — FID 20260807-specops-doctor 에서 실측).
  hit=$(printf '%s' "$cmd" | grep -oE 'Task:[[:space:]]*T[0-9]+' | head -1 | grep -oE 'T[0-9]+' | head -1)
  # ② 명시 선언이 없을 때만 산문 T# fallback (기존 동작 보존)
  [ -n "$hit" ] || hit=$(printf '%s' "$cmd" | grep -oE 'T[0-9]+' | head -1)
  printf '%s' "${hit:-}"
}

# 인라인 BYPASS 의 **사유 값**을 위치 무관하게 추출한다.
#   20260807 실사용 검증 4호: 3호 수정이 `${tool_cmd:0:200}` **앞부분 절단**이라,
#   앞에 `cd`·`echo` 같은 전처리가 붙으면 200자가 거기서 소진돼 **사유가 통째로 잘렸다**.
#   "사유는 명령 앞쪽에 온다"는 3호의 근거가 틀렸다 — compound·전처리가 붙으면 뒤로 밀린다.
#   따라서 자르지 말고 **추출**한다. 3형식(작은따옴표·큰따옴표·무따옴표) 전부 인정 —
#   형식 함정으로 정직하게 사유를 병기한 우회를 무기록 처리하면 안 된다(:136 false-deny 금지 정신).
#   개행은 공백으로 평탄화 — 사유는 계약상 한 줄이고, sed 가 줄 단위라 평탄화가 필요하다.
_extract_bypass_reason() {
  local c r
  c=$(printf '%s' "${1:-}" | tr '\n' ' ')
  r=$(printf '%s' "$c" | sed -n "s/.*SPECOPS_BYPASS_REASON='\([^']*\)'.*/\1/p" | head -1)
  [ -n "$r" ] || r=$(printf '%s' "$c" | sed -n 's/.*SPECOPS_BYPASS_REASON="\([^"]*\)".*/\1/p' | head -1)
  [ -n "$r" ] || r=$(printf '%s' "$c" | sed -n 's/.*SPECOPS_BYPASS_REASON=\([^[:space:]]*\).*/\1/p' | head -1)
  printf '%s' "$r"
}

# BYPASS 수율 계측 — 사유·명령 원문은 friction-log에 남기고, metrics에는 식별자만 기록한다.
# FID가 없거나 형식이 틀리면 no-op (비-specops·초기 세션에서 게이트를 막지 않음).
_record_bypass_metric() {
  local fid="${1:-}"
  [ -n "$fid" ] || return 0
  printf '%s' "$fid" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || return 0
  [ -f "$_RECORD_METRIC_SH" ] || return 0
  bash "$_RECORD_METRIC_SH" --fid "$fid" --phase governance-bypass --fallback true >/dev/null 2>&1 || true
}

detect_fid() {
  # U8: 다중 FID 환경에서 first-only 버그 회피
  #   1순위: <!-- active-fid: <FID> --> 마커 (사용자/도구가 명시적으로 active 표시)
  #   2순위: 첫 '## <FID>' 헤더 (기존 동작, 단일 FID 환경 fallback)
  local progress_file=".specops/session-progress.md"
  [ -f "$progress_file" ] || { echo ""; return 0; }
  # 1순위: active-fid 마커 (any line)
  local marker_fid
  marker_fid=$(grep -m1 -E '<!--[[:space:]]*active-fid:[[:space:]]*[0-9]{8}-[a-z0-9-]+[[:space:]]*-->' "$progress_file" \
    | sed -E 's/.*active-fid:[[:space:]]*([0-9]{8}-[a-z0-9-]+).*/\1/')
  if [ -n "$marker_fid" ]; then
    echo "$marker_fid"
    return 0
  fi
  # 2순위: 첫 ## 헤더 (single-FID fallback)
  grep -E '^## [0-9]{8}-[a-z0-9-]+' "$progress_file" \
    | head -1 \
    | sed -E 's/^## ([0-9]{8}-[a-z0-9-]+).*/\1/'
}

# F-1(5c): session-progress 의 FID 섹션에서 /verify PASS 가 최신 코드변경보다 뒤(위)면 0(verify유효), 아니면 1.
# 코드변경 = /implement(항상) | /receive-review + (fix [1-9]|수용). /specify·/plan·/tasks·/clarify·/analyze 제외(.md).
#
# 한계(20260626 분석, WON'T-FIX): session-progress 는 self-reported — verify 후 lifecycle 밖
#   수동 변경(Edit·핫픽스·직접 git add, /implement 줄 미기록)은 감지 못 함(false-allow). self-report
#   에게 un-self-reported 변경 탐지는 범주 오류 = honesty-failure / out-of-band 2차 방어 클래스.
#   1차 방어는 pretool is_docs_only_change(git-authoritative, verify shortcut 前 실행)가 담당.
#   설계안 A(tree해시 자가오염)·B(수동변경 transcript 無로 우회)·C(detect_fid 무력화 회귀) 전수 기각.
_verify_passed_in_progress() {
  local fid="$1"
  local progress=".specops/session-progress.md"
  [ -f "$progress" ] || return 1
  local section
  section=$(awk -v f="## $fid" '
    $0 ~ "^"f"( |$)" {insec=1; next}
    insec && /^## / {exit}
    insec {print}
  ' "$progress")
  [ -n "$section" ] || return 1
  # I-2: 행 선두 앵커(`^- YYYY-MM-DD HH:MM /command`) — memo 자유텍스트 명령 언급 무매칭 → false-block 차단.
  # YYYY-MM-DD HH:MM 전체 비교: 사전순 = 연대순, 날짜경계(23:59→00:00) 자동 처리.
  # sort -r|head-1 로 max 추출: 줄 순서(prepend 불변식)가 아닌 타임스탬프 값 기준 → writer 순서 오류 무관.
  # 동률(same-minute) → 안전측 = return 2(stale/deny). evidence-stamp 구제 없음(T39b 불변식 보존).
  local vts cts
  vts=$(printf '%s\n' "$section" \
    | grep -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} /verify PASS' \
    | grep -oE '^- [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}' \
    | sed 's/^- //' | sort -r | head -1)
  cts=$(printf '%s\n' "$section" \
    | grep -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} (/implement|/receive-review.*(fix [1-9]|수용))' \
    | grep -oE '^- [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}' \
    | sed 's/^- //' | sort -r | head -1)
  [ -z "$vts" ] && return 1              # verify 없음
  [ -z "$cts" ] && return 0             # 코드변경 없음 → verify 유효
  [[ "$vts" > "$cts" ]] && return 0 || return 2   # 0=유효 / 2=affirmative-stale(implement최신 or 동률)
}

# evidence.md 의 run-verification PASS stamp (honest-scaffold — 실제 테스트 실행 증거).
# inconclusive(verify 줄 부재) 보조 면제용. affirmative-stale 에는 미적용(apply_lookback 분기).
_verify_evidence_stamp() {
  local fid="$1"
  local ev=".specops/$fid/evidence.md"
  local state=".specops/$fid/verification-state.json"
  if [ -f "$state" ] && [ -f "$_VERIFICATION_STATE_SH" ]; then
    local verdict
    verdict=$(SPECOPS_ROOT=".specops" bash "$_VERIFICATION_STATE_SH" current "$fid" 2>/dev/null) || return 1
    [ "$verdict" = "PASS" ] && return 0 || return 1
  fi
  [ -f "$ev" ] || return 1
  grep -q '^RUN-VERIFICATION-RESULT: PASS' "$ev" && return 0 || return 1
}

# 실행 증거 판정 — transcript 의 tool_use(모델 작성 명령) ↔ tool_result(하네스 작성 출력)를
# tool_use_id 로 join 해, 검증 러너가 실제로 실행되어 PASS 를 냈는지 확인한다.
#
# 왜 둘 다 필요한가: command-only 검사는 `echo pytest` 로, result-only 검사는 `echo "VERIFY: PASS"` 로
#   뚫린다. 앵커된 러너 호출 + 그 호출의 하네스 출력을 함께 요구해야 위조 불가 바닥이 된다.
# 범위 경계(A-1, WON'T-FIX): `bash run-all.sh; echo "VERIFY: PASS"` 결합 날조는 미차단 —
#   F-3 wrapper-evasion 과 동일 클래스(의도적 날조). 본 게이트는 자기정직 스캐폴드이며
#   대상은 환각(검증했다 착각한 모델이 선의로 PASS 를 쓰는 것)이다.
# 반환: 0=실행증거 있음 / 1=없음 / 2=판정 불가(fail-open — 호출자가 기존 동작 유지)
#
# 판정 불가(2) 조건: transcript 부재 · jq 실패 · malformed JSONL(--slurpfile 전체 실패) ·
#   **tool_use 이벤트 0건**. 마지막 것이 핵심 — 이벤트가 0건이면 "검증을 안 했다"와 "transcript 를
#   제대로 못 읽었다"를 구별할 수 없다. fail-open 원칙상 판정 불가로 둔다 (C-3 설계 정정).
#
# ★ 신선도 게이트 (20260717-exec-evidence-staleness): 증거는 **마지막 실행증거 이후 코드 편집이
#   없을 때만** 유효하다. 종전엔 윈도우·스코프 없이 transcript 전체를 스캔해, 세션 초반 다른 FID 의
#   VERIFY: PASS 1회가 세션 끝까지 만능 면제표였다 (dogfood test1: FR-2 verify 가 FR-3 미검증
#   implement 커밋 8+개를 전부 열어 friction 무흔적 — 서브에이전트 훅도 main transcript 로 평가되므로
#   동일 적용). 코드 편집 = 비-.specops file_path 의 Edit/Write/NotebookEdit tool_use.
#   .specops/ 아티팩트 Write(evidence.md 마무리 등)는 정직한 verify 후 흐름이라 제외.
#   한계(F-1 동류 heuristic): Bash 경유 파일수정(sed -i·리다이렉트)은 미탐 — honest-mistake 의
#   지배 경로는 Edit/Write 이고, 의도적 우회는 F-3 wrapper 클래스로 수용.
# ── 선언 test_command 추출 (FID 20260809-runner-anchor-downstream) ──
# 왜 필요한가: 실행-근거 앵커가 specops 자신의 러너 형태(run-verification·tests/run-all·
#   pytest·npm test·go/cargo test)를 전제해, downstream 이 테스트를 실제로 돌려도 게이트가
#   열리지 않는다. 실측: 외부 4개 프로젝트에서 BYPASS 77건, 실사용 러너 4종 전부 불인정
#   (bash scripts/tests/frontend.sh · npx vitest run · pnpm --filter … test · turbo run test).
# 왜 grep 인가: dag::get_task_test_command 는 python3+pyyaml 을 요구하는데 여기는 PreToolUse
#   훅 경로다(지연이 체감에 직결). test_command 는 중첩 없는 평면 스칼라라 grep 으로 족하다.
#   대가는 파서 두 벌 — propagation edge 로 잠근다.
# 왜 whitelist 인가: 선언값을 그대로 믿으면 임의 명령이 실행증거가 된다. record-task-receipt
#   가 쓰는 패턴을 **그대로** 재사용한다(두 벌 만들면 drift).
# 한계 (전부 **미탐 방향** — 막히면 사용자는 BYPASS 로 돌아갈 뿐이고 그건 현행이다):
#   - 쌍따옴표 값만 벗긴다. `test_command: 'x'` 는 따옴표가 남아 whitelist 를 못 통과한다.
#     templates/tasks.md 가 쌍따옴표를 쓰므로 실사용 영향 미관측.
#   - CRLF 개행 tasks.md 는 추출이 `[]` 가 된다(선언 경로 무음 비활성 — Phase C 프로브 P12).
#   - 매칭은 접두 비교라 `<러너> || true`·`<러너> 2>&1` 처럼 **임의 접미 wrapper** 를 허용한다.
#     F-3(의도 위조) 클래스로 수용 — 러너는 실제로 돌았고 결과 술어가 별도로 검사된다.
#   - `bash -c "<러너>"` 래핑은 인식하지 않는다(줄 첫 토큰이 다르다).
#   - `SPECOPS_X=1 <러너>` 같은 env 접두도 인식하지 않는다.
#   - 멀티라인 cmd 의 앞줄이 `cd <경로>`·`set -eu`·`export X=Y`·빈 줄이 아니면 인식하지
#     않는다. 따옴표 든 경로(`cd "/path with space"`)도 여기 걸린다 — 문자셋에 따옴표를
#     넣으면 `cd "` 한 줄이 "안전" 이 되어 게이트가 열리기 때문이다(T58 이 그 완화를 잠금).
_extract_declared_cmds() {
  local tasks="$1"
  [ -n "$tasks" ] && [ -r "$tasks" ] || { echo '[]'; return 0; }
  local pat='^(cd[[:blank:]]+[A-Za-z0-9_.][A-Za-z0-9_/.-]*[[:blank:]]+&&[[:blank:]]+)?(bash[[:blank:]]+(scripts|tests?)/[A-Za-z0-9_/.-]+\.sh([[:blank:]][A-Za-z0-9_/.=-]*)*|(python[[:blank:]]+-m[[:blank:]]+)?pytest([[:blank:]][A-Za-z0-9_/.=-]*)*|(npm|pnpm|yarn)[[:blank:]]+(run[[:blank:]]+)?test([[:blank:]][A-Za-z0-9_/.=-]*)*|go[[:blank:]]+test([[:blank:]][A-Za-z0-9_/.=-]*)*|cargo[[:blank:]]+test([[:blank:]][A-Za-z0-9_/.=-]*)*|npx[[:blank:]]+[A-Za-z0-9_@][A-Za-z0-9_@/.-]*([[:blank:]][A-Za-z0-9_@/.=-]*)*|(pnpm|yarn)[[:blank:]]+exec[[:blank:]]+[A-Za-z0-9_@][A-Za-z0-9_@/.-]*([[:blank:]][A-Za-z0-9_@/.=-]*)*)$'
  local cmd out=""
  # ★ sed 는 **파이프 1회**만 돈다 — 종전 per-line fork 는 태스크 수에 선형이었다
  #   (실측: 30태스크 97ms · 100태스크 268ms). PreToolUse hot path 라 fork 를 O(1) 로 낮춘다.
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    case "$cmd" in *..*) continue ;; esac
    [[ "$cmd" =~ $pat ]] || continue
    out="${out}${cmd}"$'\n'
  done <<EOF_TC
$(grep -E '^[[:blank:]]*test_command:' "$tasks" 2>/dev/null \
    | sed -E 's/^[[:blank:]]*test_command:[[:blank:]]*"?//; s/"[[:blank:]]*$//')
EOF_TC
  printf '%s' "$out" | jq -Rs 'split("\n") | map(select(length > 0)) | unique' 2>/dev/null || echo '[]'
}

_verify_exec_evidence() {
  local transcript="$1" fiddir="${2:-}"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 2
  # ★ 창 한정: tasks.md ∧ evidence.md 가 둘 다 있을 때만 선언 경로를 연다(post-verify 창).
  #   evidence.md 부재(implement 창)는 task receipt 소관이라 건드리지 않는다(Wave A).
  #   2번째 인자는 **선택적** — 기존 1-인자 호출자는 decl='[]' 라 판정이 완전히 불변이다.
  local decl='[]'
  if [ -n "$fiddir" ] && [ -f "$fiddir/tasks.md" ] && [ -f "$fiddir/evidence.md" ]; then
    decl=$(_extract_declared_cmds "$fiddir/tasks.md")
  fi
  local out uses hits
  out=$(jq -rn --slurpfile a "$transcript" --argjson decl "$decl" '
    # ★ C-A: $all 은 **전체 tool_use** 를 센다 (name 무관). $uses(Bash 한정)로 세면
    #   Bash 가 없는 transcript(Edit-only·Skill-only = 위조 표현)가 0건이 되어 rc=2 fail-open 으로
    #   빠지고, 게이트가 지배 경로에서 no-op 이 된다. 이벤트 유무 판정과 러너 매칭은 다른 질문이다.
    ($a | map(select(.type=="assistant")
              | .message.content[]?
              | select(.type=="tool_use"))) as $tus
    | ($tus | length) as $all
    | ($a | map(select(.type=="user")
                | .message.content[]?
                | select(.type=="tool_result" and (.is_error != true))   # 에러 결과는 증거 불인정
                | {id: .tool_use_id,
                   out: (.content | if type=="string" then . else tostring end)})) as $res
    # 마지막 유효 실행증거의 전역 tool_use 인덱스 (없으면 -1)
    # 선행자 클래스의 \\n: Bash tool command 는 흔히 멀티라인이다(`cd <path>` 다음 줄에 러너).
    #   줄바꿈이 없으면 2번째 줄의 러너가 ^ 에도 [;&|(] 에도 안 걸려 **정직한 실행을 미인식→deny**
    #   하는 false-block 이 난다(실전 dogfooding 적발). 줄바꿈은 셸의 진짜 명령 구분자이므로
    #   `;`·`&`·`|` 와 동급으로 클래스에 든다 — 앵커 의미(줄 첫 토큰이 러너여야 함)는 그대로:
    #   `echo "ran pytest"`·`# bash run-verification.sh`(주석)는 여전히 불인정 (T12·T13 잠금).
    #   run-all.sh 인식 (20260716 false-block): self-maintenance 의 정식 러너는 전체 스위트
    #   run-all.sh 다 — 성공 시 스스로 `VERIFY: PASS` 토큰을 출력해 기존 토큰 계약으로 판정된다.
    #   앵커는 `tests/run-all\.sh` 로 좁힌다(downstream 의 무관한 ./run-all.sh 불인정 — T15 잠금).
    | ([ range(0; $all) as $i
         | $tus[$i]
         | select(.name=="Bash")
         | {id: .id, cmd: (.input.command // "")}
         | select(.cmd | test("(^|[;&|(\\n])[[:space:]]*(bash[[:space:]]+\\S*(run-verification\\.sh|tests/run-all\\.sh)|(python[[:space:]]+-m[[:space:]]+)?pytest|(npm|pnpm|yarn)[[:space:]]+(run[[:space:]]+)?test|go[[:space:]]+test|cargo[[:space:]]+test)"))
         | . as $u
         | ($res | map(select(.id == $u.id)) | .[0].out // "")
         | select(test("VERIFY: PASS") and (test("VERIFY: (PARTIAL|FAIL)") | not))
         | $i ] | max // -1) as $lasthit
    # ── 백그라운드 실행 증거 (20260807-bg-verify-evidence) — 기존 $lasthit 경로 무손상 ──
    # 백그라운드 Bash 는 tool_result 가 실행 출력이 아니라 스텁이다("Output is being written to: <경로>").
    # 실제 출력은 이후 별도 Read 의 결과에만 있으므로, **그 스텁이 발급한 경로와 정확히 일치하는**
    # Read 를 찾아 판정한다. 완화가 아니라 경로 추가다 — 백그라운드 Bash 도 러너 앵커를 먼저 통과해야 하고,
    # 경로 일치·출처 구속이 걸려 임의 파일 Read 로는 열리지 않는다.
    # ★ select 가드 필수: 없이 split 하면 미매칭 시 null|split 로 **jq 전체가 죽어** 셸의 `|| return 2`
    #   에 걸린다 → rc=2(fail-open) = 게이트 무음 해제. T21 이 이 회귀를 잠근다.
    # ★ Read 결과 술어는 Bash 결과와 **동일**해야 한다 — 기존 부정토큰 검사는 Bash 결과에만 걸려 있어
    #   자동 적용되지 않는다. 빼면 T10 이 잠근 위조 표면이 신규 경로에 무잠금 이식된다. T22 가 잠근다.
    | ([ range(0; $all) as $i
         | $tus[$i]
         | select(.name=="Bash")
         | {id: .id, cmd: (.input.command // "")}
         | select(.cmd | test("(^|[;&|(\\n])[[:space:]]*(bash[[:space:]]+\\S*(run-verification\\.sh|tests/run-all\\.sh)|(python[[:space:]]+-m[[:space:]]+)?pytest|(npm|pnpm|yarn)[[:space:]]+(run[[:space:]]+)?test|go[[:space:]]+test|cargo[[:space:]]+test)"))
         | . as $u
         | ($res | map(select(.id == $u.id)) | .[0].out // "")
         | select(test("Output is being written to: "))
         | (split("Output is being written to: ")[1] | split(" ")[0] | rtrimstr(".")) as $path
         | select($path | length > 0)
         | select([ range($i+1; $all) as $j
                    | $tus[$j]
                    | select(.name=="Read")
                    | select((.input.file_path // "") == $path)
                    | . as $r
                    | ($res | map(select(.id == $r.id)) | .[0].out // "")
                    | select(test("VERIFY: PASS") and (test("VERIFY: (PARTIAL|FAIL)") | not))
                    | 1 ] | length > 0)
         | $i ] | max // -1) as $bghit
    # ── 선언 test_command 실행 증거 (20260809-runner-anchor-downstream) ──
    # 왜 별도 블록인가: 기존 앵커 정규식은 3곳에 텍스트 복제돼 있고 T25 가 그 동일성을
    #   잠근다. 그 select 안에 OR 를 넣으면 고유 패턴이 2종이 되어 T25 가 깨진다.
    #   별도 블록은 리터럴을 늘리지 않고, 후속에 bg 확장이 필요해질 때 지점도 명확하다.
    # 왜 고정문자열인가: 선언 48건이 정규식 메타문자를 포함한다 — test() 에 넣으면 `.` 가
    #   임의 문자로 확장돼 과대 매치한다(게이트 무력화 방향).
    | ([ range(0; $all) as $i
         | $tus[$i]
         | select(.name=="Bash")
         | {id: .id, cmd: (.input.command // "")}
         # ★ heredoc 위장 차단: `cat <<DOC` 본문의 러너 줄이 줄시작 토큰으로 앵커를 통과한다.
         #   evidence.md 를 heredoc 으로 쓰는 것은 정직한 흐름이라, 막지 않으면 **문서 작성이
         #   게이트를 여는** false-open 이 된다. 기존 5종은 VERIFY: PASS 양성 요구라 무관했다.
         | select(.cmd | contains("<<") | not)
         | . as $u
         # ★ 매칭 줄이 **진짜 명령 시작**인지 본다 (Phase C Critical, 20260809).
         #   heredoc 가드만으로는 부족했다 — 따옴표 문자열 안의 실개행 줄이 선언 명령과
         #   같으면 실행 없이 열렸다(실측 재현):
         #     echo "노트\n<러너>\n끝" > notes.md      ← rc=0 이었음
         #     git commit -m "fix\n\n<러너> 로 검증함"  ← rc=0 이었음
         #     true \ + 개행 + <러너>                   ← rc=0 이었음 (인자 연속)
         #   ★ 이 판정은 인용 문법을 **흉내내지 않는다**. 두 번 시도했고 두 번 다 뚫렸다:
         #     1차 따옴표 개수 패리티 → `\"` 이스케이프가 짝수를 만들어 false-open
         #     2차 인용 상태기계     → ANSI-C `$\u0027..\u0027`·`$(..)` 중첩·백틱에서 false-open
         #   둘 다 주석에 "오산은 미탐 방향이라 안전" 이라 적었고 **둘 다 실측 반증됐다**.
         #   셸 인용은 정규 파싱이 불가하므로 아래처럼 **안전 접두 화이트리스트**로 뒤집는다.
         | ($u.cmd | split("\n")) as $lines
         | select([ range(0; ($lines | length)) as $k
             | ($lines[$k] | sub("^[ \t]+"; "")) as $L
             | select($decl | any(. as $d | $L == $d or ($L | startswith($d + " "))))
             # ★ 매칭 줄 **앞** 줄들을 안전 화이트리스트로 좁힌다 (Phase C 3회차 전환).
             #   종전엔 "문자열이 열렸나" 를 직접 판정했다 — 따옴표 패리티 → 인용 상태기계
             #   순으로 두 번 고쳤는데, 셸 인용은 정규 파싱이 불가해 라운드마다 새 우회가
             #   나왔다(이스케이프 \" → 혼합 인용 → ANSI-C → $(..) 중첩 → 백틱). 전부
             #   **false-open** 이었다. 쫓기를 그만두고 방향을 뒤집는다:
             #   앞 줄이 전부 `빈 줄`·`cd <경로>`·`set -eu`·`export X=Y` 일 때만 매칭 줄을
             #   명령 시작으로 인정한다. 그 밖(echo·git commit -m·치환·백틱·행연속·리다이렉션)은
             #   무엇이 들었든 skip 이라 **구성상 열 수 없다** — 인용 문법을 흉내내지 않는다.
             #   허용 문자셋에 따옴표·$·백틱·\ 를 넣지 않는 것이 이 가드의 본체다.
             #   대가는 미탐이다 — 앞줄에 echo 가 섞인 정직한 실행은 인식 못 한다. 그때
             #   사용자는 러너를 단독 실행하면 되고, 그건 현행 BYPASS 와 동등하다(T53).
             #   ★ 폐쇄의 범위는 **어휘적 열림**까지다. `export PATH=/tmp/evil` · `cd /가짜repo`
             #   처럼 **환경·경로를 바꿔 가짜 러너를 심는** 것은 화이트리스트를 통과한다 —
             #   F-3(의도 위조) 클래스로 설계상 수용된 범위이지 이 가드가 막는 대상이 아니다.
             #   (위 162행이 same-line env 접두를 "미인식" 이라 적은 것과 비대칭이다: 그건
             #   앵커가 줄 첫 토큰을 요구해서지 env 조작을 막아서가 아니다.)
             #   `set -euo pipefail`·`set -o pipefail` 은 `pipefail` 토큰 때문에 막힌다(미탐).
             #   후행 순수 옵션어 허용은 어휘 문자가 없어 안전하나, **인용값 허용**
             #   (`export FOO="bar baz"`)은 T58 이 잠근 `cd "` 구멍과 동형이라 금지다.
             | select($k == 0 or ([ $lines[0:$k][]
                 | select(test("^[ \t]*(cd[ \t]+[A-Za-z0-9_./~-]+|set[ \t]+-[a-zA-Z]+|export[ \t]+[A-Za-z_][A-Za-z0-9_]*=[A-Za-z0-9_./:-]*)?[ \t]*$") | not)
               ] | length) == 0)
             | 1 ] | length > 0)
         # ★ 결과 존재 확인이 먼저다 — $res 는 is_error!=true 만 담으므로 에러 결과는
         #   조인에서 빠져 "" 가 되고, "" 엔 실패 토큰이 없어 성공으로 오판된다(T34 잠금).
         | ($res | map(select(.id == $u.id))) as $r
         | select($r | length > 0)
         | ($r[0].out // "")
         # ★ 백그라운드 스텁 차단 — bg Bash 의 결과는 실행 출력이 아니라 스텁이다.
         #   막지 않으면 러너를 띄우고 **결과를 보지도 않은 채** 커밋이 열린다(T41).
         #   문자열은 아래 $bghit(및 _bg_pending_path)이 쓰는 것과 동일하다.
         | select(test("Output is being written to: ") | not)
         # downstream 러너는 VERIFY: PASS 를 찍지 않는다(`PASS 12/12`) — 그 토큰을 요구하면
         #   이 경로가 영영 안 열린다. 주 판정은 위 `$r | length > 0`(= is_error false =
         #   종료코드 0) 이고, 아래 실패 토큰 스캔은 **보조층**이다.
         # ★ 꼬리 3줄만 본다 — 전체를 스캔하면 규약 성공 요약 `PASS=N FAIL=0` 과 테스트
         #   설명 줄(`PASS T16 run-all 실패(FAIL 토큰)`)이 걸려 정직한 성공이 막힌다.
         #   그건 이 FID 가 고치려는 병의 재생산이다(실측).
         | (split("\n") | map(select(test("^[ \t]*$") | not)) | .[-3:] | join("\n"))
         # 0-카운트 중화가 스캔보다 **먼저**여야 한다 — 안 그러면 FAIL=0 이 실패로 읽힌다.
         | gsub("(?i)(fail(ure)?(ed)?s?|error(s)?)[ \t]*[=:][ \t]*0(?![0-9])"; "ZERO")
         | gsub("(?i)\\b(0|no)[ \t]+(fail(ure|ed)?s?|errors?)"; "ZERO")
         # 한국어도 중화한다 — 없으면 `실패: 0`·`오류 0건` 이 차단된다. 한국어 플러그인이
         #   한국어 러너 출력을 막는 것은 대상 집단 직격 false-block 이다.
         | gsub("(실패|오류|에러)[ \t]*[:=]?[ \t]*0[ \t]*건?(?![0-9])"; "ZERO")
         | gsub("0[ \t]*건?[ \t]*(실패|오류|에러)"; "ZERO")
         | select(test("VERIFY: (PARTIAL|FAIL)") | not)
         | select(test("(?i)(^|[^a-z])(fail(ure|ed)?s?|error)") | not)
         | select(test("실패|오류|에러") | not)
         | $i ] | max // -1) as $declhit
    # 마지막 코드 편집(비-.specops Edit/Write/NotebookEdit/MultiEdit)의 전역 인덱스 (없으면 -1)
    | ([ range(0; $all) as $i
         | $tus[$i]
         | select(.name=="Edit" or .name=="Write" or .name=="NotebookEdit" or .name=="MultiEdit")
         | select((.input.file_path // "") | test("(^|/)\\.specops/") | not)
         | $i ] | max // -1) as $lastedit
    # $bghit 은 **러너를 띄운 Bash 의 인덱스**다(Read 인덱스가 아님) — 실행 시작 시점이 더 보수적이라
    # "Bash 띄움 → 코드 수정 → Read" 를 stale 로 올바르게 판정한다(T20).
    | ([$lasthit, $bghit, $declhit] | max) as $besthit
    | (if $besthit >= 0 and $besthit > $lastedit then 1 else 0 end) as $h
    | "\($all) \($h)"
  ' 2>/dev/null) || return 2
  [ -z "$out" ] && return 2
  uses=${out%% *}; hits=${out##* }
  [ "$uses" -eq 0 ] 2>/dev/null && return 2   # tool_use 이벤트 0건 → 판정 불가 (증거 없음이 아님)
  [ "$hits" -gt 0 ] 2>/dev/null && return 0
  return 1
}

# 백그라운드 러너 스텁은 있으나 출력 회수 Read 가 없는 경우의 경로를 반환 (없으면 빈 출력).
# deny 안내문이 "왜 막혔는지" 를 원인별로 구분하는 데 쓴다 — 구분이 없으면 사용자는 방금 러너를
# 돌리고도 "실행 기록이 없습니다" 를 보고 원인을 모른다(실측: 195s 러너 재실행 낭비).
# ★ 별도 함수인 이유: _verify_exec_evidence 는 `res=$(apply_lookback_rule ...)` 서브셸 안에서
#   호출돼 그 안에서 설정한 변수가 부모로 전파되지 않는다(Phase B 적발). 안내문 생성은 deny
#   경로에서만 일어나므로 여기서 jq 를 1회 더 도는 비용은 hot path 에 영향이 없다.
_bg_pending_path() {  # $1=transcript → stdout 경로 (없으면 빈 문자열)
  [ -n "${1:-}" ] && [ -f "$1" ] || return 0
  jq -rn --slurpfile a "$1" '
    ($a | map(select(.type=="assistant") | .message.content[]? | select(.type=="tool_use"))) as $tus
    | ($tus | length) as $all
    | ($a | map(select(.type=="user") | .message.content[]?
                | select(.type=="tool_result" and (.is_error != true))
                | {id: .tool_use_id, out: (.content | if type=="string" then . else tostring end)})) as $res
    | ([ range(0; $all) as $i
         | $tus[$i]
         | select(.name=="Bash")
         | {id: .id, cmd: (.input.command // "")}
         | select(.cmd | test("(^|[;&|(\\n])[[:space:]]*(bash[[:space:]]+\\S*(run-verification\\.sh|tests/run-all\\.sh)|(python[[:space:]]+-m[[:space:]]+)?pytest|(npm|pnpm|yarn)[[:space:]]+(run[[:space:]]+)?test|go[[:space:]]+test|cargo[[:space:]]+test)"))
         | . as $u
         | ($res | map(select(.id == $u.id)) | .[0].out // "")
         | select(test("Output is being written to: "))
         | (split("Output is being written to: ")[1] | split(" ")[0] | rtrimstr(".")) as $path
         | select($path | length > 0)
         | select([ range($i+1; $all) as $j
                    | $tus[$j]
                    | select(.name=="Read")
                    | select((.input.file_path // "") == $path)
                    | 1 ] | length == 0)
         | {i: $i, p: $path} ] | last // null) as $pend
    # ★ staleness 정렬 (Phase C Important 1): 안내는 판정과 같은 기준을 써야 한다.
    #   bg 기동 이후 코드 편집이 있으면 안내대로 Read 해도 stale 로 재차단된다 —
    #   "Read 하면 인정됩니다" 가 거짓이 되고, 이 deny 메시지 자신이 경고하는
    #   "안내 이행 후 동일 메시지 재차단 → BYPASS 스파이럴"(dogfood #418→#421) 조건이 된다.
    | ([ range(0; $all) as $i
         | $tus[$i]
         | select(.name=="Edit" or .name=="Write" or .name=="NotebookEdit" or .name=="MultiEdit")
         | select((.input.file_path // "") | test("(^|/)\\.specops/") | not)
         | $i ] | max // -1) as $lastedit
    | (if $pend != null and $pend.i > $lastedit then $pend.p else "" end)
  ' 2>/dev/null || true
}

# staged ∪ unstaged-tracked 합집합 변경이 전부 docs 확장자면 0(면제), 아니면 1(비면제).
# git diff HEAD = working tree vs HEAD = staged + unstaged tracked 전부 포함 (commit -a 우회 차단).
# base branch 자동감지 — main 우선, master 차선, 없으면 실패(안전측 차단).
_detect_base_branch() {
  local b
  for b in main master; do
    git show-ref --verify --quiet "refs/heads/$b" && { printf '%s' "$b"; return 0; }
  done
  return 1
}

# 신규 repo(HEAD 없음) → --cached fallback. working tree·staged 빈(=PR 맥락, 커밋 완료) → base...HEAD PR-범위 diff.
# 빈 목록·git 실패·base 결정 불가 → 1 (fail-safe — 판정 불가 시 차단 보존). fail-open(hook 에러 allow)과 구분.
is_docs_only_change() {
  # --no-renames: rename 을 delete(old)+add(new) 2줄로 분해 → 코드파일 .md rename 위장
  #   (tool.sh→tool.md)이 원본 .sh 를 숨겨 docs-only 오인면제되던 표면 차단. 출력포맷(--name-only) 무변경.
  # $1(선택): 실행될 커밋 명령. **인자가 없으면 아래 분기가 통째로 비활성**이라 종전과 동일하게 동작한다
  #   — batch 게이트(pretool:112)·기존 T-docs.a~q 가 무수정인 이유다.
  local files
  if _commit_scope_is_staged "${1:-}"; then
    # 안전 형태 → staged 가 곧 커밋 범위다. 빈 staged 는 fail-safe(비면제) 로 떨어진다.
    files=$(git diff --cached --name-only --no-renames 2>/dev/null)
    [ -z "$files" ] && return 1
    # 계측용 노출 (20260813-friction-staged-record) — 호출자가 같은 목록으로 분류할 수 있게 한다.
    #   deny 경로에서 git diff 를 재실행하지 않기 위함이며, 판정 자체에는 쓰이지 않는다.
    #   set -u 안전: 파일 상단에서 `: "${_SPECOPS_SCOPE_FILES:=}"` 로 초기화한다.
    _SPECOPS_SCOPE_FILES="$files"
    _files_all_docs "$files"
    return $?
  fi
  files=$(git diff HEAD --name-only --no-renames 2>/dev/null)
  [ -z "$files" ] && files=$(git diff --cached --name-only --no-renames 2>/dev/null)
  if [ -z "$files" ]; then
    local base
    base=$(_detect_base_branch) || return 1
    files=$(git diff "$base"...HEAD --name-only --no-renames 2>/dev/null)
  fi
  [ -z "$files" ] && return 1
  # 계측용 노출 (20260813-friction-staged-record) — 위 staged 경로와 대칭.
  _SPECOPS_SCOPE_FILES="$files"
  _files_all_docs "$files"
}

# whitelist 매처 (is_docs_only_change ↔ is_docs_only_audit_scope 공유 — 면제 클래스 drift 방지)
# 빈 목록 = 1 (fail-safe — 판정 불가 시 비면제).
_files_all_docs() {
  local files="$1" f
  [ -z "$files" ] && return 1
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.md|*.txt|*.rst) ;;
      # design/아티팩트 면제 (20260716-batch-dogfood: Phase 2.5 design 커밋이 .md 한정 whitelist 에
      #   걸려 false-block → BYPASS 남발 유발. 둘 다 실행 코드가 살 수 없는 경로다):
      #   - screens/*.html : design-first 화면 미리보기(스펙 .md 와 쌍). repo 루트 screens/ 한정 —
      #     src/ 등 경로의 .html(앱 코드 가능)은 비면제 유지.
      #   - .specops/*     : lifecycle 아티팩트 도메인(review-base.sha·friction-log.jsonl 등 비 .md 포함).
      screens/*.html|.specops/*) ;;
      *) return 1 ;;
    esac
  done <<EOF
$files
EOF
  return 0
}

# 커밋 범위를 계측용으로 분류한다 (20260813-friction-staged-record).
#   stdout: docs-only | code | empty · 항상 rc=0 (판정 실패 개념이 없다 — 빈 목록도 유효한 답)
#
# 왜 필요한가: friction-log 가 "무엇을 커밋하려 했는가"를 남기지 않아, 마찰이 정탐인지
#   오탐인지 사후 산정이 불가능했다(선행 FID 20260813-r1-docs-only-scope 가 block 77건 중
#   결함 유래를 끝내 세지 못하고 "효과 미측정"으로 남긴 것이 실증).
#
# 왜 _files_all_docs 재사용인가: 분류가 **면제 클래스와 정의상 일치**해야 집계가 의미를 갖는다.
#   별도 규칙을 만들면 "면제됐는데 code 로 분류" 같은 모순이 생긴다. 매처 자체는 건드리지 않는다
#   (pretool↔posttool 공유 — #214→T8.e 회귀 위험).
_commit_scope_class() {
  local files rc1=0 rc2=0
  if [ "$#" -gt 0 ]; then
    files="$1"
  else
    files=$(git diff --cached --name-only --no-renames 2>/dev/null); rc1=$?
    if [ -z "$files" ]; then
      files=$(git diff HEAD --name-only --no-renames 2>/dev/null); rc2=$?
      # ★ 판정 불가(git 실패)와 빈 커밋범위를 구별한다 (AC-6·AC-4).
      #   둘 다 실패면 **아무것도 출력하지 않는다** → 호출부의 조건부 병합이 필드를 생략하고
      #   집계는 `판정불가` 로 센다. 여기서 'empty' 를 내면 AC-4 가 분리한 축이 다시 뭉개진다.
      [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && return 0
    fi
  fi
  [ -z "$files" ] && { printf 'empty'; return 0; }
  if _files_all_docs "$files"; then printf 'docs-only'; else printf 'code'; fi
}

# 커밋 명령이 **staged 만** 커밋하는 안전 형태인지 판정한다 (20260813-r1-docs-only-scope).
#   0 = staged 로 스코프 축소 가능 / 1 = 보수(현행 working-tree) 스코프 유지.
#
# 왜 필요한가: is_docs_only_change 는 working tree 전체를 봐서, 문서만 staged 해 커밋해도
#   작업트리에 남은 코드 수정 때문에 차단됐다(실측 BYPASS 16건 중 13건이 "코드 변경 0").
#   종전 주석은 "pretool 은 액션 前이라 working-tree 가 곧 커밋 범위"라고 단정했으나 **틀렸다** —
#   staged 부분집합 커밋에서 working-tree ⊋ 커밋 범위다.
#
# 왜 화이트리스트인가: #255 가 "이름 나열"식 접근의 3회 반복 실패를 기록한다. 위험 형태를 나열하면
#   나열 밖이 뚫린다. 안전 형태만 통과시키면 나열 밖은 전부 **보수 쪽(false-block 방향)** 으로 넘어진다.
_commit_scope_is_staged() {
  local s first resid tok extra rest skip=0
  [ -n "${1:-}" ] || return 1
  # 스트리퍼 재사용 — heredoc 본문·인용 내용이 판정을 오염시키지 않도록 (pretool 과 동일 전처리).
  s=$(_strip_heredoc_bodies "$1")
  s=$(_strip_quoted_strings "$s")
  # C1(개행): **개행은 `;` 와 동등한 명령 분리자다.** 첫 줄만 남기고 잔여를 무검증 폐기하면
  #   C1(연산자)·C2(단일 커밋) 가 둘째 줄부터 적용되지 않는다 — `git commit -m 'docs'` ⏎ `git add -A`
  #   ⏎ `git commit -am 'code'` 가 축소 승인으로 뚫렸다(Phase B false-allow 실측, 구코드는 deny).
  #   그렇다고 멀티라인을 전부 거부할 수는 없다 — `-F - <<'EOF'` heredoc 이 이 repo 주력 커밋 형태다(AC-7).
  #   그래서 잔여 줄이 **heredoc 종결자로만 설명되는지**를 검사한다: 첫 줄에 `<<` 가 있고 잔여 줄이
  #   공백 또는 bare word(`[A-Za-z0-9_]+`) 단독이면 통과, 그 외는 전부 보수.
  #   왜 실제 delimiter 와 대조하지 않는가: `<<EOF`·`<<'EOF'`·`<<-EOF` 파싱 표면만 늘고 보안 이득이 없다 —
  #   아래 C2 가 **첫 명령이 곧 커밋**임을 이미 보장하므로, 뒤따르는 bare word 명령은 그 커밋의
  #   staged 범위를 바꿀 수 없다(인자 없는 한 단어라 `git add ...` 형태가 불가능).
  #   ★ ANSI-C 인용 정정(Phase C 실측): `-m $'a\nb'` 는 _strip_quoted_strings 가 bail(원본 반환)하지만
  #     그것만으로 보수가 되지는 않는다 — **실개행을 포함한 형태**만 위 멀티라인 검사에서 보수로 떨어지고,
  #     리터럴 `\n` 한 토큰은 아래 C3 의 skip 이 소비해 통과한다(rc=0). 통과해도 무해하다 — 메시지 값이라
  #     staged 범위를 바꾸지 못한다. 이 주석을 정정하는 이유: 본 함수가 존재하는 원인 자체가
  #     "working-tree 가 곧 커밋 범위" 라는 **틀린 주석**이었다. 검증 없는 안전 주장은 다음 결함의 씨앗이다.
  first=${s%%$'\n'*}
  if [ "$first" != "$s" ]; then
    resid=${s#*$'\n'}
    while IFS=$' \t' read -r tok extra; do
      [ -z "$tok" ] && continue                            # 공백 전용 줄(후행 개행 등)
      case "$first" in *'<<'*) ;; *) return 1 ;; esac      # heredoc 아닌 멀티라인 = 명령 분리
      [ -n "$extra" ] && return 1                          # 종결자 줄에 토큰이 더 있으면 명령
      case "$tok" in *[!A-Za-z0-9_]*) return 1 ;; esac      # bare word 아님
    done <<EOF
$resid
EOF
  fi
  s=$first           # 첫 줄만 — heredoc 종결자 줄(EOF) 은 위에서 검증 완료
  s=${s%%<<*}        # heredoc 리다이렉션 토큰 절단 (`-F - <<'EOF'` 의 뒷부분)
  # C1: compound — 파싱 시점 staged ≠ 커밋 시점 staged (`git add -A && git commit`)
  case "$s" in *'&&'*|*'||'*|*';'*|*'|'*) return 1 ;; esac
  # C2+C5: 반드시 `git commit` 으로 시작. env 접두·`git -c ... commit`·다중 명령이 한 번에 배제된다.
  case "$s" in
    'git commit') rest="" ;;
    'git commit '*) rest=${s#git commit } ;;
    *) return 1 ;;
  esac
  # C3+C4+C6: 화이트리스트 플래그만 허용. 값을 받는 플래그는 다음 토큰을 소비한다.
  #   비플래그 토큰(경로 인자)·화이트리스트 밖 `-` 토큰은 전부 보수 판정.
  #   ★ 명령치환은 skip 소비보다 먼저 거부한다 (Phase C Important-2). _strip_quoted_strings 는
  #     `$(`·백틱 포함 인용을 "실제 실행된다 → 판정 보존" 목적으로 **일부러 남기는데**(:654),
  #     `skip=1` 이 그 보존 토큰을 무검사로 삼키면 스트리퍼의 의도가 무력화된다. 실측상 뚫리던 것은
  #     `-m "$(ga)"` 류 **무인자 단일 토큰**뿐이지만(다중 토큰·분리자 포함은 이미 보수),
  #     치환은 커밋 **전에** 실행되므로 그 한 형태로도 "파싱 시점 staged ≠ 커밋 시점 staged" 가 성립한다.
  #     false-block 비용은 `-m "$(cat f)"` 단일 토큰 클래스뿐이라 사실상 0.
  for tok in $rest; do
    case "$tok" in *'$('*|*'`'*) return 1 ;; esac
    if [ "$skip" -eq 1 ]; then skip=0; continue; fi
    case "$tok" in
      -m|--message|-F|--file) skip=1 ;;
      --message=*|--file=*|-q|--quiet) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

# posttool 감사 스코프 (20260718-posttool-audit-silence): 감사는 **방금 일어난 액션의 범위**를 본다 —
#   R-1(commit) = HEAD~1..HEAD(방금 커밋), R-2(pr create) = base...HEAD(PR 범위).
# 왜: working-tree 기준 is_docs_only_change 를 posttool 에 쓰면, 커밋 직후 잔여 dirty 가 거의 항상
#   tracked `.specops/session-progress.md` 뿐이라 .specops/* 면제(#214)에 걸려 **감사가 통째로 침묵**한다
#   (#214 이후 R-1 posttool warn 전 repo 0건의 실물 원인 — pretool block 만 남는 절반 가시성).
#   pretool 을 분리해 두는 이 근거(#214 침묵)는 그대로 유효하다 — 감사는 **이미 일어난** 액션의 범위를 본다.
#   다만 종전 주석이 덧붙인 "pretool 은 액션 前이라 working-tree 가 곧 커밋 범위" 라는 전제는 **틀렸다**:
#   staged 부분집합 커밋에서 working-tree ⊋ 커밋 범위다. pretool 쪽은 is_docs_only_change 가 커밋 명령을
#   받아 _commit_scope_is_staged 로 스코프를 좁혀 해결했다 (20260813-r1-docs-only-scope, 위 :458 참조).
# fail-safe: range diff 실패(최초 커밋 HEAD~1 부재·base 미검출) = 비면제(감사 실행 — 차단 아닌 기록이라
#   과잉 방향이 안전).
is_docs_only_audit_scope() {
  local rule_id="$1" files
  case "$rule_id" in
    R-1) files=$(git diff HEAD~1..HEAD --name-only --no-renames 2>/dev/null) || files="" ;;
    R-2) local base
         base=$(_detect_base_branch) || return 1
         files=$(git diff "$base"...HEAD --name-only --no-renames 2>/dev/null) ;;
    *) return 1 ;;
  esac
  _files_all_docs "$files"
}

# heredoc **본문**을 트리거 검사 입력에서 제거한다 (20260713-heredoc-false-block).
#
# 왜: Bash tool 의 command 는 흔히 멀티라인이고 `grep -E` 는 **줄 단위**로 검사한다 → 문서·테스트에 쓴
#   heredoc 본문의 git 예시가 **실제 명령으로 오인**되어 정직한 작업이 차단됐다(false-block, 실전 적발).
#   주석(`#`)·echo 는 선행자 클래스에 없어 안 걸리는데 heredoc 본문만 걸렸다. false-block 은 BYPASS 남발을
#   유발해 게이트 신호 자체를 희석한다.
# 범위: **입력만 전처리**한다. 트리거 정규식(rules.jsonl · pretool 인라인)은 무변경 — 정규식을 손대면
#   evasion 방어(PR #84·#112)가 흔들린다.
#
# ★ 실행자 판정 (F-3 표면 불변의 핵심): 시작 줄이 셸 실행자(bash·sh·zsh·ksh·dash·eval·exec·source)면
#   본문은 **실제로 셸에 실행되므로 제외하지 않는다**(passthrough). cat·tee·python3 등은 데이터로 보고 제외한다.
#   python3 본문은 셸 명령이 아니다 — 그 안의 subprocess git 호출은 **이미 F-3 wrapper-class**(WON'T-FIX)라
#   제외해도 표면이 넓어지지 않는다. 실측: 이 repo 는 `cat <<` 117건 · `python3 <<` 8건 · `bash <<` **0건**.
# ★ fail-safe (fail-open 아님): 미종료 heredoc · 한 줄 다중 heredoc · delimiter 파싱 불가 · awk 실패 →
#   **원본 반환** = 현재 동작(차단 우세)으로 후퇴. 제거 로직의 버그가 **차단을 뚫는 방향으로 작용하면 안 된다**.
#   애매하면 strip 하지 않는다 (정당한 차단이 뚫리는 것 > false-block).
# 지원 문법: `<<EOF` · `<<'EOF'` · `<<"EOF"` · `<<-EOF`(탭 들여쓰기 종료자). herestring(`<<<`)은 본문이 없어 무시.
# 이식성: POSIX awk 만 사용 (GNU 확장 match() 3인자 금지 — macOS bash 3.2/BSD awk).
_strip_heredoc_bodies() {
  local cmd="$1" out
  # 빠른 경로 — heredoc 연산자가 없으면 **바이트 동일** 반환 (기존 트리거 동작 완전 보존)
  case "$cmd" in
    *'<<'*) ;;
    *) printf '%s' "$cmd"; return 0 ;;
  esac
  out=$(printf '%s\n' "$cmd" | awk '
    BEGIN { inb=0; keep=0; dash=0; delim=""; bail=0; no=0; SQ=sprintf("%c",39); DQ=sprintf("%c",34) }
    { orig[NR]=$0
      if (bail) next
      if (inb) {                      # heredoc 본문 안
        t=$0
        if (dash) sub(/^\t+/,"",t)    # <<- 는 종료자의 선행 탭 허용
        if (t==delim) { inb=0; out[++no]=$0; next }   # 종료자 줄은 유지
        if (keep) out[++no]=$0        # 실행자 본문 = 실제 실행 → 유지
        next                          # 데이터 본문 → 제거
      }
      out[++no]=$0                    # 시작 줄은 항상 유지 (같은 줄의 `; git commit` 을 잡기 위해)
      probe=$0
      gsub(/<<</,"@@@",probe)         # herestring 마스킹 (길이 3 보존 → 위치 불변)
      cp=probe; nops=gsub(/<</,"x",cp)   # 치환결과 미사용 — gsub 반환값(연산자 개수)만 쓴다
      if (nops==0) next
      if (nops>1) { bail=1; next }    # 한 줄 다중 heredoc → 판정 포기(원본)
      if (!match(probe,/<<-?[ \t]*/)) { bail=1; next }
      dash=(substr(probe,RSTART+2,1)=="-")
      rest=substr(probe,RSTART+RLENGTH)
      q=substr(rest,1,1)
      if (q==SQ || q==DQ) {           # <<EOF 의 인용형: <<\047EOF\047 · <<"EOF"
        r2=substr(rest,2); p=index(r2,q)
        if (p<2) { bail=1; next }
        delim=substr(r2,1,p-1)
      } else if (match(rest,/^[A-Za-z_][A-Za-z0-9_]*/)) {
        delim=substr(rest,RSTART,RLENGTH)
      } else { bail=1; next }         # delimiter 파싱 불가 → 판정 포기(원본)
      # 실행자 판정은 **시작 줄 1줄**만 본다. 한계: 실행자가 줄-연속(백슬래시 개행)으로 시작 줄과 분리되면
      #   (bash 다음 줄에 <<EOF) 미탐지 → 본문 제외 → 통과. 실행자를 숨기려는 **의도적 난독화**이므로
      #   기존 F-3 wrapper-class(sh -c 등, 의도적 WONT-FIX)로 수용한다 — honest-mistake 경로가 없다.
      #   멀티라인 실행자 추적은 하지 않는다: 매 커밋에 도는 훅에 새 버그를 들이는 비용 > 그 표면의 값.
      keep=($0 ~ /(^|[ \t;&|(){}`])(bash|sh|zsh|ksh|dash|eval|exec|source)([ \t]|$)/) ? 1 : 0
      inb=1
    }
    END {
      if (bail || inb) { for(i=1;i<=NR;i++) print orig[i] }   # 미종료·판정 포기 → 원본 (fail-safe)
      else { for(i=1;i<=no;i++) print out[i] }
    }
  ' 2>/dev/null) || { printf '%s' "$cmd"; return 0; }   # awk 실패 → 원본 (fail-safe)
  [ -n "$out" ] || { printf '%s' "$cmd"; return 0; }    # 빈 출력(비정상) → 원본 (fail-safe)
  printf '%s' "$out"
}

# 인용 문자열 리터럴 본문을 트리거 검사 입력에서 제거한다 (20260717-quoted-falseblock).
#
# 왜: printf/echo 인자 등 **인용 문자열 안의 프로즈**("배포 후 (git commit 으로 기록)"·"build | git commit")에
#   든 셸 메타문자 선행자((·|)가 트리거와 오매칭 → 정직한 문서·코드 텍스트 작성이 차단됐다
#   (dogfood 20260717 test2 모델 backlog "R-1 블록주석 내부 오검출" — probe 로 실재 확정. heredoc 경로는
#   _strip_heredoc_bodies 가 이미 처리, 인라인 인용 인자가 잔여 표면이었다).
# 안전 불변식 (차단 우세 — heredoc strip 과 동일 철학):
#   - 싱글쿼트 본문: bash 가 절대 실행하지 않음 → 무조건 제거. eval/sh -c '...' wrapper 는 오늘도
#     트리거 미매칭(선행자 ' 는 클래스 밖 — F-3 WON'T-FIX 클래스)이라 제거해도 표면 불변.
#   - 더블쿼트 본문: $( ) 또는 백틱 포함 시 **실제 실행됨** → 그 문자열은 제거하지 않고 보존(deny 보존).
#   - 백슬래시: bash 인용 의미대로 처리(다음 1문자 verbatim — \" 가 인용 경계를 못 닫게). blanket-bail 로
#     하면 printf "%s\n" 류(실전 false-block 의 주 형태)가 전부 bail 돼 본 fix 가 무력화된다.
#   - bail(원본 반환): $'...' ANSI-C 인용 · 미종결 인용 · awk 실패 — 파싱 애매 시 현재
#     동작(차단 우세)으로 후퇴. 제거 로직 버그가 차단을 뚫는 방향으로 작용하면 안 된다.
# 이식성: POSIX awk (\x 이스케이프 금지 — SQ/DQ/BT 는 sprintf("%c",N), heredoc strip 선례).
_strip_quoted_strings() {
  local cmd="$1" out
  case "$cmd" in
    *"'"*|*'"'*) ;;
    *) printf '%s' "$cmd"; return 0 ;;   # 빠른 경로 — 인용 없음 = 바이트 동일
  esac
  out=$(printf '%s\n' "$cmd" | awk '
    BEGIN { SQ=sprintf("%c",39); DQ=sprintf("%c",34); BT=sprintf("%c",96); BS=sprintf("%c",92) }
    { lines[NR]=$0 }
    END {
      buf=""
      for(i=1;i<=NR;i++) buf = buf lines[i] (i<NR ? "\n" : "")
      if (index(buf, "$" SQ) > 0) { printf "%s", buf; exit }   # $\047...\047 ANSI-C → bail
      out=""; mode=0; dbuf=""; n=length(buf)
      for(i=1;i<=n;i++){
        ch=substr(buf,i,1)
        if(mode==0){
          if(ch==BS){ out=out ch; i++; if(i<=n) out=out substr(buf,i,1) }   # \x → 2문자 verbatim
          else if(ch==SQ){mode=1; out=out ch}
          else if(ch==DQ){mode=2; dbuf=""; out=out ch}
          else out=out ch
        } else if(mode==1){                       # 싱글쿼트 본문 — 제거 (bash: 내부 이스케이프 없음)
          if(ch==SQ){mode=0; out=out ch}
        } else {                                  # 더블쿼트 본문
          if(ch==BS){ dbuf=dbuf ch; i++; if(i<=n) dbuf=dbuf substr(buf,i,1) }   # \" 경계 오닫힘 방지
          else if(ch==DQ){
            mode=0
            if(index(dbuf,"$(")>0 || index(dbuf,BT)>0) out=out dbuf   # 실행 가능 → 보존
            out=out ch
          } else dbuf=dbuf ch
        }
      }
      if(mode!=0){ printf "%s", buf; exit }       # 미종결 인용 → 원본 (fail-safe)
      printf "%s", out
    }
  ' 2>/dev/null) || { printf '%s' "$cmd"; return 0; }
  [ -n "$out" ] || { printf '%s' "$cmd"; return 0; }
  printf '%s' "$out"
}

# transcript JSONL 에서 최근 N 개 tool_use 이벤트를 추출
# 출력: JSONL, 각 줄 { "index": <0-based>, "tool_name": "...", "input": {...} }
#   index = 필터된 tool_use 이벤트 배열의 0-based 위치 (raw JSONL line 아님)
# NOTE: --slurp 로 JSONL 전체 메모리 로드. v0.1 transcript 크기 (≤1MB 가정) 에서 허용.
# 대형 세션은 `jq -cs '.[-N:]'` → head-cut 선처리 고려 (후속 과제).
# usage: read_recent_tool_events <transcript_path> <max_count>
read_recent_tool_events() {
  local transcript="$1"
  local max="${2:-20}"
  [ -f "$transcript" ] || return 0
  jq -c --slurp --argjson max "$max" '
    [ .[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | { tool_name: .name, input: .input } ]
    | to_entries
    | map({ index: .key, tool_name: .value.tool_name, input: .value.input })
    | .[-$max:][]?
  ' "$transcript"
}

# .specops 가 symlink 면 비정상(악성 repo clone 시 외부 dir 로 write-through path-escape) — 쓰기 거부.
# fail-safe: symlink 면 1(거부), 정상 dir·부재(곧 mkdir)면 0.
_specops_dir_safe() { [ ! -L ".specops" ]; }

# per-FID 디렉토리 symlink 거부 (빈 fid → 무검사 통과). detect_fid 1차 차단 위 defense-in-depth.
_specops_fid_dir_safe() { [ -z "${1:-}" ] || [ ! -L ".specops/$1" ]; }

# friction-log append. FID 우선 fallback 전역.
# usage: log_friction <fid_or_empty> <rule_id> <principle> <evidence_snippet> <transcript_offset> [scope_class]
#   6번째 인자는 **선택**이다 (20260813-friction-staged-record) — 기존 5-인자 호출부는 무수정으로
#   종전과 byte-identical 한 레코드를 낸다(빈 값이면 필드 자체를 생략, AC-6·AC-7).
log_friction() {
  local fid="$1" rule_id="$2" principle="$3" snippet="$4" offset="$5" scope_class="${6:-}"
  _specops_dir_safe || { echo "log_friction: .specops 가 symlink — 쓰기 거부(path-escape 차단)" >&2; return 1; }
  if [ -n "$fid" ] && ! printf '%s' "$fid" | grep -Eq '^[0-9]{8}-[a-z0-9-]+$'; then
    echo "log_friction: invalid fid format" >&2
    return 1
  fi
  _specops_fid_dir_safe "$fid" || { echo "log_friction: .specops/$fid 가 symlink — 거부" >&2; return 1; }
  local target
  if [ -n "$fid" ]; then
    mkdir -p ".specops/$fid"
    target=".specops/$fid/friction-log.jsonl"
  else
    mkdir -p ".specops"
    target=".specops/friction-log.jsonl"
  fi
  # 파일 symlink 가드: 디렉토리(_specops_fid_dir_safe)는 통과해도 friction-log.jsonl
  # *파일* 자체가 symlink 면 >> 가 따라가 외부 path 누출 — append 전 차단.
  [ ! -L "$target" ] || { echo "log_friction: $target 가 symlink — 거부" >&2; return 1; }
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local fid_json
  if [ -n "$fid" ]; then
    fid_json="\"$fid\""
  else
    fid_json="null"
  fi
  local safe_snippet
  safe_snippet=$(printf '%s' "$snippet" | cut -c1-200)
  # dedup: 같은 rule_id + evidence_snippet 조합이 이미 존재하면 skip (stop hook 중복 실행 방지)
  if [ -f "$target" ] && jq -e --arg r "$rule_id" --arg s "$safe_snippet" \
       'select(.rule_id == $r and .evidence_snippet == $s)' "$target" >/dev/null 2>&1; then
    return 0
  fi
  jq -nc \
    --arg ts "$ts" \
    --argjson fid "$fid_json" \
    --arg rule_id "$rule_id" \
    --argjson principle "$principle" \
    --arg snippet "$safe_snippet" \
    --argjson offset "$offset" \
    --arg sc "$scope_class" \
    '{ ts: $ts, fid: $fid, rule_id: $rule_id, principle: $principle, severity: "warn", evidence_snippet: $snippet, transcript_offset: $offset }
     + (if $sc == "" then {} else {scope_class:$sc} end)' \
    >> "$target"
}

# log_friction 의 severity 파라미터화 변형 (기존 log_friction 무변경 — append).
# usage: log_friction_sev <fid> <rule_id> <principle> <snippet> <offset> <severity> [scope_class]
#   7번째 인자는 **선택** (20260813-friction-staged-record) — 빈 값이면 필드를 생략한다(AC-6).
log_friction_sev() {
  local fid="$1" rule_id="$2" principle="$3" snippet="$4" offset="$5" severity="${6:-warn}" scope_class="${7:-}"
  _specops_dir_safe || { echo "log_friction_sev: .specops 가 symlink — 쓰기 거부(path-escape 차단)" >&2; return 1; }
  [ -n "$fid" ] || return 0
  if ! printf '%s' "$fid" | grep -Eq '^[0-9]{8}-[a-z0-9-]+$'; then
    echo "log_friction_sev: invalid fid format" >&2; return 1
  fi
  _specops_fid_dir_safe "$fid" || { echo "log_friction_sev: .specops/$fid 가 symlink — 거부" >&2; return 1; }
  local target=".specops/$fid/friction-log.jsonl"
  mkdir -p ".specops/$fid" 2>/dev/null || return 0
  # 파일 symlink 가드 (log_friction 과 대칭) — friction-log.jsonl 파일 symlink 추종 차단.
  [ ! -L "$target" ] || { echo "log_friction_sev: $target 가 symlink — 거부" >&2; return 1; }
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local fid_json; fid_json=$(printf '%s' "$fid" | jq -R .)
  local safe_snippet; safe_snippet=$(printf '%s' "$snippet" | cut -c1-200)
  # dedup 비대칭(의도): block 항목끼리만 비교 — 기존 warn 줄(log_friction, severity 무시)과 공존 허용.
  # 정상 흐름(pretool deny → posttool 미실행 / bypass → block 미기록)에선 동일 snippet 에 둘이 안 생긴다.
  # 집계 로직이 severity 별 카운트 시 엣지에서 동일 snippet 이중계상 가능 — block 강제 기록 우선.
  if [ -f "$target" ] && jq -e --arg r "$rule_id" --arg s "$safe_snippet" \
       'select(.rule_id == $r and .evidence_snippet == $s and .severity == "block")' "$target" >/dev/null 2>&1; then
    return 0
  fi
  jq -nc --arg ts "$ts" --argjson fid "$fid_json" --arg rule_id "$rule_id" \
    --argjson principle "$principle" --arg snippet "$safe_snippet" \
    --argjson offset "$offset" --arg sev "$severity" --arg sc "$scope_class" \
    '{ ts:$ts, fid:$fid, rule_id:$rule_id, principle:$principle, severity:$sev,
       evidence_snippet:$snippet, transcript_offset:$offset }
     + (if $sc == "" then {} else {scope_class:$sc} end)' \
    >> "$target"
}

# rules.jsonl 에서 matcher + enabled:true 룰만 반환
# usage: load_rules <rules_path> <matcher>
load_rules() {
  local rules_path="$1" matcher="$2"
  [ -f "$rules_path" ] || return 0
  jq -c --arg m "$matcher" 'select(.enabled == true and .matcher == $m)' "$rules_path"
}

# lookback 룰 매처. trigger 일치 + negative_skill_pattern 이 직전 N 이벤트에 없으면 매칭.
# usage: apply_lookback_rule <rule_json> <transcript> <tool_name> <tool_command>
# 출력: 매칭 시 JSON { rule_id, evidence_snippet, offset }, 미매칭 시 빈 문자열
apply_lookback_rule() {
  local rule="$1" transcript="$2" tool_name="$3" tool_cmd="$4"
  local rule_id trigger_tool trigger_pattern lookback neg_pattern
  rule_id=$(echo "$rule" | jq -r '.id')
  trigger_tool=$(echo "$rule" | jq -r '.trigger_tool')
  [ "$tool_name" = "$trigger_tool" ] || return 0
  trigger_pattern=$(echo "$rule" | jq -r '.trigger_pattern')
  # heredoc 본문 제거 후 검사 (AC-7) — 정규식은 무변경, **입력만** 전처리한다.
  #   $tool_cmd 원본은 보존한다: 아래 evidence_snippet 은 모델이 실제로 낸 명령 전문을 남겨야 감사 가치가 있다.
  local _scan_cmd
  _scan_cmd=$(_strip_heredoc_bodies "$tool_cmd")
  _scan_cmd=$(_strip_quoted_strings "$_scan_cmd")
  printf '%s' "$_scan_cmd" | grep -Eq "$trigger_pattern" || return 0
  lookback=$(echo "$rule" | jq -r '.negative_lookback // 20')
  neg_pattern=$(echo "$rule" | jq -r '.negative_skill_pattern')
  # ★ 실행-근거 gate (20260713-verify-exec-gate): transcript 를 읽을 수 있으면, 어느 자기보고 신호가
  #   발화하든 실제 실행 증거를 요구한다. 자기보고 3경로(session-progress /verify PASS · evidence stamp ·
  #   Skill 호출)는 전부 **모델이 쓰는 것**이라, 검증했다고 착각한 모델이 선의로 게이트를 연다.
  #   #138 staleness 와 직교: staleness 는 "verify 가 충분히 최신인가", 본 gate 는 "verify 가 실제로 돌았나".
  #   ★ emit 은 기존 경로로 흘려보낸다(early-return 금지) — offset 계산을 선점하면 T6.e/f 회귀.
  # ★ detect_fid 는 아래에서 최대 2회 더 쓰인다(R-1 receipt 창·자기보고 면제). 훅 경로라
  #   지연이 체감에 직결돼(NFR-3) **1회만 부르고 재사용**한다 — 20260809 리뷰 지적.
  local _exec_rc _efid
  _efid=$(detect_fid 2>/dev/null || echo "")
  _verify_exec_evidence "$transcript" "${_efid:+.specops/$_efid}"; _exec_rc=$?

  # ★ R-1 implement 창: task receipt 필수 (Wave A — downstream-dogfood 병렬 wave BYPASS 관성 제거)
  #   tasks.md 존재 ∧ evidence.md 부재 = implement 창. FID 전체 VERIFY: PASS·실행증거 fallthrough 폐지.
  #   유효 receipt(staged⊆outputs·tree 신선·test_command hash)만 면제. T# 없음·부재·무효 → deny.
  #   evidence.md 이후(post-verify)는 아래 자기보고/Skill lookback. R-2 는 receipt 로 열지 않는다.
  if [ "$rule_id" = "R-1" ]; then
    local _rfid _rtask _rrc
    _rfid="$_efid"          # 위에서 1회 구한 값 재사용 (detect_fid 중복 호출 제거)
    if [ -n "$_rfid" ] && [ -f ".specops/$_rfid/tasks.md" ] && [ ! -f ".specops/$_rfid/evidence.md" ]; then
      _rtask=$(_infer_commit_task "$tool_cmd")
      _rrc=2
      if [ -n "$_rtask" ] && [ -f "$_CHECK_TASK_RECEIPT_SH" ]; then
        bash "$_CHECK_TASK_RECEIPT_SH" "$_rfid" "$_rtask" >/dev/null 2>&1
        _rrc=$?
      fi
      if [ "$_rrc" -eq 0 ]; then
        return 0
      fi
      local offset
      offset=$(jq -n --arg t "$trigger_tool" --arg pat "$trigger_pattern" '
        [inputs] as $all
        | ([ $all | to_entries[]
             | select(.value.type == "assistant")
             | select([.value.message.content[]? | select(.type == "tool_use" and .name == $t and ((.input.command // "") | test($pat)))] | any)
             | .key ] | last) // ($all | length)
      ' "$transcript" 2>/dev/null)
      [ -z "$offset" ] && offset=0
      jq -nc --arg id "$rule_id" --arg snippet "$tool_cmd" --argjson offset "$offset" \
        '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
      return 0
    fi
  fi

  # rc=0(실행증거 있음)·rc=2(판정 불가 — fail-open) 일 때만 자기보고 면제를 인정한다.
  # F-1(5c): session-progress verify 우선 — transcript lookback false-block 회피
  if [ "$_exec_rc" -ne 1 ]; then
    local _fid
    _fid="$_efid"           # 위에서 1회 구한 값 재사용 (detect_fid 중복 호출 제거)
    if [ -n "$_fid" ]; then
      _verify_passed_in_progress "$_fid"; local _vp=$?
      if [ "$_vp" -eq 0 ]; then
        return 0   # 유효 → 면제
      fi
      if [ "$_vp" -eq 1 ] && _verify_evidence_stamp "$_fid"; then
        return 0   # inconclusive(verify 줄 부재) + evidence stamp → 면제
      fi
      # _vp=2 (affirmative-stale) → stamp 무시, 차단 진행 (T39/spec L21 보존)
    fi
  fi
  local found=""
  if [ "$_exec_rc" -ne 1 ]; then
    found=$(read_recent_tool_events "$transcript" "$lookback" \
      | jq -c --arg p "$neg_pattern" 'select(.tool_name == "Skill" and (.input.skill // "" | test($p)))' \
      | head -1)
  fi
  if [ -z "$found" ]; then
    # triggering Bash tool_use 이벤트의 transcript 라인 번호 (0-based)
    # PostToolUse 는 현재 triggering 이벤트 직후 발화 → 마지막 매칭이 현재 이벤트
    # perf: 단일 jq 패스 — 줄단위 echo|jq fork 루프 제거 (2000줄 기준 수 초 → 수십 ms)
    local offset
    offset=$(jq -n --arg t "$trigger_tool" --arg pat "$trigger_pattern" '
      [inputs] as $all
      | ([ $all | to_entries[]
           | select(.value.type == "assistant")
           | select([.value.message.content[]? | select(.type == "tool_use" and .name == $t and ((.input.command // "") | test($pat)))] | any)
           | .key ] | last) // ($all | length)
    ' "$transcript" 2>/dev/null)
    [ -z "$offset" ] && offset=0
    jq -nc --arg id "$rule_id" --arg snippet "$tool_cmd" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-3 매처 — Skill 호출 직전 N assistant 메시지에 선언 부재 확인 (AC-9, v0.4-pre W1 확장)
# usage: apply_skill_declaration_rule <transcript> <skill_full_name>
# 선언 = 영문 "[Using|Invoking|Calling|Switching to] <short|full>" 또는
#        한국어 "<short> (을|를|로|으로)? (사용|호출|진입|이동|넘어감|시작|진행|발동|들어감|넘어가|개시)"
# short = skill_full_name 에서 "specops-ko:" 접두 제거
# v0.4-pre W1 변경 (마스터 plan §6 v0.4-pre):
# 1. 동사군 확장 (한국어 6 → 12, 영문 1 → 4)
# 2. lookback N=1 → N=3 assistant 메시지
# 3. user turn 첫 진입 예외 (직전 user 메시지에 /start 또는 트리거 키워드 있으면 면제)
# v0.4b W1 변경: full name (specops-ko:<short>) 패턴 추가 (cvt+b64 7건 회귀 원인)
# v0.5 W1 변경: lifecycle chain auto-call exempt — 직전 tool_use가 Skill(specops-ko:*)이면 면제
apply_skill_declaration_rule() {
  local transcript="$1" skill_full="$2"
  [ -f "$transcript" ] || return 0
  local short="${skill_full#specops-ko:}"
  # full name = specops-ko:<short>, short name = <short> — 둘 다 허용
  local name_re="(specops-ko:)?${short}"
  local decl_re="([Uu]sing[[:space:]]+${name_re}|[Ii]nvoking[[:space:]]+${name_re}|[Cc]alling[[:space:]]+${name_re}|[Ss]witching[[:space:]]+to[[:space:]]+${name_re}|${short}[[:space:]]*(을|를|로|으로)?[[:space:]]*(사용|호출|진입|이동|넘어감|시작|진행|발동|들어감|넘어가|개시))"
  # user turn 첫 진입 예외 트리거 (사용자 입력에 이 패턴이 있으면 첫 Skill 호출은 면제)
  local trigger_re='(/start|/quick|/free|만들[고어]|구현|추가|수정|fix|feature)'
  # perf: 단일 jq reduce 패스 — 줄단위 echo|jq fork ×4 루프 제거.
  # 상태: p1~p3(assistant text ring buffer, p1=최신), lu(마지막 user text),
  #       plc(직전 lifecycle skill — v0.5 chain 면제), matched/done/offset.
  # combined 구분자는 원 구현의 bash 리터럴 "\n"(역슬래시+n) 을 jq "\\n" 으로 보존.
  local res
  res=$(jq -nc --arg s "$skill_full" --arg decl "$decl_re" --arg trig "$trigger_re" '
    def utext: [.message.content // "" | if type == "string" then . else (.[]? | select(.type == "text") | .text) end] | first // "";
    def atext: [.message.content[]? | select(.type == "text") | .text] | join("\n");
    def has_target($s): [.message.content[]? | select(.type == "tool_use" and .name == "Skill" and .input.skill == $s)] | length > 0;
    def lc_skill: [.message.content[]? | select(.type == "tool_use" and .name == "Skill") | (.input.skill // "") | select(startswith("specops-ko:"))] | first // "";
    [inputs] as $all
    | reduce range(0; $all | length) as $i (
        {p1: "", p2: "", p3: "", lu: "", plc: "", matched: false, done: false, offset: 0};
        if .done then .
        else $all[$i] as $e
        | if ($e.type // "") == "user" then
            .lu = ($e | utext)
          elif ($e.type // "") != "assistant" then
            .
          elif ($e | has_target($s)) then
            .offset = ($i + 1)
            | .done = true
            | .matched = (
                if .plc != "" then false
                elif ((.p1 + "\\n" + .p2 + "\\n" + .p3) | test($decl)) then false
                elif (.lu != "" and (.lu | test($trig))) then false
                else true
                end)
          else
            (($e | lc_skill) as $l | if $l != "" then .plc = $l else . end)
            | (($e | atext) as $t
               | if $t != "" then .p3 = .p2 | .p2 = .p1 | .p1 = $t else . end)
          end
        end)
    | { matched, offset }
  ' "$transcript" 2>/dev/null)
  local matched offset
  matched=$(printf '%s' "$res" | jq -r '.matched' 2>/dev/null)
  offset=$(printf '%s' "$res" | jq -r '.offset' 2>/dev/null)
  [ -z "$offset" ] && offset=0
  if [ "$matched" = "true" ]; then
    jq -nc --arg id "R-3" --arg snippet "Skill($skill_full) 호출 전 선언 부재" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-4 매처 — transcript 에 assertion_pattern 존재 + test_runner_pattern 부재 → 매칭
# usage: apply_assertion_without_test_rule <rule_json> <transcript>
# 출력: 매칭 시 JSON { rule_id, evidence_snippet, offset }, 미매칭 시 빈 문자열
apply_assertion_without_test_rule() {
  local rule="$1" transcript="$2"
  [ -f "$transcript" ] || return 0
  local assertion_re test_runner_re
  assertion_re=$(echo "$rule" | jq -r '.assertion_pattern')
  test_runner_re=$(echo "$rule" | jq -r '.test_runner_pattern')
  # assertion 있는가? (assistant text 전수 조사)
  local has_assertion
  has_assertion=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' "$transcript" 2>/dev/null \
    | grep -Eo "$assertion_re" | head -1)
  [ -n "$has_assertion" ] || return 0
  # test runner 실행 있는가? (Bash tool_use input.command 전수 조사)
  local has_runner
  has_runner=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Bash") | .input.command // empty' "$transcript" 2>/dev/null \
    | grep -Eo "$test_runner_re" | head -1)
  if [ -z "$has_runner" ]; then
    # assertion 매칭된 가장 마지막 assistant text 이벤트의 라인 번호 (0-based)
    # Stop hook 이므로 최근 주장이 증거로 더 적합
    # perf: 단일 jq 패스 — 줄단위 echo|jq fork 루프 제거 (Stop 훅 매 발화 경로)
    local offset
    offset=$(jq -n --arg re "$assertion_re" '
      [inputs] as $all
      | ([ $all | to_entries[]
           | select(.value.type == "assistant")
           | select([.value.message.content[]? | select(.type == "text") | .text | test($re)] | any)
           | .key ] | last) // ($all | length)
    ' "$transcript" 2>/dev/null)
    [ -z "$offset" ] && offset=0
    jq -nc --arg id "R-4" --arg snippet "성공 주장 '$has_assertion' + test runner 실행 부재" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# advisor 실호출 증거 판정 (20260806) — R-5 자기보고 면제표 봉합
#
# advisor 는 **서버사이드 도구**라 transcript 에 일반 tool_use/tool_result 로 남지 않는다.
# 실측 기록 형태: assistant 메시지의 `server_tool_use`(name="advisor", id=srvtoolu_*) ↔
#   `advisor_tool_result`(tool_use_id 동일). 일반 tool_use 만 보던 코드로는 영원히 0건이라
#   이 형태를 직접 join 한다.
# critic-ask.sh 도 인정한다 — advisor 미연결 시의 **공식 fallback**(advisor-ko §외부 모델 위탁)이라
#   이를 불인정하면 정직한 미연결 세션이 위반으로 찍힌다.
# 반환: 0=실호출 증거 있음 / 1=없음 / 2=판정 불가(fail-open)
_advisor_exec_evidence() {
  local transcript="$1"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 2
  command -v jq >/dev/null 2>&1 || return 2
  local out
  out=$(jq -rn --slurpfile a "$transcript" '
    ([ $a[] | .message?.content? | select(type=="array") | .[] ]) as $blk
    # 이벤트 0건 = "호출 안 했다"와 "transcript 를 못 읽었다"를 구별 불가 → 판정 불가
    | ($blk | length) as $n
    | if $n == 0 then "UNKNOWN"
      else
        ([ $blk[] | select(.type=="server_tool_use" and .name=="advisor") | .id ]) as $calls
        | ([ $blk[] | select(.type=="advisor_tool_result" and (.is_error != true)) | .tool_use_id ]) as $oks
        | ([ $calls[] | select(. as $c | $oks | index($c)) ] | length) as $adv
        # critic-ask 공식 fallback
        | ([ $blk[] | select(.type=="tool_use" and .name=="Bash"
                             and ((.input.command // "") | test("critic-ask\\.sh"))) | .id ]) as $ccalls
        | ([ $blk[] | select(.type=="tool_result" and (.is_error != true)) | .tool_use_id ]) as $coks
        | ([ $ccalls[] | select(. as $c | $coks | index($c)) ] | length) as $crit
        | if ($adv + $crit) > 0 then "HIT" else "MISS" end
      end
  ' "$transcript" 2>/dev/null) || return 2
  case "$out" in
    HIT) return 0 ;;
    MISS) return 1 ;;
    *) return 2 ;;
  esac
}

# R-5 매처 — 세션 중 수정된 spec/plan/analysis md 의 Advisor 협의 기록 섹션 검사
# usage: apply_advisor_section_rule <rule_json> <transcript>
# PASS 조건: (a) 섹션 내 "해당 없음"(정직 선언 — 원칙 5) 또는
#            (b) data row 1+ **이면서** transcript 에 advisor/critic-ask 실호출 증거
# 매칭 조건: target_files 중 하나라도 위 PASS 조건 미충족
# 자기보고 봉합(20260806): 종전엔 data row 존재만으로 통과해 모델이 표를 쓰면 스스로 면제됐다.
#   R-1/R-2 실행-근거 게이트와 동형으로 "협의했다" 주장에는 실호출 증거를 요구한다.
#   판정 불가(rc=2)는 fail-open — 기존 관대 동작 유지.
apply_advisor_section_rule() {
  local rule="$1" transcript="$2"
  [ -f "$transcript" ] || return 0
  local target_files section_re
  target_files=$(echo "$rule" | jq -r '.target_files[]')
  section_re=$(echo "$rule" | jq -r '.advisor_section_pattern')
  # 세션 중 Edit/MultiEdit 된 파일 경로 추출 (Write는 신규 생성 — Advisor 섹션 불필요)
  local modified_files
  modified_files=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and (.name == "Edit" or .name == "MultiEdit")) | .input.file_path // empty' "$transcript" 2>/dev/null | sort -u)
  local match_result=""
  local fp bn is_target section_body data_rows has_hae
  # while-read — 공백 포함 경로 안전 (unquoted word-split 제거)
  while IFS= read -r fp; do
    [ -z "$fp" ] && continue
    bn=$(basename "$fp")
    is_target=0
    while IFS= read -r t; do
      [ "$bn" = "$t" ] && is_target=1
    done <<EOF_T
$target_files
EOF_T
    [ "$is_target" -eq 1 ] || continue
    [ -f "$fp" ] || continue
    # U1 R-5 trivial-skip: 동일 FID 의 spec.md §유형 라벨이 trivial 이면 본 파일 skip
    # specifying-ko 가 §1 개요에 자동 부여한 라벨 사용 (신규/유지보수/trivial).
    # spec.md 부재 시 보수적으로 기존 로직 진입 (false positive < silent pass).
    local _dir _spec _type_label
    _dir=$(dirname "$fp")
    _spec="$_dir/spec.md"
    if [ -f "$_spec" ]; then
      _type_label=$(grep -m1 '^\*\*§유형\*\*:' "$_spec" 2>/dev/null | sed 's/.*:[[:space:]]*//' | tr -d '[:space:]')
      if [ "$_type_label" = "trivial" ]; then
        continue
      fi
    fi
    # Advisor 섹션 본문 추출: section_re 이후 ~ 다음 ## 직전
    section_body=$(awk -v re="$section_re" '
      $0 ~ re { inside=1; next }
      inside && /^## / { exit }
      inside { print }
    ' "$fp")
    if [ -z "$section_body" ]; then
      match_result="섹션 부재: $fp"
      break
    fi
    # data row: | 로 시작, 헤더(`| 일시`)·구분선(`|---` 또는 `| --- |`) 제외
    data_rows=$(printf '%s\n' "$section_body" | grep -E '^\|' | grep -Ev '^\|[[:space:]]*-+' | grep -Ev '^\|[[:space:]]*일시[[:space:]]*\|' | wc -l | tr -d ' ')
    has_hae=$(printf '%s\n' "$section_body" | grep -c '해당 없음' | tr -d ' ')
    if [ "$data_rows" -eq 0 ] && [ "$has_hae" -eq 0 ]; then
      match_result="섹션 미충족: $fp"
      break
    fi
    # 협의를 **주장**하면(data row 1+, "해당 없음" 아님) 실호출 증거를 요구한다
    if [ "$data_rows" -gt 0 ] && [ "$has_hae" -eq 0 ]; then
      _advisor_exec_evidence "$transcript"
      case $? in
        1) match_result="협의 기록 있으나 advisor 실호출 증거 없음: $fp"; break ;;
        *) : ;;   # 0=증거 있음 · 2=판정 불가(fail-open)
      esac
    fi
  done <<EOF_M
$modified_files
EOF_M
  if [ -n "$match_result" ]; then
    # match_result 에 해당하는 파일 경로 추출 ("섹션 부재: <fp>" 또는 "섹션 미충족: <fp>")
    local matched_file=""
    if [[ "$match_result" == *": "* ]]; then
      matched_file="${match_result##*: }"
    fi
    # 첫 Edit/MultiEdit 이벤트 (target file 대상) 의 transcript 라인 번호 (0-based)
    # perf: 단일 jq 패스 — 줄단위 echo|jq fork 루프 제거.
    # 원 동작 보존: matched_file 비면 0, 매칭 파일은 있으나 이벤트 미발견이면 전체 라인 수.
    local offset=0
    if [ -n "$matched_file" ]; then
      offset=$(jq -n --arg p "$matched_file" '
        [inputs] as $all
        | ([ $all | to_entries[]
             | select(.value.type == "assistant")
             | select([.value.message.content[]? | select(.type == "tool_use" and (.name == "Edit" or .name == "MultiEdit") and .input.file_path == $p)] | any)
             | .key ] | first) // ($all | length)
      ' "$transcript" 2>/dev/null)
      [ -z "$offset" ] && offset=0
    fi
    jq -nc --arg id "R-5" --arg snippet "$match_result" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-6 매처 — transcript 에 verify skill + evidence.md Write 있고 gbrain-append 부재 시 매칭
# usage: apply_gbrain_absence_rule <rule_json> <transcript>
# 출력: 매칭 시 JSON { rule_id, evidence_snippet, offset, fid }, 미매칭 시 빈 문자열
# 매칭 알고리즘:
#   1. verify skill 호출 흔적 (전수 조사) 없으면 skip
#   2. 가장 최근 evidence.md Write 의 line 위치 추출 (last_evi_line). 없으면 skip
#   3. last_evi_line 이후 gbrain runner 호출 있는가? 있으면 PASS (skip)
#      — FR-6: multi-verify 환경에서도 가장 최근 evidence 이후만 본다
#   4. trivial-skip: evidence path 의 .specops/<FID>/spec.md 의 §유형 = trivial 이면 skip
#   5. FID 추출 + evidence_snippet 빌드 + JSON 반환
# 한계: trivial-skip(step 4) 의 spec.md lookup 은 transcript 에서 파생된 evidence path
#   (대개 상대경로 .specops/<FID>/evidence.md) 의 dirname 기준이라 **CWD 의존**이다.
#   훅이 plugin repo root 가 아닌 CWD 에서 실행되면 spec.md 를 못 찾아 trivial 판정이
#   누락(= 매칭 유지)될 수 있다. Stop 훅은 항상 repo root 에서 기동되므로 실사용엔 무해.
apply_gbrain_absence_rule() {
  local rule="$1" transcript="$2"
  [ -f "$transcript" ] || return 0
  local verify_skill_re evidence_path_re gbrain_runner_re
  verify_skill_re=$(echo "$rule" | jq -r '.verify_skill_pattern')
  evidence_path_re=$(echo "$rule" | jq -r '.evidence_path_pattern')
  gbrain_runner_re=$(echo "$rule" | jq -r '.gbrain_runner_pattern')

  # 1. verify skill 호출 흔적
  local has_verify
  has_verify=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Skill") | .input.skill // empty' "$transcript" 2>/dev/null \
    | grep -E "$verify_skill_re" | head -1)
  [ -n "$has_verify" ] || return 0

  # 2.+3. 가장 최근 evidence.md Write/Edit/Bash-invocation 위치 + 그 이후 gbrain runner 존재 여부
  # Edit 도 포함 — Claude 가 run-verification.sh append 후 헤더/AC 매핑 추가할 때 Edit 사용 (외부 review 후속 fix)
  # Bash 분기 — dogfood 경로 (bash scripts/_internal/run-verification.sh <FID>) invocation 도 evidence 의도 인정
  # perf: 단일 jq 패스 — transcript 2회 완주 + 줄단위 fork 루프 제거.
  # same-turn Write+Bash 의 Bash-우선 순서 (T-R6.17) 는 라인 내 bsynth 우선 평가로 보존.
  local res
  res=$(jq -nc --arg evire "$evidence_path_re" --arg grun "$gbrain_runner_re" '
    def wpath: [.message.content[]? | select(.type == "tool_use" and (.name == "Write" or .name == "Edit")) | (.input.file_path // "") | select(test($evire))] | first // "";
    def bsynth: [.message.content[]? | select(.type == "tool_use" and .name == "Bash") | (.input.command // "")
                 | (capture("bash[[:space:]]+(?:.*/)?run-verification\\.sh[[:space:]]+(?<fid>[^[:space:]]+)")? // empty)
                 | ".specops/" + .fid + "/evidence.md"
                 | select(test($evire))] | first // "";
    def grunner: [.message.content[]? | select(.type == "tool_use" and (.name == "Bash" or .name == "Skill")) | (.input.command // .input.skill // "") | select(test($grun))] | length > 0;
    [inputs] as $all
    | ($all | to_entries | map(select(.value.type == "assistant"))) as $ents
    | ([ $ents[] | { i: .key, p: ((.value | bsynth) as $b | if $b != "" then $b else (.value | wpath) end) } | select(.p != "") ] | last) as $evi
    | if $evi == null then { evi: -1, path: "", gb: false }
      else { evi: $evi.i, path: $evi.p, gb: ([ $ents[] | select(.key > $evi.i) | select(.value | grunner) ] | length > 0) }
      end
  ' "$transcript" 2>/dev/null)
  local last_evi_line last_evi_path has_gbrain_after
  last_evi_line=$(printf '%s' "$res" | jq -r '.evi' 2>/dev/null)
  last_evi_path=$(printf '%s' "$res" | jq -r '.path' 2>/dev/null)
  has_gbrain_after=$(printf '%s' "$res" | jq -r '.gb' 2>/dev/null)
  if [ -z "$last_evi_line" ] || [ "$last_evi_line" -lt 0 ]; then
    return 0
  fi
  [ "$has_gbrain_after" = "true" ] && return 0  # PASS — gbrain 호출 있음

  # 4. trivial-skip — evidence path 의 spec.md §유형 = trivial 이면 skip
  local fid_dir spec_path type_label
  fid_dir=$(dirname "$last_evi_path")
  spec_path="$fid_dir/spec.md"
  if [ -f "$spec_path" ]; then
    type_label=$(grep -m1 '^\*\*§유형\*\*:' "$spec_path" 2>/dev/null | sed 's/.*:[[:space:]]*//' | tr -d '[:space:]')
    [ "$type_label" = "trivial" ] && return 0
  fi

  # 5. FID 추출 (.specops/<FID>/evidence.md 패턴)
  local fid
  fid=$(echo "$last_evi_path" | sed -E 's|.*\.specops/([^/]+)/evidence\.md$|\1|')

  local snippet="lifecycle 완주 후 gbrain-append 호출 부재 — 1줄 인사이트 작성 권장: bash scripts/gbrain-append.sh '<insight>' --fid $fid"
  jq -nc --arg id "R-6" --arg snippet "$snippet" --argjson offset "$last_evi_line" --arg fid "$fid" \
    '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset, fid: $fid }'
}
