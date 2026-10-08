#!/usr/bin/env bash
# record-batch-gate.sh — batch 레벨 게이트 verdict 를 전 IMPL_DONE FID 로 전파 (20260806)
# Usage: record-batch-gate.sh <batch-dir> <security|integration|performance> <PASS|SKIP> [SKIP 근거]
#        record-batch-gate.sh <batch-dir> status        # 전 IMPL_DONE FID 의 게이트 3종 현황(읽기 전용)
# Exit: 0 = 기록 완료(status: 전부 PASS|인용 있는 SKIP) · 1 = 사용 오류·전파 대상 없음(status: 누락·근거 미인용 있음)
#
# 왜 필요한가: `/start-all` Phase 3 완료 Step A/B/C 는 batch 전체를 **1회** 실행하고,
#   각 skill 은 호출된 **대표 FID 1곳**의 evidence.md 에만 verdict 를 남긴다. 그런데
#   RELEASE_READY(`gh pr create` hard gate)는 ACTIVE batch 의 **전 IMPL_DONE FID** 각각에
#   security/integration/performance = PASS|SKIP 을 요구한다 — 하나라도 MISSING 이면
#   NOT_READY → hard deny(인라인 BYPASS 불가). 정직한 /start-all 완주가 구조적으로
#   batch PR 에서 막히는 설계 간 충돌(20260806 실측 — RR 게이트 v1.60 도입 이후).
#
# 규칙:
#   - PASS·SKIP 만 전파. **FAIL 은 거부** — FAIL 은 systematic-debugging 후 재실행이 정도이지
#     전 FID 로 낙인 찍는 값이 아니다.
#   - SKIP 은 근거 필수 (skip-tracker CITED 규약 — 무근거 SKIP 은 관측 도구가 BARE 로 집계).
#   - **SKIP 근거는 줄 번호 인용 필수** (20261009) — `§범위 L12-15` 꼴. 읽는 쪽(release-ready.sh)이 인용 없는 SKIP 을
#     BARE 로 보고 batch PR 을 hard deny 하는데, 쓰는 쪽이 아무 근거나 받으면 기록은 되고 PR 에서야 막힌다.
#     종전엔 그 상태가 '기존 기록 보존' 때문에 다시 불러도 고쳐지지 않았다. 판정은 skip::cite_status 와 같은 정규식이다.
#   - 멱등: 해당 게이트 섹션이 이미 있는 FID 는 건드리지 않는다(대표 FID 원본 보존 포함).
#     예외 1가지 — 그 섹션이 **인용 없는 SKIP** 이고 이번 호출이 인용 있는 SKIP 이면 근거만 보완한다
#     (종전 근거는 `**종전 근거**:` 로 남긴다 · 섹션 수는 그대로).
#   - status: 닫기 직전 확인용. PR 게이트는 `gh pr create` 에서만 돌므로, 로컬 병합으로 닫는 batch 는
#     이 명령이 유일한 확인 수단이다(실기록 20261008: 6건 중 2건이 전파 없이 닫히거나 멈췄다).
#   - 섹션 포맷은 skip::verdicts 파서 계약(`## /<헤더> <VERDICT>` + `**결과**:` 줄)을 따른다.
set -u

USAGE="usage: $0 <batch-dir> <security|integration|performance> <PASS|SKIP> [근거] | $0 <batch-dir> status"
BATCH_DIR="${1:?$USAGE}"
GATE="${2:?$USAGE}"
SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CITE_RE='L[0-9]|§[^ ]*[0-9]'   # skip::cite_status(scripts/skip-tracker.sh)와 같은 판정 — 바꾸면 함께 바꾼다

