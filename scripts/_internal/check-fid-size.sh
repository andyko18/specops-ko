#!/usr/bin/env bash
# check-fid-size.sh — FID 스코프(태스크 수) 게이트 (20261007-fid-size-gate)
# Usage: check-fid-size.sh FID
# Exit: 0 = PASS·WARN·SKIP · 1 = FAIL
#
# 왜 필요한가: decomposing-ko `## FID 크기 규약` 의 "7개 이상 분할 계획행 의무 · 10개 이상 차단" 은 산문뿐이라
#   모델이 계획행을 빠뜨리거나 10+ 태스크로 구현에 들어가도 그대로 통과했다(실측: 10-태스크 FID 24h+ 정체).
#   emit-context 는 dispatch 직전의 원자적 게이트라 실패가 곧 implementing 진입 차단이다.
#
# 판정 (n = tasks.md YAML 의 task 수):
#   n ≤ 6                                  → PASS
#   n ≥ 7, 분할 계획행 없음                → FAIL (모드 무관)
#   7 ≤ n ≤ 9, 계획행 있음                 → WARN (통과 + FID-SIZE 경고)
#   n ≥ 10, 대화형                         → FAIL (계획행이 있어도 — FID 를 나눈 뒤 재진입)
#   n ≥ 10, §auto·§batch·foundation + 계획행 → WARN (분할할 사용자 채널이 없다 — 경고하고 진행)
#
# 예외 통과(≥10)는 FID 의 friction-log 에 `FID-SIZE-EXEMPT` 로 남긴다(자기발급 가능한 면제의 사용량 측정).
# 분할 계획행 = tasks.md 의 줄 선두 `**분할 계획**: <내용>` — 내용이 비었거나 템플릿 placeholder(`<…>` 통째)이거나
#   코드펜스(```) 안에 있으면 없는 것으로 본다. 내용의 질은 검사하지 않는다(비어 있지 않은 한 줄만 본다).
# 예외 라벨은 spec.md 의 **줄 선두** 표기만 인정한다 — 줄 중간 설명(`참고: **§auto** 모드…`)은 예외가 아니다
#   (test-branch-label-contract AC-R-2 와 같은 오탐 방지).
set -u
FID="${1:?usage: $0 FID}"
# ★ 경로는 `.specops` 로 **고정**한다 — SPECOPS_ROOT 를 읽으면 env 한 줄로 tasks.md 부재 SKIP 이 되어 게이트가 풀린다
#   (check-task-ids.sh 와 같은 근원). 면제용 env override 를 두지 않는다 — 모델이 스스로 여는 면제 경로는
#   §auto 자기발급 면제표와 같은 병이다.
TASKS=".specops/$FID/tasks.md"
SPEC=".specops/$FID/spec.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

# 도입 cutoff — 이 날짜 미만 FID·비날짜 FID(fixture)는 면제한다(소급 차단 금지).
CUTOFF=20261007
# 날짜 접두 = 앞 8자리 숫자 + (끝 | 비숫자) — `20261007_big`·`20261007x` 처럼 하이픈이 없어도 날짜 FID 로 본다(이름 변경 우회 차단).
case "$FID" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) _d=$FID ;;
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][!0-9]*) _d=${FID:0:8} ;;
  *) echo "FID-SIZE: SKIP (비날짜 FID — fixture)"; exit 0 ;;
esac
[ "$_d" -lt "$CUTOFF" ] && { echo "FID-SIZE: SKIP (도입 전 FID — cutoff $CUTOFF)"; exit 0; }
[ -f "$TASKS" ] || { echo "FID-SIZE: SKIP (tasks.md 부재)"; exit 0; }

# shellcheck disable=SC1091
source "$PLUGIN/scripts/dag/parse-dag.sh"
yaml=$(dag::extract_yaml "$TASKS" 2>/dev/null)
[ -n "$yaml" ] || { echo "FID-SIZE: SKIP (YAML 부재 — 태스크 수 미검증)"; exit 0; }

