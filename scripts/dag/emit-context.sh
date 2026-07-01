#!/usr/bin/env bash
# specops-auto-ko Wave 2 U2 (FID 20260514) — dispatch-context.md 자동 산출
# Usage: emit-context.sh <FID>
#
# 동작:
#   1단계 dry-run: tasks.md YAML 파싱 → 모든 task 의 5섹션 값 검증
#     - ac 배열 비-빈 + AC.md 에 매칭 AC-id 존재
#     - inputs/outputs 존재 (빈 배열은 OK)
#     - test_command 비-빈
#   1건이라도 실패 → stderr 출력 + exit 1 + 디스크 작성 0
#   2단계 실제 작성: 모두 통과 시 dispatch/<task-id>-context.md × N 일괄 작성
#   출력: stdout "EMIT: N files" + exit 0
set -euo pipefail

FID="${1:?usage: $0 <FID>}"
[[ "$FID" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "emit-context: invalid FID — $FID" >&2; exit 1; }
TASKS=".specops/$FID/tasks.md"
AC=".specops/$FID/acceptance-criteria.md"
SPEC=".specops/$FID/spec.md"
DISPATCH=".specops/$FID/dispatch"

for f in "$TASKS" "$AC" "$SPEC"; do
  [ -f "$f" ] || { echo "emit-context: not found — $f" >&2; exit 1; }
done

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/parse-dag.sh"

yaml=$(dag::extract_yaml "$TASKS")
[ -n "$yaml" ] || { echo "emit-context: YAML 부재 — $TASKS" >&2; exit 1; }

# 1단계 dry-run 검증 (Python)
YAML_IN="$yaml" AC_PATH="$AC" python3 - << 'PYEOF' || exit 1
import os, sys, re, yaml
ac_path = os.environ["AC_PATH"]
data = yaml.safe_load(os.environ["YAML_IN"]) or {}
tasks = data.get("tasks", []) or []
if not tasks:
    print("emit-context: tasks 배열 비어있음", file=sys.stderr); sys.exit(1)

with open(ac_path, encoding="utf-8") as fh:
    ac_text = fh.read()
ac_ids = set(re.findall(r"AC-[A-Za-z0-9-]+", ac_text))

errors = []
for t in tasks:
    tid = t.get("id") or "<no-id>"
    tc = t.get("test_command", "")
    acs = t.get("ac", []) or []
    if not tc:
        errors.append(f"{tid}: test_command 미기재")
    if not acs:
        errors.append(f"{tid}: ac 배열 빈 값")
    for a in acs:
        if a not in ac_ids:
            errors.append(f"{tid}: {a} 가 acceptance-criteria.md 에 부재")
    if "inputs" not in t or "outputs" not in t:
        errors.append(f"{tid}: inputs/outputs 키 부재")
if errors:
    for e in errors:
        print(f"emit-context FAIL — {e}", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PYEOF

# 2단계 실제 작성
mkdir -p "$DISPATCH"
YAML_IN="$yaml" AC_PATH="$AC" SPEC_PATH="$SPEC" FID="$FID" DISPATCH_DIR="$DISPATCH" python3 - << 'PYEOF'
import os, re, yaml
ac_path = os.environ["AC_PATH"]
fid = os.environ["FID"]
disp = os.environ["DISPATCH_DIR"]
data = yaml.safe_load(os.environ["YAML_IN"]) or {}
tasks = data.get("tasks", []) or []

# AC.md 에서 각 AC-id 의 Given/When/Then 1줄 추출
with open(ac_path, encoding="utf-8") as fh:
    ac_text = fh.read()
def ac_summary(ac_id):
    m = re.search(rf"###\s+{re.escape(ac_id)}:?\s*(.*)", ac_text)
    return (m.group(1).strip() if m else "")[:120]

count = 0
for t in tasks:
    tid = t["id"]
    tc = t["test_command"]
    inputs = t.get("inputs", []) or []
    outputs = t.get("outputs", []) or []
    acs = t.get("ac", []) or []
    ac_lines = "\n".join(f"- {a}: {ac_summary(a)}" for a in acs)
    inputs_lines = "\n".join(f"- `{p}`" for p in inputs) or "- (없음)"
    whitelist = sorted(set(inputs) | set(outputs))
    wl_lines = "\n".join(f"- `{p}`" for p in whitelist)
    # §6 설계 계약 (design-first 후진 teeth — implementing 계약 준수 실배선).
    #   존재하는 설계 산출물만 emit, 부재 시 §6 자체 생략(graceful — 순수 로직/CLI 무영향).
    contract = [p for p in (".specops/memory/api-spec.md", ".specops/memory/data-model.md") if os.path.exists(p)]
    if os.path.isdir("screens"):
        contract.append("screens/")
    contract_section = ""
    if contract:
        cp_lines = "\n".join(f"- `{p}`" for p in contract)
        contract_section = (
            "\n## 6. 설계 계약 (design-first — 준수)\n\n"
            "> 이 task 가 인터페이스/스키마/화면을 건드리면 아래 설계 계약을 **준수**한다. "
            "어긋나야 하면 사용자 확인 필요 (verifying-evidence-ko memory 동기화 점검이 사후 검증).\n\n"
            f"{cp_lines}\n"
        )
    body = f"""<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: {fid} · task: {tid} -->

# Dispatch Context: {tid} (FID {fid})

## 1. 담당 AC

{ac_lines}

## 2. 관련 spec.md 섹션

- `.specops/{fid}/spec.md`
{inputs_lines}

## 3. 테스트 명령

```bash
{tc}
```

## 4. 수정 허용 파일 (whitelist)

{wl_lines}

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `<repo-root>/.worktrees/{fid}-{tid}/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
{contract_section}"""
    with open(os.path.join(disp, f"{tid}-context.md"), "w", encoding="utf-8") as fh:
        fh.write(body)
    count += 1
print(f"EMIT: {count} files")
PYEOF
