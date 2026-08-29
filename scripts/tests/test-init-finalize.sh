#!/usr/bin/env bash
# test-init-finalize.sh — 부트스트랩 종결 커밋 계약 (FID 20260810-init-commit-teeth)
set -u
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

FIN="$PLUGIN/scripts/_internal/init-finalize.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# 부트스트랩 산출물이 staged 인 repo 픽스처
_mkstaged() {
  local r="$1"; mkdir -p "$r/.specops/memory"; cd "$r" || return 1
  git init -q; git config user.email t@t; git config user.name t
  local f
  for f in PRD.md CLAUDE.md README.md DESIGN.md; do printf '# %s\n' "$f" > "$f"; done
  for f in constitution requirements test-strategy architecture frontend-architecture \
           backend-architecture api-spec data-model screens-overview; do
    printf '# %s\n' "$f" > ".specops/memory/$f.md"
  done
  git add -A
}

# F1 — 스테이징만 → 커밋 1건 · 파일수 일치
R="$TMP/f1"; _mkstaged "$R"
n_staged=$(git diff --cached --name-only | wc -l | tr -d ' ')
out=$(bash "$FIN" 2>&1); rc=$?
n_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
n_files=$(git show --name-only --format= HEAD 2>/dev/null | grep -c . || echo 0)
sha=$(git rev-parse --short HEAD 2>/dev/null || echo "")
subj=$(git log -1 --format=%s 2>/dev/null)     # AC-9 2절 — 메시지 접두 (doctor 판정과 결합)
# 계약: staged 산출물 **전건** + 진행기록(session-progress.md) 이 한 커밋에 들어간다(spec §3 clean tree).
#   +1 은 **픽스처 한정** — 이 픽스처엔 session-progress.md 가 없어 finalize 가 새로 만든다.
#   실제 /init-project 는 phases-artifacts.sh:223 이 이미 staged 해 두므로 delta 는 0 이다.
has_sp=$(git show --name-only --format= HEAD 2>/dev/null | grep -c 'session-progress\.md' || true)
exp_files=$((n_staged + 1))
if [ "$rc" -eq 0 ] && [ "$n_commits" = "1" ] && [ "$n_files" = "$exp_files" ] \
   && [ "${has_sp:-0}" -ge 1 ] \
   && printf '%s' "$out" | grep -q "$sha" \
   && printf '%s' "$subj" | grep -q '^chore(init): '; then
  ok "F1 스테이징만 → 커밋 1건 · 파일수 $n_files(=staged $n_staged + 진행기록) · SHA 출력 · chore(init) 접두"
else
  nope "F1" "rc=$rc commits=$n_commits files=$n_files/exp$exp_files sp=$has_sp subj=$subj out=$out"
fi

# F2 — enrich 수정분이 커밋에 포함 (재-add 보증) ★핵심
R="$TMP/f2"; _mkstaged "$R"
printf '# PRD\n\nenriched-marker-XYZ\n' > PRD.md      # add 이후 수정 = AM 상태
bash "$FIN" >/dev/null 2>&1
if git show HEAD:PRD.md 2>/dev/null | grep -q 'enriched-marker-XYZ' \
   && [ -z "$(git status --short PRD.md)" ]; then
  ok "F2 enrich 수정분이 커밋에 포함 (재-add 보증)"
else
  nope "F2" "committed=$(git show HEAD:PRD.md 2>&1 | tr '\n' ' ') status=$(git status --short PRD.md)"
fi

