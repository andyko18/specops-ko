#!/usr/bin/env bash
# specops-auto-ko governance-capture 공용 함수 라이브러리
# source 로 로드하여 사용. 실행 파일 아님.
#
# Sourced library — strict mode 는 caller 에 위임 (set -u/-e 생략).
# Requires: jq 1.6+, bash 3.2+, coreutils (date, grep, sed, cut, mkdir).

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
_verify_exec_evidence() {
  local transcript="$1"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 2
  local out uses hits
  out=$(jq -rn --slurpfile a "$transcript" '
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
    # 마지막 코드 편집(비-.specops Edit/Write/NotebookEdit)의 전역 인덱스 (없으면 -1)
    | ([ range(0; $all) as $i
         | $tus[$i]
         | select(.name=="Edit" or .name=="Write" or .name=="NotebookEdit")
         | select((.input.file_path // "") | test("(^|/)\\.specops/") | not)
         | $i ] | max // -1) as $lastedit
    | (if $lasthit >= 0 and $lasthit > $lastedit then 1 else 0 end) as $h
    | "\($all) \($h)"
  ' 2>/dev/null) || return 2
  [ -z "$out" ] && return 2
  uses=${out%% *}; hits=${out##* }
  [ "$uses" -eq 0 ] 2>/dev/null && return 2   # tool_use 이벤트 0건 → 판정 불가 (증거 없음이 아님)
  [ "$hits" -gt 0 ] 2>/dev/null && return 0
  return 1
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
  local files
  files=$(git diff HEAD --name-only --no-renames 2>/dev/null)
  [ -z "$files" ] && files=$(git diff --cached --name-only --no-renames 2>/dev/null)
  if [ -z "$files" ]; then
    local base
    base=$(_detect_base_branch) || return 1
    files=$(git diff "$base"...HEAD --name-only --no-renames 2>/dev/null)
  fi
  [ -z "$files" ] && return 1
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

# posttool 감사 스코프 (20260718-posttool-audit-silence): 감사는 **방금 일어난 액션의 범위**를 본다 —
#   R-1(commit) = HEAD~1..HEAD(방금 커밋), R-2(pr create) = base...HEAD(PR 범위).
# 왜: working-tree 기준 is_docs_only_change 를 posttool 에 쓰면, 커밋 직후 잔여 dirty 가 거의 항상
#   tracked `.specops/session-progress.md` 뿐이라 .specops/* 면제(#214)에 걸려 **감사가 통째로 침묵**한다
#   (#214 이후 R-1 posttool warn 전 repo 0건의 실물 원인 — pretool block 만 남는 절반 가시성).
#   pretool 은 액션 前이라 working-tree 가 곧 커밋 범위 = 기존 함수가 정확하다(무변경).
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
# usage: log_friction <fid_or_empty> <rule_id> <principle> <evidence_snippet> <transcript_offset>
log_friction() {
  local fid="$1" rule_id="$2" principle="$3" snippet="$4" offset="$5"
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
    '{ ts: $ts, fid: $fid, rule_id: $rule_id, principle: $principle, severity: "warn", evidence_snippet: $snippet, transcript_offset: $offset }' \
    >> "$target"
}

# log_friction 의 severity 파라미터화 변형 (기존 log_friction 무변경 — append).
# usage: log_friction_sev <fid> <rule_id> <principle> <snippet> <offset> <severity>
log_friction_sev() {
  local fid="$1" rule_id="$2" principle="$3" snippet="$4" offset="$5" severity="${6:-warn}"
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
    --argjson offset "$offset" --arg sev "$severity" \
    '{ ts:$ts, fid:$fid, rule_id:$rule_id, principle:$principle, severity:$sev, evidence_snippet:$snippet, transcript_offset:$offset }' \
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
  local _exec_rc
  _verify_exec_evidence "$transcript"; _exec_rc=$?

  # rc=0(실행증거 있음)·rc=2(판정 불가 — fail-open) 일 때만 자기보고 면제를 인정한다.
  # F-1(5c): session-progress verify 우선 — transcript lookback false-block 회피
  if [ "$_exec_rc" -ne 1 ]; then
    local _fid
    _fid=$(detect_fid)
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
# short = skill_full_name 에서 "specops-auto-ko:" 접두 제거
# v0.4-pre W1 변경 (마스터 plan §6 v0.4-pre):
# 1. 동사군 확장 (한국어 6 → 12, 영문 1 → 4)
# 2. lookback N=1 → N=3 assistant 메시지
# 3. user turn 첫 진입 예외 (직전 user 메시지에 /start 또는 트리거 키워드 있으면 면제)
# v0.4b W1 변경: full name (specops-auto-ko:<short>) 패턴 추가 (cvt+b64 7건 회귀 원인)
# v0.5 W1 변경: lifecycle chain auto-call exempt — 직전 tool_use가 Skill(specops-auto-ko:*)이면 면제
apply_skill_declaration_rule() {
  local transcript="$1" skill_full="$2"
  [ -f "$transcript" ] || return 0
  local short="${skill_full#specops-auto-ko:}"
  # full name = specops-auto-ko:<short>, short name = <short> — 둘 다 허용
  local name_re="(specops-auto-ko:)?${short}"
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
    def lc_skill: [.message.content[]? | select(.type == "tool_use" and .name == "Skill") | (.input.skill // "") | select(startswith("specops-auto-ko:"))] | first // "";
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

# R-5 매처 — 세션 중 수정된 spec/plan/analysis md 의 Advisor 협의 기록 섹션 검사
# usage: apply_advisor_section_rule <rule_json> <transcript>
# PASS 조건: 섹션 내 data row 1+ 또는 "해당 없음" 문자열 존재 (Q-D 관대)
# 매칭 조건: target_files 중 하나라도 위 PASS 조건 미충족
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
