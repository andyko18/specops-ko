#!/usr/bin/env bash
# batch-state.sh — batch queue ↔ requirements parity 검사 (read-only 감지 도구)
# 사용: batch-state.sh <batch-dir> [requirements-path]
#   exit 0 = clean (전 FR 완료 + 드리프트 0 + 중복 0)
#   exit 1 = 불일치 (미완·드리프트·중복 목록 출력 — 차단 결정은 호출측 게이트 소관)
#   exit 2 = 사용 오류
# 완료 토큰: IMPL_DONE | MERGED (Status 마지막 컬럼 기준 — 설명 컬럼 오탐 방지)
# 파싱: 행 단위 grep — 2-테이블 분할 queue 견딤. FR suffix 변형(FR-3b) 허용
set -u

# --gate (20260721-batch-pr-teeth): 훅이 batch PR 을 **차단할지** 판정하는 모드.
#   기본 모드와 판정 기준이 다르다. 드리프트·중복·미완은 batch 운영 판단이다 —
#   M1 batch → M2·M3 batch 로 나눠 진행하면 드리프트는 정상이고, 이것으로 PR 을 막으면
#   정당한 부분 batch 를 차단하는 false-block 이 된다(dogfood 20260721 test1 이 정확히 이 형태였다).
#   게이트가 보는 것은 **뭉개짐 신호**뿐이다: 산출물 부재 · 진행기록 부재 · 라벨 오염.
#   운영 신호는 gate 모드에서도 참고 출력하되 exit code 에 반영하지 않는다.
GATE=0
if [ "${1:-}" = "--gate" ]; then GATE=1; shift; fi

BATCH_DIR="${1:-}"
if [ -z "$BATCH_DIR" ] || [ ! -d "$BATCH_DIR" ]; then
  echo "Usage: $0 <batch-dir> [requirements-path]" >&2; exit 2
fi
QUEUE="$BATCH_DIR/queue.md"
[ -f "$QUEUE" ] || { echo "Error: $QUEUE 없음" >&2; exit 2; }

REQ="${2:-}"
if [ -z "$REQ" ]; then
  # start-all Phase 0 동일 fallback (clarify Q1)
  if [ -f ".specops/memory/requirements.md" ]; then REQ=".specops/memory/requirements.md"
  elif [ -f "requirements.md" ]; then REQ="requirements.md"
  else echo "Error: requirements.md 미발견 — 경로 인자로 지정" >&2; exit 2; fi
fi
[ -f "$REQ" ] || { echo "Error: $REQ 없음" >&2; exit 2; }

FR_RE='^\| *FR-[0-9][0-9A-Za-z]* *\|'
queue_rows=$(grep -E "$FR_RE" "$QUEUE" || true)
queue_ids=$(printf '%s\n' "$queue_rows" | sed -E 's/^\| *(FR-[0-9][0-9A-Za-z]*) *\|.*/\1/')
req_ids=$(grep -E "$FR_RE" "$REQ" | sed -E 's/^\| *(FR-[0-9][0-9A-Za-z]*) *\|.*/\1/' || true)

fail=0        # 전체(기본 모드 exit code)
fail_gate=0   # 뭉개짐 신호만 (--gate exit code) — 운영 신호는 불포함

# 0) 라벨 오염 (gate 전용) — Status 가 인식 라벨이 아니면 하류 teeth 가 통째로 vacuous 해진다.
#    산출물·진행기록 검사는 IMPL_DONE 행만 수집하므로(아래 4·5), `DONE` 처럼 비슷하지만 다른 라벨을
#    쓰면 **검사 대상 0건 → 조용히 통과**한다. dogfood 20260721 test1 이 정확히 그랬다(FR-4~8 전부 `DONE`).
#    기본 모드에서는 검사하지 않는다 — 기존 호출자의 판정을 바꾸지 않기 위해서다(회귀 불변식).
if [ "$GATE" -eq 1 ] && [ -n "$queue_rows" ]; then
  bad_labels=$(printf '%s\n' "$queue_rows" | awk -F'|' '{
    gsub(/\r$/, "")
    st = ""
    for (i = NF; i >= 1; i--) { gsub(/^ +| +$/, "", $i); if ($i != "") { st = $i; break } }
    id = $2; gsub(/^ +| +$/, "", id)
    if (st !~ /^(IMPL_DONE|MERGED|TODO|WIP|DOING|PENDING|HELD|SKIP|BLOCKED|PLAN_DONE|CODE_DONE)([^A-Za-z0-9_]|$)/) print "  - " id ": " st
  }')
  if [ -n "$bad_labels" ]; then
    echo "[라벨] queue.md Status 가 인식 라벨이 아님 — 완료 판정 teeth 가 무력화됩니다:"
    printf '%s\n' "$bad_labels"
    echo "  인식 라벨: IMPL_DONE | MERGED | TODO | WIP | DOING | PENDING | HELD | SKIP | BLOCKED | PLAN_DONE | CODE_DONE"
    fail=1; fail_gate=1
  fi