# F11 (Phase C Critical) — repo **하위 디렉토리**에서 실행해도 재-add 가 보증된다
#   재-add 루프가 상대경로면 subdir 에서 전부 no-op 이 되어 기존 staged 만 커밋되고
#   rc=0 "커밋 완료" 를 출력한다 — AC-2 가 조용히 무력화되는 거짓 성공(부모 재현).
#   session-progress-append.sh 도 TARGET 이 상대경로라 sub/.specops/ 를 새로 판다 —
#   같은 근원이므로 한 어서션에 함께 잠근다.
R="$TMP/f11"; _mkstaged "$R"
printf '# PRD\n\nenriched-marker-SUBDIR\n' > PRD.md      # add 이후 수정 = AM 상태
mkdir -p sub; cd sub || exit 1
out=$(bash "$FIN" 2>&1); rc=$?
cd "$R" || exit 1
committed=$(git show HEAD:PRD.md 2>/dev/null | grep -c 'enriched-marker-SUBDIR' || true)
dirty=$(git status --short PRD.md 2>/dev/null | grep -c . || true)
stray=$([ -e sub/.specops ] && echo 1 || echo 0)
if [ "$rc" -eq 0 ] && [ "${committed:-0}" -ge 1 ] && [ "${dirty:-1}" -eq 0 ] && [ "$stray" -eq 0 ]; then
  ok "F11 subdir 실행에도 enrich 재-add 보증 · sub/.specops 미생성"
else
  nope "F11" "rc=$rc committed=$committed dirty=$dirty stray_sub_specops=$stray out=$out"
fi

# F3 — 커밋 대상 없음 → rc=0 · 커밋 0
R="$TMP/f3"; mkdir -p "$R"; cd "$R" || exit 1
git init -q; git config user.email t@t; git config user.name t
out=$(bash "$FIN" 2>&1); rc=$?
n_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
[ "$rc" -eq 0 ] && [ "$n_commits" = "0" ] \
  && ok "F3 커밋 대상 없음 → rc=0 · 커밋 0" || nope "F3" "rc=$rc commits=$n_commits out=$out"

# F4 — SPECOPS_INIT_COMMIT_NOW 경로로 이미 커밋된 뒤 → no-op rc=0
R="$TMP/f4"; _mkstaged "$R"
git commit -q -m "chore(init): /init-project 부트스트랩 (사전 커밋)"
before=$(git rev-list --count HEAD)
out=$(bash "$FIN" 2>&1); rc=$?
after=$(git rev-list --count HEAD)
[ "$rc" -eq 0 ] && [ "$before" = "$after" ] \
  && ok "F4 이미 커밋됨 → no-op rc=0" || nope "F4" "rc=$rc $before→$after out=$out"

# F5 + F10(AC-10) — progress append · FID 형식 · 디렉토리 미생성
R="$TMP/f5"; _mkstaged "$R"
bash "$FIN" >/dev/null 2>&1
sp=".specops/session-progress.md"
fid=$(grep -oE '^## [0-9]{8}-init-project' "$sp" 2>/dev/null | head -1 | sed 's/^## //')
# spec §3 — 기록이 **그 단일 커밋 안에** 들어가야 커밋 직후 tree 가 clean 이다.
#   (기록이 커밋 뒤에 붙으면 downstream 에선 .specops/.gitignore 가 FID 디렉토리만
#    ignore 하므로(phases-artifacts.sh:190~194) session-progress.md 가 미커밋 수정분으로 남는다.)
sp_dirty=$(git status --short "$sp" 2>/dev/null | grep -c . || true)
sp_in_commit=$(git show --name-only --format= HEAD 2>/dev/null | grep -c 'session-progress\.md' || true)
# spec §3 기대결과는 파일 하나가 아니라 **워킹트리 전체** 가 clean 이다.
#   실측(Phase B): sp 만 보면 통과하지만 `?? .specops/session-progress.md.bak` 가 남았다
#   — session-progress-append.sh:108 이 prepend 직전 남긴 1세대 백업이고, downstream
#   .specops/.gitignore 는 FID 디렉토리 패턴만 커버해(phases-artifacts.sh:190~194) 걸러지지 않는다.
#   init 종결 경로에서 append 를 부르는 것은 본 FID 가 신규 도입했으므로 잔여물도 여기가 책임진다.
tree_dirty=$(git status --porcelain 2>/dev/null | grep -c . || true)
tree_out=$(git status --porcelain 2>/dev/null | tr '\n' '|')
if [ -n "$fid" ] && grep -q '/init-project' "$sp" && [ ! -d ".specops/$fid" ] \
   && [ "${sp_dirty:-1}" -eq 0 ] && [ "${sp_in_commit:-0}" -ge 1 ] \
   && [ "${tree_dirty:-1}" -eq 0 ]; then
  ok "F5 progress append (FID=$fid) · 커밋 포함 · 워킹트리 전체 clean · .specops/\$FID 디렉토리 미생성"
