#!/usr/bin/env bash
# SAST 로컬 룰셋 검증 (FID 20260917-sast-offline-ruleset)
#   AC-1 룰 2개 로드 · AC-5 양성(행 번호까지) · AC-6 프로덕션 오탐 0
#   semgrep 호출에는 반드시 SEMGREP_ENABLE_VERSION_CHECK=0 — 없으면 semgrep.dev 로 ~99s 매달린다.
set -u
PASS=0; FAIL=0
P=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$P/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
RULES="$P/scripts/_internal/semgrep-rules/bash-injection.yml"
FIX="$P/scripts/tests/fixtures/sast/vulnerable.sh"

# T1.a AC-1 룰 파일 존재
[ -f "$RULES" ] && ok "T1.a AC-1 룰 파일 존재" || nope "T1.a AC-1 룰 파일" "$RULES 부재"

# T1.b AC-1 룰 2개 이상
n=$(grep -c '^  - id:' "$RULES" 2>/dev/null || echo 0)
[ "$n" -ge 2 ] && ok "T1.b AC-1 룰 $n 개 (2 이상)" || nope "T1.b AC-1 룰 개수" "n=$n"

# T1.c 픽스처 존재·실행권한
{ [ -f "$FIX" ] && [ -x "$FIX" ]; } && ok "T1.c 픽스처 존재·exec" || nope "T1.c 픽스처" "$FIX"

if command -v semgrep >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  TD=$(mktemp -d)
  # T1.d AC-5 양성 — 정확히 2건 + 행 번호 5·7 (픽스처 앞 3줄이 shebang·주석·directive)
  SEMGREP_ENABLE_VERSION_CHECK=0 semgrep --config "$RULES" --json "$FIX" > "$TD/pos.json" 2>/dev/null
  got=$(python3 -c "
import json
d=json.load(open('$TD/pos.json'))
print(sorted((r['check_id'].split('.')[-1], r['start']['line']) for r in d['results']))
" 2>/dev/null)
  want="[('bash-eval-var', 5), ('bash-rm-rf-var', 7)]"
  [ "$got" = "$want" ] && ok "T1.d AC-5 양성 2건 · 행 5·7" || nope "T1.d AC-5 양성" "got=$got want=$want"

  # T1.e AC-6 음성 — 프로덕션 코드 매치 0
  SEMGREP_ENABLE_VERSION_CHECK=0 semgrep --config "$RULES" --json "$P/hooks" "$P/scripts" \
    > "$TD/neg.json" 2>/dev/null
  m=$(python3 -c "import json;print(len(json.load(open('$TD/neg.json'))['results']))" 2>/dev/null)
  [ "$m" = 0 ] && ok "T1.e AC-6 프로덕션 오탐 0" || nope "T1.e AC-6 오탐" "매치=$m — 픽스처가 아니라 룰을 고칠 것"

  # T1.f 파싱 커버리지 관측 (비차단 — 0건의 신뢰 범위를 드러낸다)
  cov=$(python3 -c "
import json
d=json.load(open('$TD/neg.json'))
sc=len(d['paths']['scanned']); bad=len({e.get('path') for e in d.get('errors',[]) if e.get('path')})
print(f'{sc-bad}/{sc}')
" 2>/dev/null)
  ok "T1.f 파싱 커버리지 $cov (참고 — 매치 0건의 신뢰는 이 범위까지)"
  rm -rf "$TD"
else
  ok "T1.d~f semgrep 또는 python3 미설치 — skip (graceful)"
fi

echo "── test-sast-rules: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
