#!/usr/bin/env bash
# guard-map.sh — 가드 생존 맵: 가드 인벤토리 + 가드별 생존 증거(T·M·P) 표 (관측 전용 · 읽기 전용)
#
# 사용:
#   bash scripts/guard-map.sh                      # 표 + 요약 + 증거 약함 목록 + 한계 푸터
#   bash scripts/guard-map.sh --weak-only          # 증거 약함 목록만
#   bash scripts/guard-map.sh --repo <root>        # 대상 repo root 지정 (기본: 이 스크립트 위치 기준 repo)
#
# 가드 인벤토리(기계 추출 — 하드코딩 목록 없음):
#   rule      hooks/rules.jsonl 의 규칙 (id · enabled)
#   check     scripts/_internal/check-*.sh (가드명 = `check-` 와 `.sh` 를 뗀 이름)
#   structure scripts/_internal/validate-structure.sh 의 `emit <label>` 라벨 (실행하지 않고 정적 추출)
# 증거 종류(적용 가능한 것만 채우고 나머지는 `-`):
#   T 테스트   check: scripts/tests/**/test-<가드명>.sh 명명 일치 = 있음(명명) · 아니면 어떤 테스트 파일이든
#              스크립트 이름(`check-X`·`check-X.sh`)을 언급 = 있음(참조) · rule: id 언급 · structure: 라벨 언급
#   M 변이대상 check: scripts/tests/mutation-targets.conf 의 대상 열에 scripts/_internal/check-X.sh 가 있음
#   P 호출배선 check: propagation 원장(scripts/_internal/propagation-matrix.jsonl)에 호출처 파일을 가리키는 edge 의
#              must_match 가 가드명(`check-X`) 또는 그 스크립트 경로(`check-X.sh`)를 우변에 담아 **그 호출처 파일 안에서**
#              할당받은 `*_SH` 변수명(`X_SH="…check-X.sh"`)을 담음 — `*_SH` 가 아닌 일반 변수(CHK·Q·CP 등)는 풀지 않는다
#              (변수명을 여러 용도로 재사용하는 호출처가 있어 일반 변수를 이름만으로 풀면 오탐 위험이 크다).
#              호출처가 .md(skill·command) 면 근거에 `산문` 을 붙인다. 가드 스크립트 자기 자신만 잠그는 edge 는
#              `자기잠금` 으로 따로 표기하고 있음으로 세지 않는다.
# 칸 값: 있음(근거) · 없음 · 미측정(사유) · -(해당 없음) · 비활성(rules enabled:false) · 자기잠금(P 전용)
#   입력 파일 부재·파싱 불가·jq 부재는 해당 소스에 의존하는 칸을 미측정(사유) 로 표시한다 — 없음 으로 위장하지 않는다.
# 증거 약함: 적용 가능한 칸 중 판정 가능한 칸(미측정·비활성·`-` 제외 — 자기잠금은 판정 가능한 없음)에서 `있음` 이 1종 이하.
#   판정 가능한 칸이 하나도 없으면(전부 미측정) 판정에서 제외한다. 적용 증거가 1종뿐인 가드(rule·structure 는 T 뿐)는
#   약함 판정에서 제외하고 표·요약에 T 개수만 보인다(요약에 `판정 제외(적용 증거 1종)` 표기). 약함 판정은 check 에만 적용된다.
#
# 종료 코드(rc): 0 정상(증거 약함이 있어도 0 — 관측 도구) · 2 사용 오류(알 수 없는 옵션·--repo 값 부재 또는 빈 값·root 가 디렉터리 아님)
# 읽기 전용: 어떤 파일도 쓰거나 바꾸지 않는다(임시 파일은 mktemp -d 아래에만 만들고 EXIT trap 으로 삭제).
#   시각·세션 환경변수·실 ~/.claude 에 의존하지 않는다. awk 는 LC_ALL=C 로 돌려 gawk·mawk·BSD awk 출력이 같다.
# 소스 가능 — gm:: 함수만 정의, main 은 직접 실행일 때만 돈다.
#
# 한계: 증거 있음 ≠ 가드 작동 — 테스트 참조·원장 edge 는 존재만 본다. 가드 강도(차단/경고)는 판정하지 않는다.
#   인벤토리는 `check-*.sh`·rules.jsonl·`emit` 라벨뿐이다(명명 규약 밖 게이트·훅 deny 분기는 없음 — 출력 푸터에도 고지).
#   호출처 판정은 이름 언급(주석 포함)으로 하므로 호출처가 실제 호출인지는 보지 않는다.
# 엄격 모드(set -uo pipefail)는 gm::main 서브셸 첫 줄에서만 켠다 — source 한 호출자 셸로 새지 않게.