else
  nope "F5" "fid=$fid dir=$([ -d ".specops/$fid" ] && echo 있음 || echo 없음) dirty=$sp_dirty in_commit=$sp_in_commit tree_dirty=$tree_dirty tree=[$tree_out]"
fi

# F8 — 커밋 실패 → rc=1 · staged 보존 · 사유·재시도 안내
R="$TMP/f8"; _mkstaged "$R"
mkdir -p .git/hooks
printf '#!/bin/sh\necho "rejected by test hook" >&2\nexit 1\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
out=$(bash "$FIN" 2>&1); rc=$?
staged_after=$(git diff --cached --name-only | wc -l | tr -d ' ')
# AC-5/FR-5 는 기록을 **커밋 성공**에 조건부로 둔다(acceptance-criteria.md:71 Given,
#   spec.md:62 "finalize 성공 시") — 실패했는데 "완료" 가 남으면 검출형 근거가 거짓이 된다.
false_rec=$(grep -c '/init-project 완료' .specops/session-progress.md 2>/dev/null || true)
if [ "$rc" -eq 1 ] && [ "$staged_after" -gt 0 ] \
   && printf '%s' "$out" | grep -q '사유' && printf '%s' "$out" | grep -q '재시도' \
   && [ "${false_rec:-1}" -eq 0 ]; then
  ok "F8 커밋 실패 → rc=1 · staged $staged_after 보존 · 사유·재시도 안내 · 거짓 완료기록 0"
else
  nope "F8" "rc=$rc staged=$staged_after false_record=$false_rec out=$out"
fi

# F12/F13 공통 픽스처 — 이전 세션이 남긴 **출처 불명 .bak** + 커밋 실패
#   실패 경로의 복원(cp .bak → session-progress.md → git add)이 .bak 출처를 확인하지 않으면
#   남의 스냅샷으로 워킹트리와 **인덱스**를 덮는다(Phase C Important 2).
_mkstale() {          # $1=repo — stale .bak 를 444 로 만들어 append 의 cp(108) 를 실패시킨다
  _mkstaged "$1"
  printf '# Session Progress\n\n---\n\n## 20250101-old\n\n- 2025-01-01 09:00 /specify 완료\n' \
    > .specops/session-progress.md
  git add .specops/session-progress.md
  printf 'STALE-BAK-MARKER-이전세션\n' > .specops/session-progress.md.bak
  chmod 444 .specops/session-progress.md.bak
  mkdir -p .git/hooks
  printf '#!/bin/sh\necho "rejected by test hook" >&2\nexit 1\n' > .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit
}
_stale_assert() {     # $1=태그 $2=rc $3=out — 워킹트리·인덱스 모두 stale 오염 0 · 원본 보존
  local tag="$1" rc="$2" out="$3" sp=".specops/session-progress.md"
  local stale idx orig staged false_rec
  stale=$(grep -c 'STALE-BAK-MARKER' "$sp" 2>/dev/null || true)
  idx=$(git show ":$sp" 2>/dev/null | grep -c 'STALE-BAK-MARKER' || true)
  orig=$(grep -c '/specify 완료' "$sp" 2>/dev/null || true)
  staged=$(git diff --cached --name-only | wc -l | tr -d ' ')
  # AC-5 는 그대로다 — 커밋 실패 시 "완료" 기록이 남으면 안 된다. F12 는 **정상 .bak 으로
  #   복원**해서, F13 은 애초에 append 가 실패해서 0 이 된다(복원 skip 이 기록을 남기지 않는다).
  false_rec=$(grep -c '/init-project 완료' "$sp" 2>/dev/null || true)
  if [ "$rc" -eq 1 ] && [ "${stale:-1}" -eq 0 ] && [ "${idx:-1}" -eq 0 ] \
     && [ "${orig:-0}" -ge 1 ] && [ "$staged" -gt 0 ] && [ "${false_rec:-1}" -eq 0 ]; then
    ok "$tag stale .bak 로 복원하지 않음 (워킹트리·인덱스 무오염 · 거짓 완료기록 0 · staged $staged 보존)"
  else
    nope "$tag" "rc=$rc stale=$stale index_stale=$idx orig_kept=$orig staged=$staged false_record=$false_rec out=$out"
  fi
}

