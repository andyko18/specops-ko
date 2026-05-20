#!/usr/bin/env bash
# specops-auto-ko v0.4a W1 — DAG 파서 (Sourced library)
#
<<<<<<< HEAD
<<<<<<< HEAD
# 5 함수 namespace:
=======
# 4 함수 namespace:
>>>>>>> origin/feat/20260425-slug-cli
=======
# 4 함수 namespace:
>>>>>>> origin/feat/v0.4b
#   dag::extract_yaml      <tasks.md>                   — `## 의존 그래프` 섹션의 YAML fenced block stdout
#   dag::list_leaves       <yaml-string>                — depends_on=[] 인 task id (newline 구분)
#   dag::outputs_disjoint  <yaml-string> <id1> <id2>    — id1·id2 outputs 교집합 0이면 exit 0
#   dag::find_independent_batch <yaml-string>           — 절대 leaf 2개+ + outputs disjoint 인 batch (newline)
<<<<<<< HEAD
<<<<<<< HEAD
#   dag::get_task_test_command  <yaml-string> <task-id> — task 의 test_command 필드 (없으면 빈 + exit 0)  [Wave 2 U2]
=======
>>>>>>> origin/feat/20260425-slug-cli
=======
>>>>>>> origin/feat/v0.4b
#
# 의존성: python3 + pyyaml (기존 is-hook-enabled.sh, is-rule-enabled.sh와 동일 인프라)
# 참조: 마스터 plan §6 v0.4a W1 + advisor 협의 2026-04-26 13:00 (정정 채택)
#
# Sourced library — caller가 set -u/-e 제어. strict mode 위임.

# Python 의존 가드 — 부재 시 stderr 1회 경고 + 함수는 빈 문자열·exit 1 반환 (안전 fallback)
__dag_check_python() {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c "import yaml" 2>/dev/null; then
    if [ -z "${SPECOPS_DAG_WARNED:-}" ]; then
      echo "⚠️  dag::*: python3+pyyaml 미설치 — 모든 DAG 함수 빈 결과 (순차 fallback)" >&2
      export SPECOPS_DAG_WARNED=1
    fi
    return 1
  fi
  return 0
}