# 인자 검증을 queue 파싱보다 먼저 한다 — 잘못된 verdict 는 queue 상태와 무관하게 같은 문구로 거부한다.
VERDICT=""; REASON=""; HDR=""
if [ "$GATE" != "status" ]; then
  VERDICT="${3:?$USAGE}"
  REASON="${4:-}"
  case "$GATE" in
    security)    HDR="security-review" ;;
    integration) HDR="integration-test" ;;
    performance) HDR="performance-test" ;;
    *) echo "record-batch-gate: 미지 게이트 '$GATE' (security|integration|performance|status)" >&2; exit 1 ;;
  esac
  case "$VERDICT" in
    PASS) ;;
    SKIP)
      [ -n "$REASON" ] || {
        echo "record-batch-gate: SKIP 은 근거 필수 (skip-tracker CITED 규약)" >&2; exit 1
      }
      # 근거는 evidence.md 의 한 줄이다 — 줄바꿈이 들면 섹션 구조가 깨진다.
      case "$REASON" in *"
"*|*$'\r'*) echo "record-batch-gate: 근거에 줄바꿈을 넣을 수 없다 — 한 줄로 쓴다" >&2; exit 1 ;; esac
      printf '%s' "$REASON" | grep -qE "$CITE_RE" || {
        cat >&2 <<EOF
record-batch-gate: SKIP 근거에 spec.md 섹션명+라인번호 인용이 없다 — 기록하지 않았다.
  받은 근거: $REASON
  형식 예:  "§범위 L12-15 — 통합 표면 없음"  ·  "§NFR L8-12 — 성능 임계값 없음"
  (인용 없는 SKIP 은 release-ready 가 BARE 로 보고 batch PR 을 차단한다 — 여기서 먼저 막는다.)
EOF
        exit 1
      } ;;
    FAIL)
      echo "record-batch-gate: FAIL 은 전파 대상이 아니다 — systematic-debugging 후 재실행" >&2
      exit 1 ;;
    *) echo "record-batch-gate: 미지 verdict '$VERDICT' (PASS|SKIP)" >&2; exit 1 ;;
  esac
fi

QUEUE="$BATCH_DIR/queue.md"
[ -f "$QUEUE" ] || { echo "record-batch-gate: queue.md 부재 ($BATCH_DIR)" >&2; exit 1; }

SPECOPS=$(dirname "$BATCH_DIR")
. "$SELF/queue-lib.sh"
# 판정 파서(skip::verdicts·skip::cite_status)는 release-ready 와 같은 것을 쓴다 — 여기서 다시 구현하지 않는다.
# shellcheck source=/dev/null
. "$SELF/../skip-tracker.sh"

# Status 정규화 (20260828-queue-label-drift) — 모델이 `**IMPL_DONE**` 로 손편집하면
#   종전 `|IMPL_DONE|` 리터럴 매칭이 전건 불일치해 **대상 0건**이 됐다.
done_fid_cells=$(awk -F'|' "$QUEUE_AWK_QNORM"'
{
  st = ""
  for (i = NF; i >= 1; i--) { if (qnorm($i) != "") { st = qnorm($i); break } }
  if (st ~ /^IMPL_DONE$/) print qnorm($3)
}' "$QUEUE" || true)
fids=$(printf '%s\n' "$done_fid_cells" | grep -E '^[0-9]{8}-[a-z0-9-]+$' || true)
[ -n "$fids" ] || { echo "record-batch-gate: IMPL_DONE FID 0건 ($QUEUE)" >&2; exit 1; }
# IMPL_DONE 인데 FID 칸이 FID 가 아닌 행(TBD·빈칸) — 전파할 곳도, 검사할 산출물도 찾을 수 없다.
n_done=$(printf '%s\n' "$done_fid_cells" | grep -c . || true)
n_fid=$(printf '%s\n' "$fids" | grep -c . || true)

# ── status: 읽기 전용 현황 ────────────────────────────────────────────────────
if [ "$GATE" = "status" ]; then
  bad=0; miss=0; bare=0; noev=0; nfail=0
  echo "BATCH-GATE-STATUS: $(basename "$BATCH_DIR")"
  for fid in $fids; do
    ev="$SPECOPS/$fid/evidence.md"
    if [ ! -f "$ev" ]; then
      echo "  $fid  evidence.md 부재 — 전파할 곳이 없다(이 FID 의 verify 가 돌지 않았다)"
      noev=$((noev + 1)); bad=1; continue
    fi
    line="  $fid "
    for g in security integration performance; do
      v=$(skip::verdicts "$ev" "$g" 2>/dev/null | tail -1)
      [ -n "$v" ] || v=MISSING
      case "$v" in
        PASS) ;;
        SKIP) if skip::cite_status "$ev" "$g" 2>/dev/null | grep -qx BARE; then v="SKIP(BARE)"; bare=$((bare + 1)); bad=1; fi ;;
        MISSING) miss=$((miss + 1)); bad=1 ;;
        *) nfail=$((nfail + 1)); bad=1 ;;
      esac
      line="$line $g=$v"
    done
    echo "$line"
  done
  nofid=$((n_done - n_fid))
  if [ "$nofid" -gt 0 ]; then
    echo "  (IMPL_DONE 행 ${n_done}개 중 ${nofid}개는 queue 의 FID 칸이 비었거나 TBD 다 — 그 FR 은 여기서 확인할 수 없다)"
    bad=1
  fi
  if [ "$bad" -eq 0 ]; then
    echo "BATCH-GATE-STATUS: OK (IMPL_DONE ${n_fid}개 FID 전부에 security·integration·performance 판정이 있다)"
    exit 0
  fi
  cat <<EOF
