#!/usr/bin/env bash
# agent-spans.sh — 서브에이전트 transcript 에서 허용 필드만 뽑아 에이전트당 1줄을 낸다 (프라이버시 경계 · 읽기 전용)
# Usage: agent-spans.sh [--local] [--gap-cap-min N] agent-ID.jsonl...   (각 jsonl 옆의 agent-ID.meta.json 이 있으면 함께 읽는다)
# 출력(탭 구분, 에이전트당 1줄): 시작초 끝초 wall초 10분초과간격건수 그합초 방치상한초과간격건수 그합초 역할
#   wall = (끝 − 시작) − 방치 상한(--gap-cap-min, 기본 720분)을 넘는 내부 간격의 합. 10분(600초)을 넘되 상한 이하인 간격은 빼지 않고 건수·합만 센다(권한 대기·유휴 고백용).
#   역할 = meta 의 agentType — 단 toolUseId 가 비어 있지 않은 문자열이고 agentType 이 ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}$ 일 때만. 그 밖은 "-"(미분류).
#   시각이 있는 레코드가 하나도 없는 jsonl 은 줄을 내지 않는다.
# --local: epoch 대신 TZ 환경변수의 로컬 벽시계 초(jq localtime) — 원장(로컬 분)과 같은 기준으로 조인할 때 쓴다.
# rc: 0 · 2 = 인자 없음·알 수 없는 옵션·잘못된 값·읽을 수 없는 파일 · 3 = jq 없음
#
# 프라이버시 계약: jsonl 에서 읽는 키는 timestamp 뿐이고 meta 에서는 agentType·toolUseId 뿐이다(description·spawnDepth·본문은 참조하지 않는다).
#   출력은 파생값(숫자)과 형식 검사를 통과한 역할 이름뿐이고, 값 연산은 try 로 감싸며 jq 의 stderr 는 버린다(jq 오류 문구는 문제 값을 그대로 찍는다).
# 속도: jsonl 은 273MB 라 줄마다 JSON 을 파싱하는 데 약 4초가 든다 — 호출자(stage-timing.sh --by-agent)가 본 표 계산과 병렬로 돌린다.
#   줄 안에서 timestamp 문자열만 잘라 읽는 우회(index·slice)는 codepoint 오프셋 때문에 이득이 작고(실측 4.0초) 중첩 객체의 timestamp 키에 취약해 쓰지 않는다.
# 키: 에이전트는 파일 경로(확장자 앞 줄기)로 구분한다 — 같은 ID 가 다른 세션 폴더에 있어도 합쳐지지 않는다(T1.i).
# 한계: meta 파일은 끝 개행이 없어 jq 의 줄 읽기가 다음 파일과 이어 붙이므로 awk 로 파일 이름을 앞에 붙여 한 줄씩 넘긴다.
#   jsonl 은 jq 가 여러 파일을 이어 읽는다 — 끝 개행 없는 파일(기록 중인 활성 세션)의 마지막 줄은 다음 파일의 첫 줄과 합쳐져 둘 다 유실될 수 있다.
set -u
LOCAL=0; CAPMIN=720
while [ "$#" -gt 0 ]; do
  case "$1" in
    --local) LOCAL=1; shift ;;
    --gap-cap-min)
      [ "$#" -ge 2 ] && printf '%s' "$2" | grep -qE '^[1-9][0-9]*$' || { echo "agent-spans: --gap-cap-min 은 1 이상의 정수여야 합니다" >&2; exit 2; }
      CAPMIN="$2"; shift 2 ;;
    -*) echo "agent-spans: 알 수 없는 옵션" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ "$#" -ge 1 ] || { echo "usage: agent-spans.sh [--local] [--gap-cap-min N] agent-ID.jsonl..." >&2; exit 2; }
METAS=()
for f in "$@"; do
  { [ -f "$f" ] && [ -r "$f" ]; } || { echo "agent-spans: 읽을 수 없는 파일" >&2; exit 2; }
  [ -f "${f%.jsonl}.meta.json" ] && [ -r "${f%.jsonl}.meta.json" ] && METAS+=("${f%.jsonl}.meta.json")
done
command -v jq >/dev/null 2>&1 || { echo "agent-spans: jq 없음" >&2; exit 3; }

# JQ-META-BEGIN
ROLES=""
if [ "${#METAS[@]}" -gt 0 ]; then
  ROLES=$(awk '{ print FILENAME "\t" $0 }' "${METAS[@]}" 2>/dev/null | jq -Rr '
    index("\t") as $i
    | select($i != null)
    | (.[0:$i] | try capture("(?<id>.+)\\.meta\\.json$").id catch null) as $id
    | (.[$i + 1:] | try fromjson catch null) as $m
    | select($id != null and ($m | type) == "object")
    | ($m.agentType) as $a | ($m.toolUseId) as $u
    | [$id, (if ($a | type) == "string" and ($a | test("^[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}$")) and ($u | type) == "string" and ($u | length) > 0 then $a else "-" end)]
    | @tsv' 2>/dev/null)
fi
# JQ-META-END

# JQ-SPANS-BEGIN
jq -nRr --argjson loc "$LOCAL" --argjson cap "$((CAPMIN * 60))" --arg roles "$ROLES" '
  ($roles | split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}) as $role
  | reduce inputs as $l ({ts: {}};
      (input_filename | try capture("(?<id>.+)\\.jsonl$").id catch null) as $id
      | if $id == null then .
        else
          (($l | try fromjson catch null) | if type == "object" then (.timestamp | try (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch null) else null end) as $t
          | if $t == null then .
            else .ts[$id] += [(if $loc == 1 then ($t | localtime | mktime) else $t end)]
            end
        end)
  | .ts | to_entries[]
  | .key as $id | (.value | sort) as $s
  | ([range(1; $s | length) as $i | $s[$i] - $s[$i - 1]]) as $g
  | ([$g[] | select(. > $cap)]) as $x
  | ([$g[] | select(. > 600 and . <= $cap)]) as $b
  | [$s[0], $s[-1], (($s[-1] - $s[0]) - ($x | add // 0)), ($b | length), ($b | add // 0), ($x | length), ($x | add // 0), ($role[$id] // "-")]
  | @tsv' "$@" 2>/dev/null
# JQ-SPANS-END
