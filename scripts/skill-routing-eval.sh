#!/usr/bin/env bash
# skill-routing-eval.sh — 결정론 skill 라우팅 eval (FID 20261004-skill-routing-eval · warn-first · 토큰 0)
# skill description 간 tf-idf 코사인으로 충돌 후보·드리프트를 보고하고, trigger-queries 의 owner 라우팅을 참고 지표로 낸다.
# 사용: bash scripts/skill-routing-eval.sh [--skills-dir D] [--queries-dir D] [--baseline F] [--warn-pair X] [--drift-inc X]
#                                          [--strict] [--emit-baseline] [--dump-tokens TEXT]
#   기본: 경고만(rc 0) · --strict 면 PAIR-DRIFT ≥1 일 때 rc 1 · 입력 오류 rc 2 · jq 부재 SKIP rc 0
#   --emit-baseline: 현재 상태(임계 0.15 이상 쌍)의 기준선 JSON 을 stdout 으로만 출력(파일 무변경 — 갱신은 사람이 리다이렉트·커밋)
#   --dump-tokens TEXT: 토큰화 결과 출력(테스트·디버그용)
#   예외: --emit-baseline 은 jq 부재 시 SKIP(rc 0)이 아니라 rc 2(SKIP 문구가 기준선 파일에 섞이지 않게)
# df 상한: 문서의 50% 이상(df ≥ N/2)에 나오는 토큰은 제외한다(경계 포함 제외).
# 구현이 awk 가 아니라 jq 인 이유: macOS awk(20200816)·Ubuntu mawk 모두 length("가나다")=9(바이트 단위)라 한글 글자 bigram 이 불가하다(실측).
# 한계: description 은 한 줄만 지원(YAML block scalar `>`·`|` 는 rc 2 로 거부) · 조사 제거는 말미 1개 휴리스틱 · 임계값 미보정 — 절대값이 아니라 기준선 대비 변화를 본다. 질의↔description 코사인은 모델의 실제 라우팅과 다르다(참고용).
set -uo pipefail
export LC_ALL=C

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SKILLS_DIR="$PLUGIN/skills"
QUERIES_DIR="$PLUGIN/scripts/tests/llm-eval/skills"
BASELINE="$PLUGIN/scripts/tests/llm-eval/skill-routing-baseline.json"
WARN=0.20; INC=0.05; BASE_FLOOR=0.15; TOPK=5
STRICT=0; EMIT=0; DUMP=""; DUMP_SET=0

die() { echo "ERROR: $1" >&2; exit 2; }
_num() { case "$1" in ''|*[!0-9.]*|*.*.*|.) return 1 ;; *) return 0 ;; esac; }
while [ $# -gt 0 ]; do
  case "$1" in
    --skills-dir)   [ $# -ge 2 ] || die "--skills-dir 값 필요"; SKILLS_DIR="$2"; shift 2 ;;
    --queries-dir)  [ $# -ge 2 ] || die "--queries-dir 값 필요"; QUERIES_DIR="$2"; shift 2 ;;
    --baseline)     [ $# -ge 2 ] || die "--baseline 값 필요"; BASELINE="$2"; shift 2 ;;
    --warn-pair)    [ $# -ge 2 ] && _num "$2" || die "--warn-pair 는 0 이상 수여야 한다"; WARN="$2"; shift 2 ;;
    --drift-inc)    [ $# -ge 2 ] && _num "$2" || die "--drift-inc 는 0 이상 수여야 한다"; INC="$2"; shift 2 ;;
    --strict)       STRICT=1; shift ;;
    --emit-baseline) EMIT=1; shift ;;
    --dump-tokens)  [ $# -ge 2 ] || die "--dump-tokens 값 필요"; DUMP="$2"; DUMP_SET=1; shift 2 ;;
    -h|--help)      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)              die "알 수 없는 인자: $1" ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  # --emit-baseline 은 출력을 기준선 파일로 리다이렉트하므로 SKIP 문구가 파일에 들어가지 않게 오류(rc 2·stdout 비움)로 낸다
  [ "$EMIT" = 1 ] && die "jq 필요(--emit-baseline 은 jq 없이 불가)"
  echo "SKILL-ROUTING: SKIP (jq 필요)"; exit 0
fi

# ── jq 프로그램: 토큰화·tf-idf·코사인 ──
read -r -d '' DEFS <<'JQEOF' || true
def parts: ["에서는","으로는","에서","으로","까지","부터","에게","에는","이다","하는","하고","하며","한다","된다","은","는","이","가","을","를","의","에","와","과","로","도","만","및","시","등"];
def stem: . as $w | (parts | map(select(. as $p | (($w|length) > (($p|length) + 1)) and ($w|endswith($p)))) | .[0]) as $p
  | if $p then $w[0:(($w|length) - ($p|length))] else $w end;
