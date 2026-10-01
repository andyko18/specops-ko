#!/usr/bin/env bash
# check-task-ids.sh — task id 규격 게이트 (20261001-task-id-guard)
# Usage: check-task-ids.sh FID
# Exit: 0 = PASS 또는 SKIP · 1 = FAIL(규격 위반 id)
#
# 왜 필요한가: tasks.md 의 id 가 `T1a` 이면 커밋의 `Task: T1a` 가 hooks/governance-lib.sh `_infer_commit_task` 에서
#   `T1` 로 잘려 없는 receipt 를 찾고, R-1 implement 창의 receipt 탈출구가 열리지 않는다(사고 2회).
#   숫자 id 전제가 시스템 전반(hooks/save-review-report.sh 의 tid=T숫자)에 있어 정규식을 넓히지 않고 원천에서 막는다.
set -u
FID="${1:?usage: $0 FID}"
# ★ 경로는 `.specops` 로 **고정**한다 — SPECOPS_ROOT 를 읽으면 `SPECOPS_ROOT=/nonexistent` 한 줄로 tasks.md 부재 SKIP 이
#   되어 접미사 id 거부가 풀린다(env 면제 경로). emit-context.sh 도 `.specops/FID/tasks.md` 하드코딩이라 같은 근원을 본다.
TASKS=".specops/$FID/tasks.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

# 도입 cutoff — 이 날짜 미만 FID·비날짜 FID(fixture)는 면제한다. env override 를 두지 않는다
#   (모델이 스스로 여는 면제 경로는 §auto 자기발급 면제표와 같은 병이다).
CUTOFF=20261001
_d=${FID%%-*}
case "$_d" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
  *) echo "TASK-IDS: SKIP (비날짜 FID — fixture)"; exit 0 ;;
esac
[ "$_d" -lt "$CUTOFF" ] && { echo "TASK-IDS: SKIP (도입 전 FID — cutoff $CUTOFF)"; exit 0; }
[ -f "$TASKS" ] || { echo "TASK-IDS: SKIP (tasks.md 부재)"; exit 0; }

# shellcheck disable=SC1091
source "$PLUGIN/scripts/dag/parse-dag.sh"
yaml=$(dag::extract_yaml "$TASKS" 2>/dev/null)
[ -n "$yaml" ] || { echo "TASK-IDS: SKIP (YAML 부재 — id 규격 미검증)"; exit 0; }

verdict=$(SPECOPS_TI_YAML="$yaml" python3 - <<'PYEOF' 2>/dev/null
import os, re, yaml
try:
    doc = yaml.safe_load(os.environ["SPECOPS_TI_YAML"]) or {}
except Exception:
    print("PARSE_FAIL"); raise SystemExit(0)
tasks = doc.get("tasks") if isinstance(doc, dict) else None
if not isinstance(tasks, list):
    print("PARSE_FAIL"); raise SystemExit(0)
bad, n = [], 0
for t in tasks:
    if not isinstance(t, dict):
        continue
    n += 1
    raw = t.get("id")
    tid = "" if raw is None else str(raw)
    if not re.fullmatch(r"T[0-9]+", tid):
        bad.append(tid if tid else "(id 없음)")
print(("BAD:" + ", ".join(bad)) if bad else ("OK:%d" % n))
PYEOF
)
case "$verdict" in
  OK:*)  echo "TASK-IDS: PASS (${verdict#OK:} tasks)"; exit 0 ;;
  BAD:*) echo "TASK-IDS: FAIL — 숫자 전용(T1~Tn) 규격 위반: ${verdict#BAD:}"
         echo "  task id 는 T1, T2, T10 처럼 T 뒤 숫자만 쓴다. T1a 같은 접미사는 커밋의 'Task: T1a' 가 T1 로 잘려 R-1 receipt 탈출구가 열리지 않는다."
         echo "  해법: tasks.md 의 id 를 숫자 전용으로 재명명하고 emit-context 를 재실행하세요."
         exit 1 ;;
  *)     echo "TASK-IDS: SKIP (YAML 파싱 불가 — id 규격 미검증)"; exit 0 ;;
esac
