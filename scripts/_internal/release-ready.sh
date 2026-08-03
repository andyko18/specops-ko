#!/usr/bin/env bash
# RELEASE_READY 합성 판정 (P0-3). PR 직전 품질 축을 한곳에서 본다.
# Usage: release-ready.sh <FID>
# Exit: 0=READY · 1=NOT_READY · 2=UNKNOWN(fail-open / legacy)
set -u

FID="${1:?usage: $0 <FID>}"
printf '%s' "$FID" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || {
  echo "RELEASE_READY: UNKNOWN"
  echo "  reason=invalid-fid"
  exit 2
}

SPECOPS="${SPECOPS_ROOT:-.specops}"
FID_DIR="$SPECOPS/$FID"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
STATE_SH="$PLUGIN/scripts/_internal/verification-state.sh"
AUDIT_SH="$PLUGIN/scripts/_internal/check-review-audit.sh"
RECON_SH="$PLUGIN/scripts/_internal/reconcile-check.sh"
# shellcheck source=/dev/null
source "$PLUGIN/scripts/skip-tracker.sh"

if [ ! -d "$FID_DIR" ]; then
  echo "RELEASE_READY: UNKNOWN"
  echo "  reason=fid-dir-missing"
  exit 2
fi

# legacy: 구조화 상태도 evidence stamp도 없으면 판정 불가 → fail-open
has_state=0
[ -f "$FID_DIR/verification-state.json" ] && has_state=1
has_stamp=0
[ -f "$FID_DIR/evidence.md" ] \
  && grep -q '^RUN-VERIFICATION-RESULT: ' "$FID_DIR/evidence.md" 2>/dev/null \
  && has_stamp=1
if [ "$has_state" -eq 0 ] && [ "$has_stamp" -eq 0 ]; then
  echo "RELEASE_READY: UNKNOWN"
  echo "  reason=legacy-no-verify-artifact"
  exit 2
fi

verify=UNKNOWN
review=UNKNOWN
security=UNKNOWN
integration=UNKNOWN
performance=UNKNOWN
reconcile=UNKNOWN
crit_high=UNKNOWN
ready=1

# ① verify — PASS only
if [ -f "$STATE_SH" ]; then
  verify=$(SPECOPS_ROOT="$SPECOPS" bash "$STATE_SH" current "$FID" 2>/dev/null || echo NOT_RUN)
else
  verify=NOT_RUN
fi
[ "$verify" = "PASS" ] || ready=0

# ② review
if [ -f "$AUDIT_SH" ]; then
  audit_out=$(SPECOPS_ROOT="$SPECOPS" bash "$AUDIT_SH" "$FID" 2>&1) || true
  case "$audit_out" in
    REVIEW-AUDIT:\ PASS*) review=PASS ;;
    REVIEW-AUDIT:\ FAIL*) review=FAIL; ready=0 ;;
    REVIEW-AUDIT:\ SKIP*)
      if [ -f "$FID_DIR/review-request.md" ] \
         || { [ -d "$FID_DIR/reviews" ] && [ -n "$(ls -A "$FID_DIR/reviews" 2>/dev/null)" ]; }; then
        review=SKIP_OK
      else
        review=SKIP_EMPTY
        ready=0
      fi
      ;;
    *) review=UNKNOWN; ready=0 ;;
  esac
else
  review=UNKNOWN
  ready=0
fi

# ③④⑤ lifecycle tail gates — PASS|SKIP 허용, 부재·FAIL 거부
ev="$FID_DIR/evidence.md"
for gate in security integration performance; do
  v=$(skip::verdicts "$ev" "$gate" 2>/dev/null | tail -1)
  [ -n "$v" ] || v=MISSING
  case "$gate" in
    security) security="$v" ;;
    integration) integration="$v" ;;
    performance) performance="$v" ;;
  esac
  case "$v" in
    PASS|SKIP) ;;
    *) ready=0 ;;
  esac
done

# ⑥ reconcile — DESYNC 문구면 NOT READY (--hook 모드 사용, 기본 출력 불변)
if [ -f "$RECON_SH" ]; then
  recon_out=$(SPECOPS_ROOT="$SPECOPS" bash "$RECON_SH" "$FID" --hook 2>&1) || true
  if printf '%s' "$recon_out" | grep -q 'DESYNC'; then
    reconcile=DESYNC
    ready=0
  else
    reconcile=OK
  fi
else
  reconcile=UNKNOWN
  ready=0
fi

# ⑦ Critical/High — best-effort (오탐 시 축만 UNKNOWN, 전체 fail-open 금지)
crit_high=OK
if [ -f "$ev" ]; then
  if skip::verdicts "$ev" security 2>/dev/null | grep -qx FAIL; then
    crit_high=SECURITY_FAIL
    ready=0
  fi
fi
if [ -d "$FID_DIR/reviews" ]; then
  if grep -RqlE 'NEEDS_FIX|## 🔴 Critical' "$FID_DIR/reviews" 2>/dev/null; then
    # receive-review 수용 흔적이 없으면 미승인으로 본다 (휴리스틱)
    if ! grep -qE '/receive-review|수용' "$SPECOPS/session-progress.md" 2>/dev/null; then
      crit_high=UNRESOLVED_REVIEW
      ready=0
    fi
  fi
fi

if [ "$ready" -eq 1 ]; then
  echo "RELEASE_READY: OK"
else
  echo "RELEASE_READY: NOT_READY"
fi
printf '  verify=%s\n' "$verify"
printf '  review=%s\n' "$review"
printf '  security=%s\n' "$security"
printf '  integration=%s\n' "$integration"
printf '  performance=%s\n' "$performance"
printf '  reconcile=%s\n' "$reconcile"
printf '  crit_high=%s\n' "$crit_high"

[ "$ready" -eq 1 ] && exit 0 || exit 1
