#!/usr/bin/env bash
# init-project rename 검증 (FID 20260619-rename-init-project)
set -u
PASS=0; FAIL=0
P=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# AC-1: init-project.md 존재 + name + trigger + 오케스트레이터 호출
IP="$P/commands/init-project.md"
[ -f "$IP" ] && grep -q '^name: init-project' "$IP" && grep -q '"/init-project"' "$IP" && grep -q 'start-project.sh' "$IP" \
  && ok "AC-1 init-project.md 신설" || nope "AC-1" "init-project.md 결함"
# AC-2: start-project alias 제거됨 (deprecated stub → 부재)
[ ! -f "$P/commands/start-project.md" ] && ok "AC-2 start-project alias 제거" || nope "AC-2" "alias 잔존"
# AC-3: 메타skill /init-project 안내
grep -q '/init-project' "$P/skills/using-specops-auto-ko-ko/SKILL.md" \
  && ok "AC-3 메타skill /init-project" || nope "AC-3" "메타skill 미갱신"
# AC-4: chain 안내 파일에 /init-project 등장 + 사용자노출 /start-project 잔존 0
#   (deprecated stub·테스트·CHANGELOG·start-project.sh 참조 제외)
miss=""
for f in skills/specifying-ko/SKILL.md skills/e2e-test-ko/SKILL.md commands/start-all.md commands/start-foundation.md; do
  grep -q '/init-project' "$P/$f" || miss="$miss $f(no-init)"
  # start-project.{sh,md} 경로 마스킹 후 /start-project(슬래시) 잔존 검사 (줄단위 false-neg 회피)
  # sed -E 필수 — BSD sed(macOS)는 BRE `\|` 교대 미지원(no-op→false-positive). plan-reviewer 2회차.
  sed -E 's#start-project\.(sh|md)#XMASKX#g' "$P/$f" | grep -q '/start-project' && miss="$miss $f(stale-start)"
done
[ -z "$miss" ] && ok "AC-4 chain 안내 갱신" || nope "AC-4" "$miss"
# AC-5: templates footer + README 갱신 (대표 샘플)
grep -q '/init-project' "$P/templates/PRD.md" && grep -q '/init-project' "$P/README.md" \
  && ok "AC-5 templates/README 갱신" || nope "AC-5" "footer/README 미갱신"
# AC-R-1: start-project.sh 무변경 (git)
git -C "$P" diff HEAD --quiet -- scripts/_internal/start-project.sh && ok "AC-R-1 start-project.sh 무변경" || nope "AC-R-1" "오케스트레이터 변경됨"

echo "── test-rename-init-project: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