GM_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

gm::awk()  { LC_ALL=C awk "$@"; }
gm::sort() { LC_ALL=C sort; }

gm::usage() {
  cat <<'EOF'
사용: guard-map.sh [--weak-only] [--repo <root>]
  (옵션 없음)     가드 인벤토리 + 증거 표 + 요약 + 증거 약함 목록 + 한계
  --weak-only     증거 약함 목록만
  --repo <root>   대상 repo root (기본: 이 스크립트 위치 기준 repo)
  -h, --help      이 도움말
종료 코드: 0 정상 · 2 사용 오류
EOF
}

# ── 인벤토리 ────────────────────────────────────────────────────────────────

# rules.jsonl → "rule<TAB>id<TAB>state" (state: active|disabled|bad|nojq) · 파일 부재면 아무것도 내지 않는다
gm::inv_rules() {  # <root>
  local f="$1/hooks/rules.jsonl"
  [ -r "$f" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -Rr 'select(test("\\S")) | input_line_number as $n
      | (try (fromjson
              | if type == "object"
                then [ (.id // "?" | tostring), (if has("enabled") then (.enabled | tostring) else "true" end) ] | join("\t")
                else error("x") end)
         catch ("BAD\t" + ($n | tostring)))' "$f" 2>/dev/null |
      gm::awk -F'\t' '
        $1 == "BAD" { printf "rule\t줄%s\tbad\n", $2; next }
        { printf "rule\t%s\t%s\n", $1, ($2 == "false" ? "disabled" : "active") }'
  else
    gm::awk '
      /[^ \t]/ {
        id = "줄" NR
        if (match($0, /"id"[ \t]*:[ \t]*"[^"]*"/)) {
          id = substr($0, RSTART, RLENGTH); sub(/^"id"[ \t]*:[ \t]*"/, "", id); sub(/"$/, "", id)
        }
        printf "rule\t%s\tnojq\n", id
      }' "$f"
  fi
}

gm::inv_checks() {  # <root>
  local f b n
  for f in "$1"/scripts/_internal/check-*.sh; do
    [ -f "$f" ] || continue
    b=${f##*/}; n=${b#check-}; n=${n%.sh}
    printf 'check\t%s\tactive\n' "$n"
  done | gm::sort
}

gm::inv_structure() {  # <root> — emit <label> <OK|FAIL|SKIP|INFO> 의 라벨(첫 출현 순)
  local f="$1/scripts/_internal/validate-structure.sh"
  [ -r "$f" ] || return 0
  gm::awk '
    /^[ \t]*#/ { next }
    {
      s = $0
      while (match(s, /(^|[^A-Za-z0-9_])emit[ \t]+[a-z_][a-z0-9_]*[ \t]+[A-Z]+/)) {
        t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub(/^.*emit[ \t]+/, "", t); split(t, p, /[ \t]+/)
        if (!(p[1] in seen)) { seen[p[1]] = 1; printf "structure\t%s\tactive\n", p[1] }
      }
    }' "$f"
}

# ── 증거 소스 수집 (한 번씩) ───────────────────────────────────────────────

# 테스트 파일 목록(root 기준 상대경로, 정렬)
gm::test_files() {  # <root>
  [ -d "$1/scripts/tests" ] || return 0
  (cd "$1" && find scripts/tests -type f -name 'test-*.sh' 2>/dev/null) | gm::sort
}

# 호출처 후보 파일 목록 — 코드·산문(.sh .md .json · .githooks/*). 테스트·README 는 제외 (find 가 repo 루트의 CHANGELOG·CLAUDE 는 보지 않는다)
gm::callsite_files() {  # <root>
  (cd "$1" && find hooks scripts .githooks skills commands agents templates -type f \
      \( -name '*.sh' -o -name '*.md' -o -name '*.json' -o -path '.githooks/*' \) 2>/dev/null) |
    gm::awk '
      /^scripts\/tests\// { next }
      /(^|\/)README[^\/]*$/ { next }
      { print }' | gm::sort
}

# 공통 awk 조각: 한 줄을 단어(영숫자 _ . - 연속)로 쪼개 양끝의 . - 를 뗀다 → W[1..n], n 반환
GM_AWK_WORDS='
function words(s, W,    n, i, k, x, a) {
  n = split(s, a, /[^A-Za-z0-9_.-]+/); k = 0
  for (i = 1; i <= n; i++) {
    x = a[i]
    while (x != "" && (substr(x, 1, 1) == "." || substr(x, 1, 1) == "-")) x = substr(x, 2)
    while (x != "" && (substr(x, length(x), 1) == "." || substr(x, length(x), 1) == "-")) x = substr(x, 1, length(x) - 1)
    W[++k] = x
  }
  return k
}'

# 테스트 파일들에서 토큰(가드명·규칙 id·라벨)이 언급된 (토큰, 파일) 쌍 — 파일당 토큰 1회
gm::scan_mentions() {  # <root> <tokfile> <testlist>
  (cd "$1" && gm::awk -v TOK="$2" -v LIST="$3" "$GM_AWK_WORDS"'
    BEGIN {
      while ((getline t < TOK) > 0) if (t != "") tok[t] = 1
      close(TOK)
      while ((getline f < LIST) > 0) {
        delete seen
        while ((getline line < f) > 0) {
          n = words(line, W)
          for (i = 1; i <= n; i++) if ((W[i] in tok) && !(W[i] in seen)) { seen[W[i]] = 1; printf "%s\t%s\n", W[i], f }
        }
        close(f)
      }
    }')
}

# 호출처 후보 파일들에서 ① check-X(.sh) 언급 "C<TAB>name<TAB>file" ② `*_SH=…check-X.sh…` 할당(우변에 스크립트 경로) "A<TAB>file<TAB>var<TAB>name"
gm::scan_callsites() {  # <root> <checknames-file> <filelist>
  (cd "$1" && gm::awk -v NAMES="$2" -v LIST="$3" "$GM_AWK_WORDS"'
    BEGIN {
      while ((getline t < NAMES) > 0) if (t != "") chk[t] = 1
      close(NAMES)
      while ((getline f < LIST) > 0) {
        delete seen
        while ((getline line < f) > 0) {
          n = words(line, W)
          for (i = 1; i <= n; i++) {
            w = W[i]
            if (substr(w, 1, 6) != "check-") continue
            nm = substr(w, 7); sub(/\.sh$/, "", nm)
            if ((nm in chk) && !(nm in seen)) { seen[nm] = 1; printf "C\t%s\t%s\n", nm, f }
          }
          s = line
          sub(/^[ \t]+/, "", s); sub(/^(export|local|readonly)[ \t]+/, "", s)
          if (match(s, /^[A-Za-z_][A-Za-z0-9_]*_SH=/)) {
            var = substr(s, 1, RLENGTH - 1); val = substr(s, RLENGTH + 1)
            m = words(val, V)
            for (j = 1; j <= m; j++) {
              w = V[j]
              if (substr(w, 1, 6) != "check-" || w !~ /\.sh$/) continue
              nm = substr(w, 7); sub(/\.sh$/, "", nm)
              if (nm in chk) printf "A\t%s\t%s\t%s\n", f, var, nm
            }
          }
        }
        close(f)
      }
    }')
}

# 원장 edge → "id<TAB>path<TAB>must_match" · 파싱 불가 줄은 "BAD" 1줄 (jq 필요)
gm::ledger_edges() {  # <ledger>
  jq -Rr 'select(test("\\S"))
    | (try (fromjson | . as $r
            | if ($r | type) != "object" then error("x")
              else (($r.edges // [])[] | [ ($r.id // "?" | tostring), (.path // "" | tostring), (.must_match // "" | tostring) ] | @tsv) end)
       catch "BAD")' "$1" 2>/dev/null
}

# mutation-targets.conf → 대상 경로(첫 `|` 앞, 공백·./ 정리) 한 줄씩
gm::conf_targets() {  # <conf>
  gm::awk '
    {
      t = $0; sub(/\|.*/, "", t)
      sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); sub(/^\.\//, "", t)
      if (t != "") print t
    }' "$1"
}

# ── 조인: 가드 목록 + 증거 소스 → 칸 값 TSV (kind name T M P) ───────────────

gm::join() {  # <guards> <testlist> <mentions> <conf> <calls> <edges> <tests_ok> <conf_state> <ledger_state>
  gm::awk -v GUARDS="$1" -v TESTLIST="$2" -v MENT="$3" -v CONF="$4" -v CALLS="$5" -v EDGES="$6" \
    -v TESTS_OK="$7" -v CONF_STATE="$8" -v LEDGER_STATE="$9" "$GM_AWK_WORDS"'
  function is_call(p) {
    if (p ~ /^scripts\/tests\//) return 0
    if (p ~ /(^|\/)README[^\/]*$/) return 0
    if (p ~ /^\.githooks\//) return 1
    if (p !~ /^(hooks|scripts|skills|commands|agents|templates)\//) return 0
    return (p ~ /\.(sh|md|json)$/)
  }
  function cand(nm, rank, key, ev, prose) {
    if (!(nm in bestrank) || rank < bestrank[nm] || (rank == bestrank[nm] && key < bestkey[nm])) {
      bestrank[nm] = rank; bestkey[nm] = key; bestev[nm] = ev (prose ? "·산문" : "")
    }
  }
  function emit_row(g,    k, n, T, M, P) {
    k = gk[g]; n = gn[g]; M = "-"; P = "-"
    if (k == "rule") {
      if (gs[g] == "disabled") T = "비활성"
      else if (gs[g] == "bad") T = "미측정(파싱 불가)"
      else if (gs[g] == "nojq") T = "미측정(jq 부재)"
      else if (TESTS_OK != 1) T = "미측정(테스트 디렉터리 부재)"
      else T = (n in ment) ? "있음(참조)" : "없음"
    } else if (k == "structure") {
      if (TESTS_OK != 1) T = "미측정(테스트 디렉터리 부재)"
      else T = (n in ment) ? "있음(참조)" : "없음"
    } else {
      if (TESTS_OK != 1) T = "미측정(테스트 디렉터리 부재)"
      else if (("test-" n ".sh") in tname) T = "있음(명명)"
      else if ((("check-" n) in ment) || (("check-" n ".sh") in ment)) T = "있음(참조)"
      else T = "없음"
      if (CONF_STATE != "ok") M = "미측정(변이 conf 부재)"
      else M = (("scripts/_internal/check-" n ".sh") in conf) ? "있음(conf)" : "없음"
      if (LEDGER_STATE == "nojq") P = "미측정(jq 부재)"
      else if (LEDGER_STATE == "absent") P = "미측정(원장 부재)"
      else if (n in bestev) P = "있음(" bestev[n] ")"
      else if (n in selflock) P = "자기잠금"
      else if (LEDGER_STATE == "partial") P = "미측정(원장 일부 파싱 불가)"
      else if (callcnt[n] > 0) P = "없음"
      else P = "미측정(호출처 코드 없음)"
    }
    printf "%s\t%s\t%s\t%s\t%s\n", k, n, T, M, P
  }
  BEGIN {
    ng = 0
    while ((getline line < GUARDS) > 0) {
      split(line, f, "\t"); ng++; gk[ng] = f[1]; gn[ng] = f[2]; gs[ng] = f[3]
      if (f[1] == "check") chk[f[2]] = 1
    }
    close(GUARDS)
    while ((getline line < TESTLIST) > 0) { b = line; sub(/^.*\//, "", b); tname[b] = 1 }
    close(TESTLIST)
    while ((getline line < MENT) > 0) { split(line, f, "\t"); ment[f[1]] = 1 }
    close(MENT)
    while ((getline line < CONF) > 0) conf[line] = 1
    close(CONF)
    while ((getline line < CALLS) > 0) {
      split(line, f, "\t")
      if (f[1] == "C") { if (f[3] != "scripts/_internal/check-" f[2] ".sh") callcnt[f[2]]++ }
      else if (f[1] == "A") { k = f[2] SUBSEP f[3]; asg[k] = (k in asg) ? asg[k] " " f[4] : f[4] }
    }
    close(CALLS)
    while ((getline line < EDGES) > 0) {
      split(line, f, "\t"); path = f[2]; mm = f[3]
      sub(/^\.\//, "", path)
      self = ""
      if (path ~ /^scripts\/_internal\/check-[^\/]+\.sh$/) {
        self = path; sub(/^scripts\/_internal\/check-/, "", self); sub(/\.sh$/, "", self)
        selflock[self] = 1
      }
      if (!is_call(path)) continue
      prose = (path ~ /\.md$/) ? 1 : 0
      n = words(mm, W)
      for (i = 1; i <= n; i++) {
        w = W[i]
        if (substr(w, 1, 6) == "check-") {
          nm = substr(w, 7); sub(/\.sh$/, "", nm)
          if ((nm in chk) && nm != self) cand(nm, prose * 2, path " " w, "이름", prose)
        }
        k = path SUBSEP w
        if (k in asg) {
          m = split(asg[k], gl, " ")
          for (j = 1; j <= m; j++) if ((gl[j] in chk) && gl[j] != self) cand(gl[j], 1 + prose * 2, path " " w, "변수 " w, prose)
        }
      }
    }
    close(EDGES)
    for (g = 1; g <= ng; g++) emit_row(g)
  }'
}

# ── 렌더: 칸 값 TSV → 표·요약·증거 약함 ────────────────────────────────────

gm::render() {  # <cells-file> <weak-only 0|1> <notes-file>
  gm::awk -v CELLS="$1" -v WEAK_ONLY="$2" -v NOTES="$3" '
  # 표시 폭: UTF-8 한글(3바이트)=2칸 · 2바이트 문자=1칸 · ASCII=1칸 (LC_ALL=C 바이트 기준 — 세 awk 동일)
  function dw(s,    t, n) { t = s; n = gsub(/[\300-\357]/, "", t); return length(s) - n }
  function pad(s, w,    d, r) { d = dw(s); r = s; while (d < w) { r = r " "; d++ } return r }
  function cat(v) {
    if (v ~ /^있음/) return "Y"
    if (v ~ /^없음/ || v ~ /^자기잠금/) return "N"
    if (v ~ /^미측정/) return "U"
    return "D"
  }
  function kinds_for(k) { return (k == "check") ? "TMP" : "T" }
  BEGIN {
    nr = 0
    while ((getline line < CELLS) > 0) {
      split(line, f, "\t"); nr++
      rk[nr] = f[1]; rn[nr] = f[2]; c["T", nr] = f[3]; c["M", nr] = f[4]; c["P", nr] = f[5]
      cnt[f[1]]++
    }
    close(CELLS)
    nk = split("rule check structure", KO, " ")
    if (!WEAK_ONLY) {
      printf "인벤토리: rules %d · check %d · structure %d\n", cnt["rule"] + 0, cnt["check"] + 0, cnt["structure"] + 0
      while ((getline line < NOTES) > 0) if (line != "") print line
      close(NOTES)
      print "범례: T=테스트 M=변이 대상 등록 P=propagation 호출 배선 · 값 = 있음(근거) / 없음 / 미측정(사유) / - 해당 없음"
      print ""
    }
    for (i = 1; i <= nr; i++) {
      k = rk[i]; ks = kinds_for(k)
      y = 0; u = 0; jd = 0; lst = ""
      for (j = 1; j <= length(ks); j++) {
        col = substr(ks, j, 1); v = c[col, i]; ct = cat(v)
        if (v ~ /^비활성/) disn[k]++
        if (ct == "Y") { y++; lst = lst col }
        if (ct == "U") u++
        if (ct == "Y" || ct == "N") jd++
        tally[k, col, ct]++
        if (v ~ /^자기잠금/) selfl[k]++
      }
      Y[i] = y; U[i] = u; JD[i] = jd; LST[i] = (lst == "" ? "-" : lst)
      if (y >= 2) two++
      weak[i] = (length(ks) >= 2 && jd >= 1 && y <= 1) ? 1 : 0
      if (weak[i]) nweak++
    }
    if (!WEAK_ONLY) {
      w1 = dw("종류"); w2 = dw("가드"); w3 = 1; w4 = 1
      for (i = 1; i <= nr; i++) {
        if (dw(rk[i]) > w1) w1 = dw(rk[i])
        if (dw(rn[i]) > w2) w2 = dw(rn[i])
        if (dw(c["T", i]) > w3) w3 = dw(c["T", i])
        if (dw(c["M", i]) > w4) w4 = dw(c["M", i])
      }
      print pad("종류", w1) "  " pad("가드", w2) "  " pad("T", w3) "  " pad("M", w4) "  P"
      for (i = 1; i <= nr; i++)
        print pad(rk[i], w1) "  " pad(rn[i], w2) "  " pad(c["T", i], w3) "  " pad(c["M", i], w4) "  " c["P", i]
      print ""
      print "요약"
      for (a = 1; a <= nk; a++) {
        k = KO[a]; ks = kinds_for(k); n = cnt[k] + 0
        line = sprintf("- %-9s %d개", k, n)
        for (j = 1; j <= length(ks); j++) {
          col = substr(ks, j, 1)
          line = line sprintf(" | %s 있음 %d 없음 %d 미측정 %d - %d", col, tally[k, col, "Y"] + 0, tally[k, col, "N"] + 0, tally[k, col, "U"] + 0, tally[k, col, "D"] + 0)
        }
        extra = ""
        if (selfl[k] + 0 > 0) extra = extra sprintf(" 자기잠금 %d(없음에 포함)", selfl[k])
        if (disn[k] + 0 > 0) extra = extra sprintf(" 비활성 %d(-에 포함)", disn[k])
        if (extra != "") line = line " |" extra
        if (length(ks) < 2) line = line " | 판정 제외(적용 증거 1종)"
        print line
      }
      printf "- 가드 %d개 중 증거 2종 이상 %d개 · 증거 약함 %d개\n", nr, two + 0, nweak + 0
      print ""
    }
    printf "증거 약함 (적용 증거 2종 이상 가드(check) 중 판정 가능한 증거에서 있음 1종 이하 — 미측정 칸은 판정에서 제외): %d개\n", nweak + 0
    if (nweak + 0 == 0) print "  (없음)"
    for (i = 1; i <= nr; i++) if (weak[i])
      printf "  %s %s — 있음 %d/%d (%s) 미측정 %d\n", rk[i], rn[i], Y[i], JD[i], LST[i], U[i]
  }'
}

gm::footer() {
  cat <<'EOF'

한계
 ① 명명 규약 밖 게이트(release-ready.sh·reconcile-check.sh·batch-state.sh --gate 등)와 훅 deny 분기는 인벤토리에 없다.
 ② 테스트 `참조` 는 가드를 단언한다는 뜻이 아니다 — 증거 있음 ≠ 가드 작동.
 ③ 변이 점수는 직접 재계산하지 않는다 — M 은 mutation-targets.conf 등록 여부만 본다.
 ④ propagation edge 는 must_match 를 단어 단위로만 읽고 문자열 존재만 본다 — 교대(|)·glob·부정 정규식은 오탐·미탐이 날 수 있다.
EOF
}

# ── main ────────────────────────────────────────────────────────────────────

gm::main() (
  set -uo pipefail
  local root="" weak_only=0 missing="" tmp
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --weak-only) weak_only=1; shift ;;
      --repo)
        [ "$#" -ge 2 ] || { echo "guard-map: --repo 에 값이 없다" >&2; gm::usage >&2; return 2; }
        [ -n "$2" ] || { echo "guard-map: --repo 값이 비어 있다" >&2; gm::usage >&2; return 2; }
        root="$2"; shift 2 ;;
      -h|--help) gm::usage; return 0 ;;
      *) echo "guard-map: 알 수 없는 옵션/인자: $1" >&2; gm::usage >&2; return 2 ;;
    esac
  done
  [ -n "$root" ] || root=$(cd "$GM_HERE/.." && pwd)
  [ -d "$root" ] || { echo "guard-map: repo root 가 디렉터리가 아니다: $root" >&2; gm::usage >&2; return 2; }
  root=$(cd "$root" && pwd)

  tmp=$(mktemp -d "${TMPDIR:-/tmp}/guard-map.XXXXXX") || { echo "guard-map: 임시 디렉터리를 만들 수 없다" >&2; return 2; }
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  local have_jq=1 tests_ok=0 conf_state=ok ledger_state=ok
  command -v jq >/dev/null 2>&1 || have_jq=0
  [ -d "$root/scripts/tests" ] && tests_ok=1
  [ -r "$root/scripts/tests/mutation-targets.conf" ] || conf_state=absent
  local ledger="$root/scripts/_internal/propagation-matrix.jsonl"
  if [ "$have_jq" -ne 1 ]; then ledger_state=nojq
  elif [ ! -r "$ledger" ]; then ledger_state=absent
  fi

  { gm::inv_rules "$root"; gm::inv_checks "$root"; gm::inv_structure "$root"; } > "$tmp/guards.tsv"

  gm::test_files "$root" > "$tmp/tests.lst"
  gm::awk -F'\t' '$1 == "check" { print $2 }' "$tmp/guards.tsv" > "$tmp/checknames.txt"
  gm::awk -F'\t' '$1 == "check" { print "check-" $2; print "check-" $2 ".sh"; next } { print $2 }' "$tmp/guards.tsv" > "$tmp/tokens.txt"
  : > "$tmp/ment.tsv"; : > "$tmp/calls.tsv"; : > "$tmp/edges.tsv"; : > "$tmp/conf.txt"
  if [ -s "$tmp/tests.lst" ]; then gm::scan_mentions "$root" "$tmp/tokens.txt" "$tmp/tests.lst" > "$tmp/ment.tsv"; fi
  gm::callsite_files "$root" > "$tmp/callsite.lst"
  if [ -s "$tmp/callsite.lst" ]; then gm::scan_callsites "$root" "$tmp/checknames.txt" "$tmp/callsite.lst" > "$tmp/calls.tsv"; fi
  if [ "$conf_state" = ok ]; then gm::conf_targets "$root/scripts/tests/mutation-targets.conf" > "$tmp/conf.txt"; fi
  if [ "$ledger_state" = ok ]; then
    gm::ledger_edges "$ledger" > "$tmp/edges.raw"
    if grep -qx 'BAD' "$tmp/edges.raw"; then ledger_state=partial; fi
    grep -vx 'BAD' "$tmp/edges.raw" > "$tmp/edges.tsv" || true
  fi

  [ -r "$root/hooks/rules.jsonl" ] || missing="$missing hooks/rules.jsonl"
  [ -r "$root/scripts/_internal/validate-structure.sh" ] || missing="$missing validate-structure.sh"
  [ "$tests_ok" -eq 1 ] || missing="$missing scripts/tests"
  [ "$conf_state" = ok ] || missing="$missing mutation-targets.conf"
  [ "$ledger_state" != absent ] || missing="$missing propagation-matrix.jsonl"
  [ "$have_jq" -eq 1 ] || missing="$missing jq"
  [ "$ledger_state" != partial ] || missing="$missing propagation-matrix.jsonl(일부 파싱 불가)"
  : > "$tmp/notes.txt"
  if [ -n "$missing" ]; then printf '미측정 입력:%s\n' "$missing" > "$tmp/notes.txt"; fi

  gm::join "$tmp/guards.tsv" "$tmp/tests.lst" "$tmp/ment.tsv" "$tmp/conf.txt" "$tmp/calls.tsv" "$tmp/edges.tsv" \
    "$tests_ok" "$conf_state" "$ledger_state" > "$tmp/cells.tsv"
  gm::render "$tmp/cells.tsv" "$weak_only" "$tmp/notes.txt"
  if [ "$weak_only" -ne 1 ]; then gm::footer; fi
  return 0
)

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  gm::main "$@"
  exit $?
fi
