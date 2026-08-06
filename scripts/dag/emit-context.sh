#!/usr/bin/env bash
# specops-ko Wave 2 U2 (FID 20260514) — dispatch-context.md 자동 산출
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

# foundation 재사용 게이트 (소비측) — 구현 **전** fail-fast.
#   decomposing-ko 계약: §유형≠foundation 이고 manifest 가 있으면 각 task 가
#   `**재사용 foundation**` 또는 `**미재사용 근거**` 를 기재해야 한다. 종전엔 산문뿐이라
#   모델이 안 쓰면 그대로 통과했다 — 공통부를 만들고 아무도 안 쓰는 상태가 조용히 지나간다.
#   여기 배선한 이유: emit-context 는 dispatch 직전의 원자적 게이트라, 실패가 곧
#   implementing 진입 차단이다(디스크 작성 0 — 다른 검증과 동일 원자성).
_REUSE_SH="$SCRIPT_DIR/../_internal/check-foundation-reuse.sh"
if [ -f "$_REUSE_SH" ]; then
  if ! reuse_out=$(bash "$_REUSE_SH" "$FID" 2>&1); then
    printf '%s\n' "$reuse_out" >&2
    echo "emit-context: foundation 재사용 선언 누락 — tasks.md 보완 후 재실행" >&2
    exit 1
  fi
fi

# 유지보수 baseline 게이트 — analyzing 산출물(current-state·impact-analysis) 존재·채움.
#   analyzing-ko HARD-GATE 의 기계화 가능 부분. 부재 시 AC-R-1 근거가 없고,
#   check-regression-ac 의 스키마 override 판정이 current-state.md 를 읽으므로
#   파괴적 스키마 변경에도 AC-R-2 가 요구되지 않는다(안전망 무음 해제).
_MBASE_SH="$SCRIPT_DIR/../_internal/check-maintain-baseline.sh"
if [ -f "$_MBASE_SH" ]; then
  if ! mbase_out=$(bash "$_MBASE_SH" "$FID" 2>&1); then
    printf '%s\n' "$mbase_out" >&2
    echo "emit-context: 유지보수 baseline 부재 — analyzing-ko 선행 후 재실행" >&2
    exit 1
  fi
fi

# 회귀 AC 게이트 — §유형=유지보수 는 AC-R-1, 스키마 override 는 AC-R-2 (독립 조건).
#   "/maintain 의 존재 이유" 인 회귀 안전망이 산문뿐이었다(템플릿의 "evaluator BLOCK" 주장에
#   구현 0곳). 템플릿이 AC-R 섹션을 기본 포함하므로 채움(placeholder 잔존)까지 판정한다.
_REGAC_SH="$SCRIPT_DIR/../_internal/check-regression-ac.sh"
if [ -f "$_REGAC_SH" ]; then
  if ! regac_out=$(bash "$_REGAC_SH" "$FID" 2>&1); then
    printf '%s\n' "$regac_out" >&2
    echo "emit-context: 회귀 AC(AC-R) 누락·미채움 — acceptance-criteria.md 보완 후 재실행" >&2
    exit 1
  fi
fi

# AC 필드 게이트 (20260807 OpenSpec 갭분석 G1) — **아래 must 커버리지 검사의 전제**.
#   그 검사는 `**우선순위**: must` 가 있는 AC 만 대상으로 삼는다(하위호환 fail-open).
#   필드가 없으면 must_ids=[] 가 되어 검사가 무음으로 꺼지므로, 스위치의 존재를 먼저 강제한다.
#   실측 20260807: AC 픽스처 7개 중 6개가 우선순위 0건 — 그 문서들에선 검사가 죽어 있었다.
_ACFMT_SH="$SCRIPT_DIR/../_internal/check-ac-format.sh"
if [ -f "$_ACFMT_SH" ]; then
  if ! acfmt_out=$(bash "$_ACFMT_SH" "$FID" 2>&1); then
    printf '%s\n' "$acfmt_out" >&2
    echo "emit-context: AC 필드 미충족 — acceptance-criteria.md 보완 후 재실행" >&2
    exit 1
  fi
  printf '%s\n' "$acfmt_out" | grep '^AC-FORMAT: WARN' >&2 || true
fi

# foundation 기술스택 확정 증거 (clarify 층 봉합).
#   clarify 단계엔 스크립트가 반드시 지나는 관문이 없어(specify→clarify→plan 전부 대화)
#   BLOCKING 강제가 산문으로만 남았다. 결정의 **증거**를 구현 직전인 여기서 확인한다.
_STACK_SH="$SCRIPT_DIR/../_internal/check-stack-decided.sh"
if [ -f "$_STACK_SH" ]; then
  if ! stack_out=$(bash "$_STACK_SH" "$FID" 2>&1); then
    printf '%s\n' "$stack_out" >&2
    echo "emit-context: foundation 기술스택 미확정 — clarify·원장 보완 후 재실행" >&2
    exit 1
  fi
fi

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