fi

# 1) queue FR-ID 중복
dups=$(printf '%s\n' "$queue_ids" | sort | uniq -d | grep -v '^$' || true)
if [ -n "$dups" ]; then
  echo "[중복] queue.md FR-ID 중복 — 상태 오갱신 위험:"
  printf '%s\n' "$dups" | sed 's/^/  - /'
  fail=1
fi

# 2) 드리프트 — requirements 에 있으나 queue 미추적
drift=$(printf '%s\n' "$req_ids" | while IFS= read -r id; do
  [ -z "$id" ] && continue
  printf '%s\n' "$queue_ids" | grep -qx "$id" || printf '%s\n' "$id"
done)
if [ -n "$drift" ]; then
  echo "[드리프트] requirements 에 있으나 queue 미추적:"
  printf '%s\n' "$drift" | sed 's/^/  - /'
  fail=1
fi

# 3) 미완 — Status(마지막 컬럼)가 IMPL_DONE|MERGED 아님
incomplete=""
if [ -n "$queue_rows" ]; then  # 빈 queue 가드 — awk 빈 줄 유입 시 "  - : " phantom 차단
incomplete=$(printf '%s\n' "$queue_rows" | awk -F'|' '{
  gsub(/\r$/, "")   # CRLF 방어 — $0 재분할로 IMPL_DONE\r 미완 오탐 차단
  # 마지막 비어있지 않은 필드 = Status (st 행두 초기화 — 이월 방지, plan-reviewer Minor)
  st = ""
  for (i = NF; i >= 1; i--) { gsub(/^ +| +$/, "", $i); if ($i != "") { st = $i; break } }
  id = $2; gsub(/^ +| +$/, "", id)
  if (st !~ /^(IMPL_DONE|MERGED)/) print "  - " id ": " st
}')
fi
if [ -n "$incomplete" ]; then
  echo "[미완] 완료(IMPL_DONE|MERGED) 아님:"
  printf '%s\n' "$incomplete"
  fail=1
fi

# 4) 산출물 뭉개짐 방지 teeth — IMPL_DONE FID 마다 per-FR 검증·리뷰 산출물 3종 필수
#    Phase 3 는 FR 당:
#      - review-base.sha    : review.diff 격리 base (부재→requesting-code-review 가 HEAD~1 로 silent
#                             fallback → 직전 FR 변경까지 끌어들여 내용 뭉개짐. layer 2 강제)
#      - evidence.md        : per-FR verify 산출 (layer 3 존재)
#      - review-request.md 또는 review-skip.md
#           : per-FR code-review 산출 (layer 3). review-skip.md 허용 조건 둘 중 하나:
#             (a) lite+단일태스크+batch-review-skip allowlist (기존)
#             (b) 사유에 end-loaded: + 전 tid 의 reviews/<tid>-[BC]-report.md 존재
#             (skip-only 시 사유 비공백 필수)
#    를 개별 생성해야 한다. 하나라도 없으면 verify/review 가 뭉개졌거나 미실행 → batch PR 전 차단.
#    MERGED(타 사이클서 이미 shipped)는 batch 전용 review-base.sha 미보유 가능 → 제외(IMPL_DONE 한정).
#    FID = 첫 두 비어있지 않은 필드 중 둘째.
SPECOPS_ROOT=$(dirname "$BATCH_DIR")
done_pairs=""
if [ -n "$queue_rows" ]; then
  done_pairs=$(printf '%s\n' "$queue_rows" | awk -F'|' '{
    gsub(/\r$/, "")
    n = 0; delete a
    for (i = 1; i <= NF; i++) { gsub(/^ +| +$/, "", $i); if ($i != "") a[++n] = $i }
    if (n >= 2 && a[n] ~ /^IMPL_DONE/) print a[1] "|" a[2]
  }')