# dag::extract_yaml <tasks.md>
# `## 의존 그래프` 섹션 안의 ```yaml ... ``` fenced block 본문만 stdout
# 섹션 또는 yaml block 부재 시 빈 출력 + stderr WARN
dag::extract_yaml() {
  local md="$1"
  if [ ! -f "$md" ]; then
    echo "dag::extract_yaml: 파일 없음 — $md" >&2
    return 1
  fi
  # awk: ## 의존 그래프 헤더 발견 후 ```yaml ~ ``` 블록 추출
  awk '
    /^## 의존 그래프/ { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section && /^```yaml/ { in_yaml = 1; next }
    in_yaml && /^```/ { in_yaml = 0; exit }
    in_yaml { print }
  ' "$md"
}

# dag::list_leaves <yaml-string>
# YAML 입력에서 depends_on=[] 인 task id 만 newline 구분 출력
# YAML 파싱 실패 시 stderr WARN + 빈 출력 (fallback)
dag::list_leaves() {
  local yaml="$1"
  __dag_check_python || return 1
  SPECOPS_DAG_YAML="$yaml" python3 -c '
import os, sys, yaml
data = os.environ["SPECOPS_DAG_YAML"]
try:
    doc = yaml.safe_load(data) or {}
except Exception as e:
    sys.stderr.write(f"⚠️  dag::list_leaves: YAML 파싱 실패 ({e}) — fallback\n")
    sys.exit(0)
tasks = doc.get("tasks", []) or []
for t in tasks:
    if not isinstance(t, dict):
        continue
    deps = t.get("depends_on") or []
    if isinstance(deps, list) and len(deps) == 0:
        tid = t.get("id")
        if tid:
            print(tid)
'
}

# dag::outputs_disjoint <yaml-string> <id1> <id2>
# id1·id2 outputs 집합 교집합 0 + 같은 디렉터리 새 파일 추가도 disjoint=false (보수)
# disjoint이면 exit 0, overlap이면 exit 1
dag::outputs_disjoint() {
  local yaml="$1" id1="$2" id3="$3"
  __dag_check_python || return 1
  SPECOPS_DAG_YAML="$yaml" python3 -c '
import os, sys, yaml
id1, id2 = sys.argv[1], sys.argv[2]
data = os.environ["SPECOPS_DAG_YAML"]
try:
    doc = yaml.safe_load(data) or {}
except Exception:
    sys.exit(2)
tasks = {t["id"]: t for t in (doc.get("tasks") or []) if isinstance(t, dict) and "id" in t}
if id1 not in tasks or id2 not in tasks:
    sys.exit(2)
out1 = set(tasks[id1].get("outputs") or [])
out2 = set(tasks[id2].get("outputs") or [])
if out1 & out2:
    sys.exit(1)
sys.exit(0)
' "$id1" "$id3"
}

# dag::find_independent_batch <yaml-string>
# 절대 leaf (depends_on=[]) 만 후보 + 두 개씩 disjoint 검사 + 2개+ pair 발견 시 batch 출력
# 출력: id 들 newline 구분. batch 형성 못하면 빈 출력.
dag::find_independent_batch() {
  local yaml="$1"
  __dag_check_python || return 1
  SPECOPS_DAG_YAML="$yaml" python3 -c '
import os, sys, yaml
data = os.environ["SPECOPS_DAG_YAML"]
try:
    doc = yaml.safe_load(data) or {}
except Exception as e:
    sys.stderr.write(f"⚠️  dag::find_independent_batch: YAML 파싱 실패 ({e}) — fallback (빈 batch)\n")
    sys.exit(0)
tasks = {t["id"]: t for t in (doc.get("tasks") or []) if isinstance(t, dict) and "id" in t}
candidates = [tid for tid, t in tasks.items()
              if isinstance(t.get("depends_on"), list) and len(t.get("depends_on") or []) == 0]
if len(candidates) < 2:
    sys.exit(0)

def disjoint(a, b):
    out_a = set(tasks[a].get("outputs") or [])
    out_b = set(tasks[b].get("outputs") or [])
    if out_a & out_b:
        return False
    return True

batch = []
for cand in candidates:
    if all(disjoint(cand, b) for b in batch):
        batch.append(cand)
if len(batch) >= 2:
    for tid in batch:
        print(tid)
'
}
<<<<<<< HEAD
<<<<<<< HEAD

# dag::get_task_test_command <yaml-string> <task-id>
# task 의 test_command 필드 stdout (Wave 2 U2 — FID 20260514).
# 미기재·미존재·파싱실패 3 분기 모두 stderr 에 정확히 1줄 warn 출력 후 graceful exit 0 (AC-2 (b)).
dag::get_task_test_command() {
  local yaml="$1"
  local task_id="$2"
  __dag_check_python || return 1
  YAML_IN="$yaml" python3 - "$task_id" << 'PYEOF'
import os, sys, yaml
task_id = sys.argv[1]
try:
    data = yaml.safe_load(os.environ.get("YAML_IN", ""))
    for task in (data.get("tasks", []) if data else []):
        if task.get("id") == task_id:
            tc = task.get("test_command", "")
            if tc:
                print(tc)
            else:
                print(f"warn: task {task_id} test_command 미기재 — fallback", file=sys.stderr)
            sys.exit(0)
    # 미존재 task → 1 회 warn
    print(f"warn: task {task_id} 미존재 — fallback", file=sys.stderr)
    sys.exit(0)
except Exception as e:
    print(f"warn: dag::get_task_test_command 파싱 실패 ({e}) — fallback", file=sys.stderr)
    sys.exit(0)
PYEOF
}
=======
>>>>>>> origin/feat/20260425-slug-cli
=======
>>>>>>> origin/feat/v0.4b