n=$(SPECOPS_FS_YAML="$yaml" python3 -E - <<'PYEOF' 2>/dev/null
import os, sys
# -E 는 PYTHON* env 만 막는다 — stdin 실행은 sys.path[0]='' 라 cwd 의 yaml.py 가 진짜 yaml 을 가린다. import 전에 cwd 를 뺀다
# (-I 는 user site-packages 까지 빼 pyyaml 을 못 찾고 SKIP 으로 열리므로 쓰지 않는다).
sys.path[:] = [p for p in sys.path if p not in ("", ".")]
import yaml
try:
    doc = yaml.safe_load(os.environ["SPECOPS_FS_YAML"]) or {}
except Exception:
    print("PARSE_FAIL"); raise SystemExit(0)
tasks = doc.get("tasks") if isinstance(doc, dict) else None
if not isinstance(tasks, list):
    print("PARSE_FAIL"); raise SystemExit(0)
print(len(tasks))
PYEOF
)
case "$n" in
  ''|*[!0-9]*) echo "FID-SIZE: SKIP (YAML 파싱 불가 — 태스크 수 미검증)"; exit 0 ;;
esac

[ "$n" -le 6 ] && { echo "FID-SIZE: PASS ($n tasks)"; exit 0; }

has_plan=no
awk '
  /^[[:space:]]*```/ { fence = !fence; next }
  !fence && /^\*\*분할 계획\*\*:/ {
    c = $0; sub(/^\*\*분할 계획\*\*:[[:space:]]*/, "", c); sub(/[[:space:]\r]+$/, "", c)
    if (c != "" && !(c ~ /^<.*>$/)) found = 1
  }
  END { exit found ? 0 : 1 }' "$TASKS" 2>/dev/null && has_plan=yes

exempt=""
if [ -f "$SPEC" ]; then
  if grep -qE '^\*\*§batch\*\*:[[:space:]]*[^[:space:]]' "$SPEC" 2>/dev/null; then exempt="§batch"
  elif grep -qE '^\*\*§auto\*\*:[[:space:]]*true[[:space:]]*$' "$SPEC" 2>/dev/null; then exempt="§auto"
  elif grep -qE '^\*\*§유형\*\*:[[:space:]]*foundation' "$SPEC" 2>/dev/null; then exempt="foundation"
  fi
fi

_warn_line="⚠️ FID-SIZE: $n 태스크 (권장 ≤6) — 다중 세션에 걸칠 수 있음. 중간 이탈 시 재개는 /status (reconcile) 로."

if [ "$has_plan" = no ]; then
  echo "FID-SIZE: FAIL — $n 태스크(권장 ≤6)인데 tasks.md 에 분할 계획행이 없다."
  echo "  tasks.md 끝에 \`**분할 계획**: <어느 태스크까지 이번 FID, 나머지는 후속 FID 후보>\` 1행을 기재하세요(줄 선두)."
  [ "$n" -ge 10 ] && [ -z "$exempt" ] && echo "  $n 태스크(≥10)는 대화형에서 FID 분할 없이 구현에 진입할 수 없다 — 수직 슬라이스로 FID 를 나눈 뒤 decomposing 재진입."
  exit 1
fi

if [ "$n" -ge 10 ]; then
  if [ -z "$exempt" ]; then
    echo "FID-SIZE: FAIL — $n 태스크(≥10)는 대화형에서 FID 분할 없이 구현에 진입할 수 없다."
    echo "  수직 슬라이스(각자 독립 shippable)로 FID 를 나눈 뒤 decomposing 재진입. 분할 계획행만으로는 열리지 않는다."
    exit 1
  fi
  # 예외 라벨은 모델이 쓰는 spec.md 표기라 자기발급이 가능하다 — 막지 못하는 대신 **사용을 기록**해 남용을 측정 가능하게 한다
  #   (v2.3.0 면제 남용 기록 3종과 같은 접근). 기록 실패·lib 부재는 판정에 영향이 없다(부수효과). dedup 은 log_friction 이 한다.
  ( [ -f "$PLUGIN/hooks/governance-lib.sh" ] \
    && . "$PLUGIN/hooks/governance-lib.sh" 2>/dev/null \
    && declare -F log_friction >/dev/null 2>&1 \
    && log_friction "$FID" "FID-SIZE-EXEMPT" 2 "$exempt 예외로 $n 태스크 통과 (분할 계획행 기재)" 0 ) >/dev/null 2>&1 || true
  echo "FID-SIZE: WARN ($n tasks, $exempt 예외 — 분할 불가라 차단 대신 경고)"
  echo "$_warn_line"
  exit 0
fi

echo "FID-SIZE: WARN ($n tasks, 분할 계획행 있음)"
echo "$_warn_line"
exit 0
