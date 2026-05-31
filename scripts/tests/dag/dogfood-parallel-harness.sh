#!/usr/bin/env bash
# dogfood-parallel-harness — DAG-AWARE PARALLEL dispatch 재실행 harness
#
# ⚠️⚠️ 정직성 라벨 (반드시 읽을 것) ⚠️⚠️
#   이 harness 의 핵심 가치 = implementing-ko L67-101 의 병렬 분기 "절차" 를
#   real parse-dag → worktree-per-leaf → 부모 git apply --index 머지 로 재현하는 것.
#
#   그러나 **dogfood 의 진짜 증명 — "단일 assistant 메시지에 implementer Agent 2개를
#   동시 emit 하는 병렬 dispatch" — 은 bash 로 검증 불가능하다** (LLM 은 bash 안에서 안 돎).
#   따라서:
#     • `run`  : 병렬 Agent step 을 **명시적 GAP** 으로 비워두고 안내만 출력 (실제 dogfood).
#                운영자/LLM 이 GAP 을 채운 뒤 `verify` 를 호출한다.
#     • `demo` : GAP 을 **bash 가 파일 작성으로 대체** 하여 setup→merge→teardown 을 자동
#                완주 (CI green 가능). 단 이는 **머지 합성(glue) 만 검증** — 병렬 dispatch
#                자체는 **검증하지 않는다**. 이 스크립트를 "parallel-dispatch 테스트" 라
#                부르지 말 것. 실제 병렬성 증명은 세션 transcript (case-study 참조) 에만 있다.
#
# Usage: dogfood-parallel-harness.sh {run|demo|verify|teardown}
set -u

CMD="${1:-}"
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
FIX="$SELF_DIR/fixtures/dogfood-parallel"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "git repo 아님" >&2; exit 1; }
WT1="$ROOT/.worktrees/dogfood-parallel-T1"
WT2="$ROOT/.worktrees/dogfood-parallel-T2"

_teardown() {
  git -C "$ROOT" reset -q HEAD fileA.sh fileB.sh 2>/dev/null || true
  rm -f "$ROOT/fileA.sh" "$ROOT/fileB.sh"
  git -C "$ROOT" worktree remove --force "$WT1" 2>/dev/null || true
  git -C "$ROOT" worktree remove --force "$WT2" 2>/dev/null || true
  git -C "$ROOT" branch -D dogfood-parallel-T1 dogfood-parallel-T2 2>/dev/null || true
}

_setup() {
  _teardown  # 이전 잔존 정리 (재실행 안전)
  # 1) real parse-dag 로 독립 batch 추출 — 병렬 자격 판정
  # shellcheck disable=SC1091
  source "$ROOT/scripts/dag/parse-dag.sh"
  local yaml batch
  yaml=$(dag::extract_yaml "$FIX/tasks.md")
  [ -n "$yaml" ] || { echo "FAIL: parse-dag yaml 추출 실패 (python3+pyyaml 필요)" >&2; return 1; }
  batch=$(dag::find_independent_batch "$yaml" | tr '\n' ' ')
  if ! dag::outputs_disjoint "$yaml" T1 T2; then
    echo "FAIL: T1·T2 outputs overlap — 병렬 자격 미충족" >&2; return 1
  fi
  echo "[setup] real parse-dag batch=[${batch% }] DISJOINT → DAG-AWARE PARALLEL 자격 충족"
  # 2) worktree-per-leaf (implementing-ko L71)
  git -C "$ROOT" worktree add -q "$WT1" -b dogfood-parallel-T1 || return 1
  git -C "$ROOT" worktree add -q "$WT2" -b dogfood-parallel-T2 || return 1
  echo "[setup] worktree: $WT1"
  echo "[setup] worktree: $WT2"
}

_verify_merge() {
  # 부모 머지 (implementing-ko L88-92): 각 worktree staged diff → git apply --index 순차
  local p1 p2
  p1=$(mktemp); p2=$(mktemp)
  git -C "$WT1" diff --cached > "$p1"
  git -C "$WT2" diff --cached > "$p2"
  if [ ! -s "$p1" ] || [ ! -s "$p2" ]; then
    echo "FAIL: leaf staged diff 비어있음 (GAP 미충족 — Agent 가 git add 안 함?)" >&2
    rm -f "$p1" "$p2"; return 1
  fi
  ( cd "$ROOT" && git apply --index "$p1" && git apply --index "$p2" ) || {
    echo "FAIL: git apply --index 머지 실패" >&2; rm -f "$p1" "$p2"; return 1; }
  rm -f "$p1" "$p2"
  if [ -f "$ROOT/fileA.sh" ] && [ -f "$ROOT/fileB.sh" ]; then
    echo "[verify] 양쪽 landing: $(bash "$ROOT/fileA.sh") / $(bash "$ROOT/fileB.sh")"
    echo "PASS: 2 leaf staged → git apply --index 합성 → 부모 worktree 양쪽 landing"
    return 0
  fi
  echo "FAIL: 산출물 landing 누락" >&2; return 1
}

case "$CMD" in
  run)
    _setup || exit 1
    cat <<EOF

══════════════════ 병렬 dispatch GAP (LLM/운영자가 채움) ══════════════════
  다음을 **단일 메시지에 2개 동시** dispatch 하라 (이것이 bash 로 검증 불가한 핵심):
    Agent#1: implementer → context $FIX/T1-context.md, worktree $WT1
    Agent#2: implementer → context $FIX/T2-context.md, worktree $WT2
  각 Agent 는 worktree 에서 파일 생성 + git add (commit 금지, R8).
  완료 후:  bash $0 verify
═══════════════════════════════════════════════════════════════════════════
EOF
    ;;
  demo)
    # ★ GAP 을 bash 가 대체 — 병렬 dispatch 미검증, 머지 glue 만 자동 완주
    _setup || { _teardown; exit 1; }
    echo "[demo] ⚠️ 병렬 Agent 대신 bash 가 파일 작성 (병렬성 미검증 — glue 만)"
    printf '#!/usr/bin/env bash\necho "leaf A output"\n' > "$WT1/fileA.sh"
    printf '#!/usr/bin/env bash\necho "leaf B output"\n' > "$WT2/fileB.sh"
    chmod +x "$WT1/fileA.sh" "$WT2/fileB.sh"
    git -C "$WT1" add fileA.sh; git -C "$WT2" add fileB.sh
    if _verify_merge; then _teardown; echo "[demo] teardown 완료 (git status clean 기대)"; exit 0
    else _teardown; exit 1; fi
    ;;
  verify)
    _verify_merge; rc=$?
    _teardown
    exit $rc
    ;;
  teardown)
    _teardown; echo "[teardown] worktree/branch/staged 정리 완료"
    ;;
  *)
    echo "Usage: $0 {run|demo|verify|teardown}" >&2
    echo "  run      — setup + 병렬 dispatch GAP 안내 (실제 dogfood; Agent 는 LLM 이 실행)" >&2
    echo "  demo     — GAP 을 bash 로 대체해 머지 glue 자동 완주 (CI green; 병렬성 미검증)" >&2
    echo "  verify   — worktree staged → git apply --index 머지 검증 + teardown" >&2
    echo "  teardown — 잔존 worktree/branch 정리" >&2
    exit 2
    ;;
esac
