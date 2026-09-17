#!/usr/bin/env bash
# test-intent.sh — 기능 단위 intent.md 계약 (판정기 + 문서 잠금)
# FID 20260917-intent-md-adoption · AC-3·4·6·7·8·9·10·11
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
TPL="$PLUGIN/templates/intent.md"

# T-tpl.a: 5절 고정
_missing=""
for h in '## 문제' '## 기대 결과' '## 영향 사용자·시스템' '## 제약' '## 열린 질문'; do
  grep -qF "$h" "$TPL" || _missing="${_missing}${_missing:+ · }$h"
done
[ -z "$_missing" ] && ok "T-tpl.a 5절 고정" || nope "T-tpl.a" "누락: $_missing"

# T-tpl.b: Status 3값 + 열린 질문 없음 표기 규약
## `- 없음` 은 `--` 로 옵션 파싱을 끊는다 (plan-review 2회차 I-A: 안 끊으면 `grep: invalid option`)
grep -q 'Status' "$TPL" && grep -q 'accepted' "$TPL" && grep -qF -- '- 없음' "$TPL" \
  && ok "T-tpl.b Status·열린질문 없음 표기" || nope "T-tpl.b" "규약 문구 부재"

# T-tpl.c: spec 템플릿 추적 줄
grep -q 'intent\.md' "$PLUGIN/templates/spec.md" \
  && ok "T-tpl.c spec 템플릿 Intent 추적" || nope "T-tpl.c" "spec 템플릿 미갱신"

CHK="$PLUGIN/scripts/_internal/check-intent.sh"
_fid() {  # $1=dir $2=fid — spec 있는 FID
  mkdir -p "$1/.specops/$2"
  printf '# spec\n**§유형**: 유지보수\n' > "$1/.specops/$2/spec.md"
}
_intent_filled() {  # $1=dir $2=fid
  printf '# Intent: 예시\n\n**작성자**: 사용자 · **Status**: accepted\n\n## 문제\n실제 문제 서술\n\n## 기대 결과\n관찰 가능한 결과\n\n## 영향 사용자·시스템\n- 운영자\n\n## 제약\n- 해당 없음\n\n## 열린 질문\n- 없음\n' > "$1/.specops/$2/intent.md"
}