# F12 (Phase C Important 2) — append 는 성공했으나 그 백업 cp 가 실패해 .bak 이 stale
R="$TMP/f12"; _mkstale "$R"
out=$(bash "$FIN" 2>&1); rc=$?
chmod 644 .specops/session-progress.md.bak 2>/dev/null || true
_stale_assert "F12" "$rc" "$out"

# F13 (Phase C Important 2 · 리뷰어 명시 시나리오) — append **자체**가 조용히 실패(`|| true`)
#   .specops 를 555 로 만들어 prepend(mv)를 막는다. append 는 마지막 echo 때문에 rc=0 으로
#   끝나므로(실측) 종료코드로는 실패를 못 본다 — 그래서 우리 기록의 **실재**를 확인해야 한다.
R="$TMP/f13"; _mkstale "$R"
chmod 555 .specops
out=$(bash "$FIN" 2>&1); rc=$?
chmod 755 .specops; chmod 644 .specops/session-progress.md.bak 2>/dev/null || true
_stale_assert "F13" "$rc" "$out"

DOC="$PLUGIN/scripts/doctor.sh"

# F6 — 미커밋 부트스트랩 → bootstrap warn · exit 0 / 커밋 후 → ok
R="$TMP/f6"; _mkstaged "$R"
out=$(bash "$DOC" --json 2>&1); rc=$?
st=$(printf '%s' "$out" | jq -r '.checks[]|select(.id=="bootstrap")|.status' 2>/dev/null)
fix=$(printf '%s' "$out" | jq -r '.checks[]|select(.id=="bootstrap")|.fix' 2>/dev/null)
bash "$FIN" >/dev/null 2>&1
st2=$(bash "$DOC" --json 2>&1 | jq -r '.checks[]|select(.id=="bootstrap")|.status' 2>/dev/null)
if [ "$rc" -eq 0 ] && [ "$st" = "warn" ] && [ -n "$fix" ] && [ "$st2" = "ok" ]; then
  ok "F6 미커밋 → warn(+조치) · 커밋 후 → ok · exit 0"
else
  nope "F6" "rc=$rc st=$st fix=$fix st2=$st2"
fi

# F9 — memory 부재 repo → bootstrap unknown · 행 개수 동일
R="$TMP/f9"; mkdir -p "$R/.specops"; cd "$R" || exit 1
git init -q; git config user.email t@t; git config user.name t
j=$(bash "$DOC" --json 2>&1)
st=$(printf '%s' "$j" | jq -r '.checks[]|select(.id=="bootstrap")|.status' 2>/dev/null)
cnt=$(printf '%s' "$j" | jq -r '.checks|length' 2>/dev/null)
[ "$st" = "unknown" ] && [ "$cnt" = "8" ] \
  && ok "F9 memory 부재 → unknown · checks 8행 고정" || nope "F9" "st=$st cnt=$cnt"

# F7 — session-progress 제목이 그 프로젝트 이름 (하드코딩 인자 제거)
ENS="$PLUGIN/hooks/ensure-session-progress.sh"
R="$TMP/f7-외부"; mkdir -p "$R"; cd "$R" || exit 1
bash "$ENS" >/dev/null 2>&1
t1=$(awk 'FNR==6' .specops/session-progress.md 2>/dev/null)
R="$TMP/specops-ko"; mkdir -p "$R"; cd "$R" || exit 1
bash "$ENS" >/dev/null 2>&1
t2=$(awk 'FNR==6' .specops/session-progress.md 2>/dev/null)
# ★ 패턴 실측 필수: hooks.json 은 JSON 이스케이프라 리터럴이 `...progress.sh\" specops-ko` 다.
#   `\.sh" *specops-ko` 와 `[^"]*specops-ko` 는 **둘 다 0 match**(실측) — `\` 와 `"` 가 사이에 낀다.
#   아래 패턴만 현재 1 match 로 확인됐다.
hard=$(grep -c 'ensure-session-progress\.sh.*specops-ko' "$PLUGIN/hooks/hooks.json" || true)
if printf '%s' "$t1" | grep -q 'f7-외부' && ! printf '%s' "$t1" | grep -q 'specops-ko' \
   && printf '%s' "$t2" | grep -q 'specops-ko' && [ "${hard:-0}" -eq 0 ]; then
  ok "F7 제목=프로젝트명 · hooks.json 하드코딩 0"