fi
missing_artifacts=""
invalid_skip=""
if [ -n "$done_pairs" ]; then
  while IFS='|' read -r fr_id fid; do
    [ -z "$fr_id" ] && continue
    # FID 미확정 placeholder 는 미완 검사(3)가 이미 잡음 — 여기선 skip
    case "$fid" in ''|'—'|'-'|'TBD'|'tbd') continue ;; esac
    for art in review-base.sha evidence.md; do
      [ -f "$SPECOPS_ROOT/$fid/$art" ] || \
        missing_artifacts="${missing_artifacts}  - ${fr_id} (${fid}): ${art} 없음"$'\n'
    done
    # review-request.md 또는 lite skip 산출 review-skip.md 중 하나 필수
    if [ ! -f "$SPECOPS_ROOT/$fid/review-request.md" ] && [ ! -f "$SPECOPS_ROOT/$fid/review-skip.md" ]; then
      missing_artifacts="${missing_artifacts}  - ${fr_id} (${fid}): review-request.md|review-skip.md 없음"$'\n'
    fi
    # review-skip.md only — (a) lite+단일태스크 또는 (b) end-loaded+B/C reports (남용 차단)
    # review-request.md 가 있으면 정식 리뷰 경로로 보고 skip 메타는 검사하지 않는다.
    if [ -f "$SPECOPS_ROOT/$fid/review-skip.md" ] && [ ! -f "$SPECOPS_ROOT/$fid/review-request.md" ]; then
      skip_file="$SPECOPS_ROOT/$fid/review-skip.md"
      rp_file="$SPECOPS_ROOT/$fid/risk-profile.json"
      tasks_file="$SPECOPS_ROOT/$fid/tasks.md"
      reason_raw=$(cat "$skip_file" 2>/dev/null || true)
      reason=$(printf '%s' "$reason_raw" | tr -d ' \t\r\n')
      if [ -z "$reason" ]; then
        invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): review-skip.md 사유 비어 있음"$'\n'
      elif printf '%s' "$reason_raw" | grep -qiE 'end-loaded|batch-end-loaded'; then
        # (b) end-loaded / batch-end-loaded: Phase B/C 가 이미 커버 — requesting 중복 skip
        if [ ! -f "$tasks_file" ]; then
          invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): end-loaded skip 인데 tasks.md 부재"$'\n'
        else
          missing_bc=""
          while IFS= read -r tid; do
            [ -z "$tid" ] && continue
            [ -f "$SPECOPS_ROOT/$fid/reviews/${tid}-B-report.md" ] || \
              missing_bc="${missing_bc}${tid}-B "
            [ -f "$SPECOPS_ROOT/$fid/reviews/${tid}-C-report.md" ] || \
              missing_bc="${missing_bc}${tid}-C "
          done <<TIDS