def toks: ascii_downcase | [match("[가-힣]+|[a-z0-9]+(?:-[a-z0-9]+)*"; "g").string]
  | map(if test("^[가-힣]") then (stem as $w | if ($w|length) == 1 then [$w] else [range(0; ($w|length) - 1) as $i | $w[$i:($i+2)]] end) else [.] end)
  | add // [];
def tf: group_by(.) | map({key: .[0], value: length}) | from_entries;
def fmt: (. * 1000 | round) as $n | "\($n / 1000 | floor).\(("00" + ($n % 1000 | tostring))[-3:])";
def r3: (. * 1000 | round) / 1000;
JQEOF

if [ "$DUMP_SET" = 1 ]; then
  jq -n -r --arg t "$DUMP" "$DEFS"' ($t | toks | join(" "))'
  exit $?
fi

[ -d "$SKILLS_DIR" ] || die "skills 디렉터리 없음: $SKILLS_DIR"
TMP=$(mktemp -d) || die "mktemp 실패"
trap 'rm -rf "$TMP"' EXIT

# ── description 추출(frontmatter 첫 블록) ──
: > "$TMP/docs.tsv"; nskills=0
for f in "$SKILLS_DIR"/*/SKILL.md; do
  [ -f "$f" ] || continue
  name=$(basename "$(dirname "$f")")
  d=$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; next} n==1 && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f" | sed 's/^"\(.*\)"$/\1/')
  [ -n "$d" ] || die "description 누락: $name ($f)"
  [[ "$d" =~ ^[\>\|][-+0-9]*[[:space:]]*$ ]] && die "description 이 block scalar(한 줄만 지원): $name"
  printf '%s\t%s\n' "$name" "$d" >> "$TMP/docs.tsv"; nskills=$((nskills + 1))
done
[ "$nskills" -ge 2 ] || die "skill 이 2개 미만이다: $SKILLS_DIR"
jq -Rn '[inputs | split("\t") | {(.[0]): (.[1:] | join("\t"))}] | add' "$TMP/docs.tsv" > "$TMP/docs.json" || die "description 수집 실패"

# ── 질의(trigger-queries) ──
echo '[]' > "$TMP/q.json"
if [ -d "$QUERIES_DIR" ]; then
  : > "$TMP/q.ndjson"
  for qf in "$QUERIES_DIR"/*/trigger-queries.json; do
    [ -f "$qf" ] || continue
    jq -c 'select(type == "object") | . as $j | (($j.should_trigger // [])[] | {skill: $j.skill, kind: "pos", id: .id, query: .query}),
           (($j.should_not_trigger // [])[] | {skill: $j.skill, kind: "neg", id: .id, query: .query})' "$qf" >> "$TMP/q.ndjson" 2>"$TMP/q.err" \
      || die "trigger-queries 손상: $qf"
  done
  jq -s '.' "$TMP/q.ndjson" > "$TMP/q.json" 2>/dev/null || die "질의 수집 실패"
  jq -e 'all(.[]; (.skill | type == "string") and (.id | type == "string") and (.query | type == "string"))' "$TMP/q.json" >/dev/null 2>&1 \
    || die "trigger-queries 형식 오류(skill·id·query 문자열 필수): $QUERIES_DIR"
fi

# ── 기준선 ──
echo 'null' > "$TMP/base.json"
if [ "$EMIT" = 0 ] && [ -f "$BASELINE" ]; then
  jq -e '(.pairs | type) == "object" and all(.pairs[]; type == "number")' "$BASELINE" >/dev/null 2>&1 || die "기준선 손상: $BASELINE"
  cp "$BASELINE" "$TMP/base.json"
fi

# ── 본 계산 ──
read -r -d '' MAIN <<'JQEOF' || true
($docs[0]) as $D | ($D | keys) as $names | ($names | length) as $N
| (reduce ($names[] | $D[.] | toks | unique[]) as $t ({}; .[$t] += 1)) as $df
| def vec: tf | with_entries(select((($df[.key] // 0) as $d | $d > 0 and $d < ($N * 0.5))) | .value = ((1 + (.value | log)) * (($N / $df[.key]) | log)));
  def cos($a; $b): (($a | to_entries | map(.value * ($b[.key] // 0)) | add) // 0) as $dot
    | ((($a | [.[] | . * .] | add) // 0) | sqrt) as $na | ((($b | [.[] | . * .] | add) // 0) | sqrt) as $nb
    | if $na == 0 or $nb == 0 then 0 else $dot / ($na * $nb) end;
  ($names | map({key: ., value: ($D[.] | toks | vec)}) | from_entries) as $V
| [range(0; $N) as $i | range($i + 1; $N) as $j | {a: $names[$i], b: $names[$j], s: (cos($V[$names[$i]]; $V[$names[$j]]) | r3)}]
| sort_by([-.s, .a, .b]) as $pairs
| if $emit then
    {version: 1, pairs: ($pairs | map(select(.s >= $floor)) | map({key: "\(.a)~\(.b)", value: .s}) | from_entries)}
  else
    ($base[0]) as $B
    | ($pairs | map(select(.s >= $warn))) as $warns
    | ($pairs | map(. as $p | ($B.pairs["\($p.a)~\($p.b)"] // null) as $bs
        | select($B != null and (($bs == null and $p.s >= $warn) or ($bs != null and ((($p.s * 1000 | round) - ($bs * 1000 | round)) >= ($inc * 1000 | round)))))
        | . + {bs: $bs})) as $drifts
    | ([ "SKILL-ROUTING: skills=\($N) pairs=\($pairs | length) max=\($pairs[0].s | fmt) (\($pairs[0].a)~\($pairs[0].b)) warn>=\($warn | fmt) baseline=\(if $B == null then "없음" else "있음" end)" ]
      + ($warns | map("PAIR-WARN: \(.a) ~ \(.b) cos=\(.s | fmt)"))
      + (if $B == null then ["BASELINE: 없음 — drift 판정 생략"] else ($drifts | map("PAIR-DRIFT: \(.a) ~ \(.b) cos=\(.s | fmt) baseline=\(if .bs == null then "없음" else (.bs | fmt) end)")) + ["DRIFT: \($drifts | length)"] end)
      + ( ($q[0]) as $Q
        | if ($Q | length) == 0 then ["QUERY-ROUTING: 없음"] else
            ($Q | map(. as $x | ($x.query | toks | vec) as $qv
              | ($names | map({n: ., s: cos($qv; $V[.])})) as $sc
              | ([$sc[] | select(.n == $x.skill)] | .[0]) as $o
              | {skill: $x.skill, kind: $x.kind, id: $x.id,
                 rank: (if $o == null then null elif $o.s <= 0 then $N else (1 + ([$sc[] | select(.s > $o.s)] | length)) end),
                 top1: ($sc | sort_by([-.s, .n]) | .[0] | if .s > 0 then .n else "-" end)})) as $R
            | ($R | map(select(.kind == "pos"))) as $P | ($R | map(select(.kind == "neg"))) as $G
            | ["QUERY-ROUTING: pos=\($P | length) owner-rank1=\($P | map(select(.rank == 1)) | length) owner-top3=\($P | map(select(.rank != null and .rank <= 3)) | length) · neg=\($G | length) owner-rank1=\($G | map(select(.rank == 1)) | length)"]
              + ($P | sort_by([.skill, .id]) | map(select(.rank == null or .rank > $topk) | "QUERY-WARN: \(.skill) \(.id) owner-rank=\(.rank // "없음") top1=\(.top1)"))
          end )
      + ["NOTE: 조사 제거는 말미 1개 휴리스틱·임계 미보정 — 절대값이 아니라 기준선 대비 변화를 본다. 질의 지표는 참고용(모델 라우팅과 다름)."]
      ) | .[]
  end
JQEOF
if [ "$EMIT" = 1 ]; then
  jq -n -S --slurpfile docs "$TMP/docs.json" --slurpfile q "$TMP/q.json" --slurpfile base "$TMP/base.json" \
     --argjson warn "$WARN" --argjson inc "$INC" --argjson floor "$BASE_FLOOR" --argjson topk "$TOPK" --argjson emit true \
     "$DEFS $MAIN" || die "계산 실패"
  exit 0
fi
OUT=$(jq -n -r --slurpfile docs "$TMP/docs.json" --slurpfile q "$TMP/q.json" --slurpfile base "$TMP/base.json" \
     --argjson warn "$WARN" --argjson inc "$INC" --argjson floor "$BASE_FLOOR" --argjson topk "$TOPK" --argjson emit false \
     "$DEFS $MAIN") || die "계산 실패"
printf '%s\n' "$OUT"
DRIFTN=$(printf '%s\n' "$OUT" | sed -n 's/^DRIFT: \([0-9][0-9]*\)$/\1/p')
if [ "$STRICT" = 1 ] && [ "${DRIFTN:-0}" -ge 1 ]; then exit 1; fi
exit 0