else
  nope "F7" "t1=$t1 | t2=$t2 | hardcoded=$hard"
fi

# F-doc (AC-7) — 산문의 목록 소유권 이전
CMD="$PLUGIN/commands/init-project.md"
lit=$(grep -cE '^[[:space:]]*git (add|commit)' "$CMD" || true)
ph=$(grep -c '보강·골격 파일들' "$CMD" || true)
call=$(grep -c 'init-finalize\.sh' "$CMD" || true)
if [ "${lit:-0}" -eq 0 ] && [ "${ph:-0}" -eq 0 ] && [ "${call:-0}" -ge 1 ]; then
  ok "F-doc 산문 git add/commit 리터럴 0 · 플레이스홀더 0 · finalize 호출 ${call}건"
else
  nope "F-doc" "literal=$lit placeholder=$ph call=$call"
fi

# F-doc2 (SCOPE-MOVED) — /doctor 커맨드 문서가 doctor.sh 항목 목록과 동기.
#   T3 이 5번째 항목(bootstrap)을 scripts/doctor.sh 에 넣었는데 문서는 4항목인 채로 남았다.
#   문서/구현 drift 는 T5 가 존재하는 이유 그 자체라 같은 클래스를 여기서 잠근다.
#   20260830-silent-failure-surfacing T3 이 governance·deps 를 더해 8항목이 됐다 — id 순회·개수를 함께 올린다.
#   stale 라벨 판정은 리터럴 고정('4항목') 을 버리고 "현재 개수(8) 가 아닌 N항목 잔존 0" 으로 일반화한다:
#   고정 리터럴은 항목이 늘어나는 순간 절대 매치하지 않는 죽은 검사가 되어, 이 검사 자신이
#   무음 실패가 된다(= 이 FID 가 없애려는 클래스). 개수 증설 시엔 아래 -eq 8 이 강제로 실패해 갱신을 부른다.
DOCMD="$PLUGIN/commands/doctor.md"
d_boot=$(grep -c 'bootstrap' "$DOCMD" || true)
d_old=$(grep -oE '[0-9]+항목' "$DOCMD" | grep -vxc '8항목' || true)
d_ids=0
# id 존재 판정은 **점검 항목 표의 행**(`^| \`id\` |`) 을 요구한다 — 파일 어디든 백틱 언급이면 통과시키던
# 이전 판정은 이빨이 없었다(실측 20260830: `governance` 행을 통째로 지워도 `deps` 행 산문의
# "위 `governance` 항목이 …" 언급이 카운트를 8로 유지해 PASS 했다). 행 삭제가 안 잡히면 이 검사 자체가 무음이다.
for _id in git_hooks memory orphan_fid progress bootstrap stale governance deps; do
  grep -qE "^\|[[:space:]]*\`$_id\`[[:space:]]*\|" "$DOCMD" && d_ids=$((d_ids + 1))
done
if [ "${d_boot:-0}" -ge 1 ] && [ "${d_old:-0}" -eq 0 ] && [ "$d_ids" -eq 8 ]; then
  ok "F-doc2 /doctor 문서 8항목 동기 (bootstrap 기재 · stale 'N항목' 라벨 잔존 0 · id ${d_ids}/8)"
else
  nope "F-doc2" "bootstrap=$d_boot stale_label=$d_old ids=$d_ids/8"
fi

finish