# T-chk.a: 날짜 FID + intent 부재 → FAIL
TD=$(mktemp -d); _fid "$TD" 20991231-x
out=$(cd "$TD" && bash "$CHK" 20991231-x 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'intent.md' \
  && ok "T-chk.a intent 부재 FAIL" || nope "T-chk.a" "rc=$rc out=$out"
rm -rf "$TD"

# T-chk.b: 템플릿 그대로 복사 → 미채움 FAIL
TD=$(mktemp -d); _fid "$TD" 20991231-x; cp "$TPL" "$TD/.specops/20991231-x/intent.md"
(cd "$TD" && bash "$CHK" 20991231-x >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T-chk.b 미채움 FAIL" || nope "T-chk.b" "rc=$rc"
rm -rf "$TD"

# T-chk.c: 채워진 intent → PASS
TD=$(mktemp -d); _fid "$TD" 20991231-x; _intent_filled "$TD" 20991231-x
(cd "$TD" && bash "$CHK" 20991231-x >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T-chk.c 채움 PASS" || nope "T-chk.c" "rc=$rc"
rm -rf "$TD"

# T-chk.d: cutoff 이전 FID → SKIP (도입 전 FID 무손상)
TD=$(mktemp -d); _fid "$TD" 20260101-old
out=$(cd "$TD" && bash "$CHK" 20260101-old 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'SKIP' \
  && ok "T-chk.d cutoff 이전 SKIP" || nope "T-chk.d" "rc=$rc out=$out"
rm -rf "$TD"

# T-chk.e: 비날짜 FID(fixture) → SKIP
TD=$(mktemp -d); _fid "$TD" ok-fid
out=$(cd "$TD" && bash "$CHK" ok-fid 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'SKIP' \
  && ok "T-chk.e 비날짜 FID SKIP" || nope "T-chk.e" "rc=$rc"
rm -rf "$TD"

# T-chk.f: spec.md 부재 → SKIP (fail-open)
TD=$(mktemp -d); mkdir -p "$TD/.specops/20991231-x"
(cd "$TD" && bash "$CHK" 20991231-x >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T-chk.f spec 부재 fail-open" || nope "T-chk.f" "rc=$rc"
rm -rf "$TD"

# T-chk.g: spec 미참조 → WARN 이지만 rc=0 (clarify Q2)
TD=$(mktemp -d); _fid "$TD" 20991231-x; _intent_filled "$TD" 20991231-x
err=$(cd "$TD" && bash "$CHK" 20991231-x 2>&1 >/dev/null); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$err" | grep -q 'WARN' \
  && ok "T-chk.g 미참조 WARN rc=0" || nope "T-chk.g" "rc=$rc err=$err"
rm -rf "$TD"

# T-chk.h: 레거시 memory/intent.md → 이관 WARN rc=0
TD=$(mktemp -d); _fid "$TD" 20991231-x; _intent_filled "$TD" 20991231-x
mkdir -p "$TD/.specops/memory"
printf '# 프로세스 설계서\n- **트리거**: 사용자 행동\n' > "$TD/.specops/memory/intent.md"
_h1=$(cksum < "$TD/.specops/memory/intent.md")
err=$(cd "$TD" && bash "$CHK" 20991231-x 2>&1 >/dev/null); rc=$?
_h2=$(cksum < "$TD/.specops/memory/intent.md")
# AC-2: 제안만 — 레거시 파일은 바뀌지 않는다(해시 불변까지 단언 · plan-review 1회차 I-6)
[ "$rc" -eq 0 ] && printf '%s' "$err" | grep -q 'process-design' && [ "$_h1" = "$_h2" ] \
  && ok "T-chk.h 레거시 이관 WARN · 파일 불변" || nope "T-chk.h" "rc=$rc err=$err hash=$_h1/$_h2"
rm -rf "$TD"

# T-wire.a: emit-context 배선
grep -q 'check-intent.sh' "$PLUGIN/scripts/dag/emit-context.sh" \
  && ok "T-wire.a emit-context 배선" || nope "T-wire.a" "미배선"

SPEC_SKILL="$PLUGIN/skills/specifying-ko/SKILL.md"
_b15=$(awk '/^1\.5\./{f=1} f&&/^2\. /{exit} f' "$SPEC_SKILL")
# ★ 쌍은 `패턴|라벨` 순서다 — `_pat` 은 첫 `|` 앞을 쓴다 (plan-review 1회차 I-2: 순서가 뒤집히면 영구 FAIL)
for _p in 'check-intent\.sh|판정 SoT' 'HARD GATE|신규 독립 게이트' '설계 승인과 통합|maintain·lite 통합' 'FR 행|batch 도출' 'ASSUMED|auto 표기'; do
  _pat=${_p%%|*}; _lbl=${_p#*|}
  printf '%s\n' "$_b15" | grep -qE "$_pat" \
    && ok "T-15 1.5 구간: $_lbl" || nope "T-15 $_lbl" "1.5 구간에 없음"
done
grep -q 'intent 추적' "$SPEC_SKILL" \
  && ok "T-15.z Step 7 자체검토 intent 추적" || nope "T-15.z" "Step 7 미갱신"
grep -q 'intent\.md' "$PLUGIN/scripts/show-fid-status.sh" \
  && ok "T-art.a show-fid-status 아티팩트" || nope "T-art.a" "미포함"
grep -q 'intent\.md' "$PLUGIN/skills/structured-artifacts-ko/SKILL.md" \
  && ok "T-art.b structured-artifacts 트리" || nope "T-art.b" "미포함"

# T-cons: 하류 소비 배선 (AC-8) — intent 를 읽는 6문서 + 집계기 정규식
for _f in skills/clarifying-ko/SKILL.md skills/planning-ko/SKILL.md skills/verifying-evidence-ko/SKILL.md skills/performance-test-ko/SKILL.md commands/start-all.md commands/start-all-auto.md; do
  grep -q 'intent' "$PLUGIN/$_f" && ok "T-cons ${_f##*/} 소비" || nope "T-cons ${_f##*/}" "intent 미참조"
done
grep -q 'intent' "$PLUGIN/scripts/_internal/collect-assumptions.sh" \
  && ok "T-cons collect-assumptions" || nope "T-cons collect-assumptions" "정규식 미확장"
finish