# 역방향 커버리지 (20260806 /maintain 정밀분석) — 모든 **must** AC 가 ≥1 task 에 매핑.
#   종전엔 task→AC 한 방향만 검사해, AC-R-1(회귀 must)을 채워 놓고 어느 태스크에도
#   매핑하지 않으면 회귀 테스트가 영영 구현되지 않았다 (decomposing 산문 "모든 must AC 매핑" 의 teeth).
#   must 판정: h2/h3 AC 헤더 섹션 안에 `**우선순위**: must` 가 있는 id 만 —
#   우선순위 필드가 아예 없는 구식/픽스처 AC 문서는 자연히 대상 0건(하위호환 fail-open).
must_ids = []
_cur = None
for line in ac_text.splitlines():
    m = re.match(r"^#{2,3}\s+(AC-[A-Za-z0-9-]+)", line)
    if m:
        _cur = m.group(1)
        continue
    if _cur and re.match(r"^\*\*우선순위\*\*:\s*must", line.strip()):
        must_ids.append(_cur)
        _cur = None
covered = {a for t in tasks for a in (t.get("ac") or [])}
for mid in must_ids:
    if mid not in covered:
        errors.append(f"must AC 미커버 — {mid} 가 어느 태스크의 ac 배열에도 없음 (회귀/필수 AC 는 태스크 매핑 의무)")

if errors:
    for e in errors:
        print(f"emit-context FAIL — {e}", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PYEOF

# 2단계 실제 작성
mkdir -p "$DISPATCH"
YAML_IN="$yaml" AC_PATH="$AC" SPEC_PATH="$SPEC" FID="$FID" DISPATCH_DIR="$DISPATCH" python3 - << 'PYEOF'
import os, re, sys, yaml
ac_path = os.environ["AC_PATH"]
fid = os.environ["FID"]
disp = os.environ["DISPATCH_DIR"]
data = yaml.safe_load(os.environ["YAML_IN"]) or {}
tasks = data.get("tasks", []) or []

# AC.md 에서 각 AC-id 의 Given/When/Then 1줄 추출
with open(ac_path, encoding="utf-8") as fh:
    ac_text = fh.read()
def ac_summary(ac_id):
    # 헤더(### AC-1: ...) 우선 — templates/acceptance-criteria.md 표준.
    # #{2,3} 로 ## (h2) 도 겸용 — LLM 이 h2 로 쓰는 drift 가 흔해(20260722 screen-design 실측:
    #   ## AC-N 이 추출 밖 → 빈 요약 17건 조용히 통과) 구제. #209 bullet 겸용 완화 철학 연장.
    # bullet(- **AC-1**: ... / - AC-1: ...) 겸용.
    for pat in (rf"#{{2,3}}\s+{re.escape(ac_id)}:?\s*(.*)",
                rf"^-\s+\*\*{re.escape(ac_id)}\*\*:?\s*(.*)",
                rf"^-\s+{re.escape(ac_id)}:?\s*(.*)"):
        m = re.search(pat, ac_text, re.MULTILINE)
        if m and m.group(1).strip():
            return m.group(1).strip()[:120]
    # 어느 포맷에도 없거나 빈 설명 — id 는 1차 게이트를 통과했으므로(AC.md 에 토큰 존재) 이는
    #   "id 존재 but 헤더/불릿 전무" = 진짜 drift 다. 빈 AC 로 dispatch 되면 서브에이전트가 담당 AC 를
    #   못 읽으므로 fail-closed 로 차단한다 (20260723-lifecycle-robustness C).
    print(f"WARN: {ac_id} 요약 추출 실패 — acceptance-criteria.md 포맷 확인 (### {ac_id}: 헤더 권장)", file=sys.stderr)
    return ""

# 사전 계산 + 원자적 fail-closed (부분 잔류 0) — write 루프 전에 전 AC 요약을 뽑고,
#   추출 실패(빈 요약)가 1건이라도 있으면 파일을 쓰지 않고 exit 1 (missing-tc·bad-ac 게이트와 동일 원자성).
summaries = {}
extract_failed = False
for t in tasks:
    for a in (t.get("ac", []) or []):
        if a not in summaries:
            s = ac_summary(a)   # 실패 시 stderr WARN
            summaries[a] = s
            if not s:
                extract_failed = True
if extract_failed:
    print("emit-context: AC 요약 추출 실패 — fail-closed (빈 AC dispatch 차단)", file=sys.stderr)
    sys.exit(1)

count = 0
for t in tasks:
    tid = t["id"]
    tc = t["test_command"]
    inputs = t.get("inputs", []) or []
    outputs = t.get("outputs", []) or []
    acs = t.get("ac", []) or []
    ac_lines = "\n".join(f"- {a}: {summaries[a]}" for a in acs)
    inputs_lines = "\n".join(f"- `{p}`" for p in inputs) or "- (없음)"
    whitelist = sorted(set(inputs) | set(outputs))
    wl_lines = "\n".join(f"- `{p}`" for p in whitelist)
    # §6 설계 계약 (design-first 후진 teeth — implementing 계약 준수 실배선).
    #   존재하는 설계 산출물만 emit, 부재 시 §6 자체 생략(graceful — 순수 로직/CLI 무영향).
    # api-spec-consumer.md: 외부 API 소비 계약 (KIND 1·5 — Phase 8g/Step 5.6 산출). 제공 IF 와 대칭 (C2).
    contract = [p for p in (".specops/memory/api-spec.md", ".specops/memory/api-spec-consumer.md", ".specops/memory/data-model.md") if os.path.exists(p)]
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
    body = f"""<!-- specops-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
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