BATCH-GATE-STATUS: INCOMPLETE — 누락 ${miss} · 근거 미인용 ${bare} · FAIL ${nfail} · evidence 부재 ${noev} · FID 미기재 ${nofid}
  이 상태로 batch 를 닫지 않는다(PR 은 RELEASE_READY 가 막고, 로컬 병합은 아무것도 막지 않는다).
  MISSING  → 그 게이트(Step A/B/C)를 실행한 뒤:  bash $0 $BATCH_DIR <게이트> <PASS|SKIP> "<근거>"
  SKIP(BARE) → 같은 명령을 **줄 번호를 인용한 근거**로 다시 부른다:  … SKIP "§범위 L12-15 — <사유>"
  FAIL     → 전파 대상이 아니다. 원인을 고치고 그 게이트를 다시 실행한다.
  FID 미기재 → queue.md 의 그 행 FID 칸에 실제 FID 를 적는다(Phase 1 에서 빠진 것).
EOF
  exit 1
fi

# 인용 없는 기존 SKIP 섹션의 근거를 보완한다 — 그 게이트의 섹션만, 섹션 수는 그대로.
#   무엇이 SKIP 이고 무엇이 인용인지는 skip::verdicts·skip::cite_status 와 **같은 우선순위**로 본다:
#   헤더에 SKIP 이 있으면 SKIP, 헤더에 PASS·FAIL 이 있으면 그 판정(본문의 "SKIP" 글자는 보지 않는다),
#   헤더에 판정이 없을 때만 첫 `**결과**:` 줄을 본다. 인용은 SKIP 헤더 또는 첫 `**근거**:` 줄에서 찾는다.
#   근거는 ENVIRON 으로 넘긴다 — `awk -v` 는 `\1`·`\\`·`\t` 를 해석해 글자를 바꾼다(신규 섹션의 echo 경로와 어긋났다).
#   rc 0 = 보완함 · 1 = 보완 대상 없음 · 2 = 실패(원본 불변)
_amend_bare() {  # $1=evidence.md
  local ev="$1" tmp rc
  tmp=$(mktemp "${ev}.XXXXXX") || return 2
  RBG_REASON="$REASON" awk -v hdr="^## /$HDR" -v cite="$CITE_RE" '
    function flush(   i, v, cited, seenr, put) {
      if (n == 0) return
      v = ""; cited = 0; seenr = 0
      if (buf[1] ~ /SKIP/) { v = "SKIP"; if (buf[1] ~ cite) cited = 1 }
      else if (buf[1] ~ /PASS/) v = "PASS"
      else if (buf[1] ~ /FAIL/) v = "FAIL"
      for (i = 2; i <= n; i++) {
        if (v == "" && buf[i] ~ /^\*\*결과\*\*:/) {
          if (buf[i] ~ /SKIP/) v = "SKIP"; else if (buf[i] ~ /PASS/) v = "PASS"; else if (buf[i] ~ /FAIL/) v = "FAIL"; else v = "?"
        }
        if (buf[i] ~ /^\*\*근거\*\*:/ && !seenr) { seenr = 1; if (buf[i] ~ cite) cited = 1 }
      }
      if (v != "SKIP" || cited) { for (i = 1; i <= n; i++) print buf[i]; n = 0; return }
      fixed++
      put = 0
      for (i = 1; i <= n; i++) {
        if (buf[i] ~ /^\*\*근거\*\*:/) { sub(/^\*\*근거\*\*:/, "**종전 근거**:", buf[i]) }
        print buf[i]
        if (!put && (buf[i] ~ /^\*\*결과\*\*:/ || (i == 1 && (n == 1 || buf[2] !~ /^\*\*결과\*\*:/)))) {
          print "**근거**: " ENVIRON["RBG_REASON"]; put = 1
        }
      }
      n = 0
    }
    /^## / { flush(); if ($0 ~ hdr) { insec = 1; buf[++n] = $0; next } insec = 0; print; next }
    insec { buf[++n] = $0; next }
    { print }
    END { flush(); exit (fixed > 0 ? 0 : 1) }
  ' "$ev" > "$tmp" 2>/dev/null
  rc=$?
  if [ "$rc" -eq 0 ]; then
    if cat "$tmp" > "$ev"; then rm -f "$tmp"; return 0; fi
    rm -f "$tmp"; return 2
  fi
  rm -f "$tmp"
  [ "$rc" -eq 1 ] && return 1
  return 2
}