$(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]*' "$tasks_file" 2>/dev/null | sed -E 's/^[[:space:]]*-[[:space:]]*id:[[:space:]]*//;s/[[:space:]]*$//' || true)
TIDS
          if [ -z "$(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]*' "$tasks_file" 2>/dev/null || true)" ]; then
            invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): end-loaded skip 인데 tasks.md 에 task id 없음"$'\n'
          elif [ -n "$missing_bc" ]; then
            invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): end-loaded skip 인데 reviews 누락 (${missing_bc% })"$'\n'
          fi
        fi
      else
        # (a) lite+단일태스크+batch-review-skip
        if [ ! -f "$rp_file" ]; then
          invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): review-skip 인데 risk-profile.json 부재"$'\n'
        else
          eff=$(jq -r '.effective // empty' "$rp_file" 2>/dev/null || true)
          if [ "$eff" != "lite" ]; then
            invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): review-skip 인데 effective=${eff:-?} (lite 아님)"$'\n'
          fi
          if ! jq -e '.reductions_allowed | index("batch-review-skip")' "$rp_file" >/dev/null 2>&1; then
            invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): review-skip 인데 reductions_allowed에 batch-review-skip 없음"$'\n'
          fi
        fi
        if [ ! -f "$tasks_file" ]; then
          invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): review-skip 인데 tasks.md 부재"$'\n'
        else
          task_n=$(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]*' "$tasks_file" 2>/dev/null | wc -l | tr -d ' ')
          if [ "${task_n:-0}" -ne 1 ]; then
            invalid_skip="${invalid_skip}  - ${fr_id} (${fid}): review-skip 인데 태스크 수=${task_n:-0} (단일 태스크만 허용)"$'\n'
          fi
        fi
      fi
    fi
  done <<EOF
$done_pairs
EOF
fi
if [ -n "$missing_artifacts" ]; then
  echo "[산출물 누락] IMPL_DONE FID 의 per-FR 검증·리뷰 산출물 부재 (뭉개짐 방지 teeth):"
  printf '%s' "$missing_artifacts"
  fail=1; fail_gate=1
fi
if [ -n "$invalid_skip" ]; then
  echo "[review-skip 무효] lite+단일태스크 또는 end-loaded|batch-end-loaded+B/C reports 메타 미충족 (남용·오분류 차단):"
  printf '%s' "$invalid_skip"
  fail=1; fail_gate=1
fi

# 5) 진행기록 teeth — IMPL_DONE FID 마다 session-progress.md FID 섹션에 /verify PASS 줄 필수
#    (dogfood 20260716: batch 가 skill 미호출 인라인 진행으로 session-progress 0줄 → R-1/R-2 면제 신호
#     (_verify_passed_in_progress) 부재 → 게이트 차단 → BYPASS 관성 남발. 이 줄은 verifying-evidence-ko
#     실호출의 흔적이자 세션 재개 맥락의 유일 경로. 앵커·섹션 추출은 governance-lib.sh
#     _verify_passed_in_progress 와 동일 포맷 — 행 선두 `- YYYY-MM-DD HH:MM /verify PASS`, memo 언급 무매칭)
PROGRESS="$SPECOPS_ROOT/session-progress.md"
missing_progress=""
if [ -n "$done_pairs" ]; then
  while IFS='|' read -r fr_id fid; do
    [ -z "$fr_id" ] && continue
    case "$fid" in ''|'—'|'-'|'TBD'|'tbd') continue ;; esac
    has_line=0
    if [ -f "$PROGRESS" ]; then
      awk -v f="## $fid" '$0 ~ "^"f"( |$)" {insec=1; next} insec && /^## / {exit} insec {print}' "$PROGRESS" \
        | grep -Eq '^- [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} /verify PASS' && has_line=1
    fi
    [ "$has_line" -eq 1 ] || \
      missing_progress="${missing_progress}  - ${fr_id} (${fid}): session-progress /verify PASS 줄 없음"$'\n'
  done <<EOF
$done_pairs
EOF
fi
if [ -n "$missing_progress" ]; then
  echo "[진행기록 누락] IMPL_DONE FID 의 session-progress /verify PASS 줄 부재 (verifying-evidence-ko 실호출 흔적·R-1/R-2 면제 신호):"
  printf '%s' "$missing_progress"
  fail=1; fail_gate=1
fi

if [ "$GATE" -eq 1 ]; then
  if [ "$fail_gate" -eq 0 ]; then
    echo "BATCH-GATE: OK (뭉개짐 신호 없음 — 드리프트·미완은 운영 판단이라 차단 대상 아님)"
    exit 0
  fi
  echo "BATCH-GATE: BLOCK — per-FR 산출물·진행기록·라벨 결함 (위 목록 참조)" >&2
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "BATCH-STATE: OK (전 FR 완료 · 드리프트 0 · 중복 0 · 산출물·진행기록 완비)"
  exit 0
fi
echo "BATCH-STATE: MISMATCH — batch PR 전 확인 필요" >&2
exit 1