wrote=0; amended=0; failed=0
for fid in $fids; do
  ev="$SPECOPS/$fid/evidence.md"
  [ -f "$ev" ] || { echo "  WARN: $fid evidence.md 부재 — skip" >&2; continue; }
  # 멱등 — 이미 그 게이트의 **판정이 있는** 섹션이 있으면(대표 FID 포함) 보존. 인용 없는 SKIP 만 근거를 보완한다.
  #   헤더만 있고 판정이 없는 섹션은 기록이 아니다(status 가 MISSING 으로 본다) — 그때는 새 섹션을 덧붙인다.
  if [ -n "$(skip::verdicts "$ev" "$GATE" 2>/dev/null | tail -1)" ]; then
    if [ "$VERDICT" = SKIP ]; then
      _amend_bare "$ev"; arc=$?
      [ "$arc" -eq 0 ] && amended=$((amended + 1))
      [ "$arc" -eq 2 ] && { echo "  WARN: $fid 근거 보완 실패 — evidence.md 는 그대로다" >&2; failed=$((failed + 1)); }
    fi
    continue
  fi
  {
    echo ""
    echo "## /$HDR $VERDICT"
    echo "**결과**: $VERDICT"
    [ -n "$REASON" ] && echo "**근거**: $REASON"
    echo "**출처**: batch $(basename "$BATCH_DIR") Step 게이트 1회 실행 — record-batch-gate.sh 전파"
  } >> "$ev"
  wrote=$((wrote + 1))
done

if [ "$amended" -gt 0 ]; then
  echo "BATCH-GATE: $GATE $VERDICT → ${wrote}개 FID 전파 · ${amended}개 FID 근거 보완(인용 없던 SKIP) (그 밖의 기존 기록 보존)"
else
  echo "BATCH-GATE: $GATE $VERDICT → ${wrote}개 FID 전파 (기존 기록 보존)"
fi
[ "$((n_done - n_fid))" -gt 0 ] && echo "  WARN: IMPL_DONE 행 ${n_done}개 중 $((n_done - n_fid))개는 FID 칸이 비었거나 TBD 라 전파하지 못했다 — queue.md 의 FID 칸을 채운다" >&2
[ "$failed" -gt 0 ] && { echo "record-batch-gate: ${failed}개 FID 의 근거 보완이 실패했다" >&2; exit 1; }
exit 0
