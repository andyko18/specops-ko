#!/usr/bin/env bash
# queue-set-status.sh — queue.md 의 FR 행 Status 를 기계적으로 갱신 (FID 20260828-queue-label-drift)
#
# 사용: queue-set-status.sh <queue.md> <FR-ID> <STATUS> [FID]
#   FID 를 주면 그 행의 FID 칸도 함께 채운다. IMPL_DONE 은 FID 칸이 채워져 있어야 한다(20261009).
#   exit 0 = 갱신 완료 (또는 이미 같은 값 — 멱등)
#   exit 1 = 갱신 실패 (FR-ID 미발견 · 중복 · 알 수 없는 라벨 · 표 형식 아님)
#   exit 2 = 사용 오류
#
# 왜 필요한가:
#   종전 갱신 경로는 `commands/start-all.md` 산문 지시("Status를 `IMPL_DONE`으로 갱신")를
#   받은 **모델의 손편집**뿐이었다. 모델이 강조 표기를 붙여 `**IMPL_DONE**` 를 쓰자
#   소비자 3곳이 전건 불일치했고, 검사가 **대상 0건으로 조용히 통과**했다
#   (argus batch-20260729 실측: FR 31건이 무검증 방치).
#
#   읽는 쪽 정규화(`queue-lib.sh`)가 이미 그 형태를 흡수하지만 그건 **사후 방어**다.
#   쓰는 쪽을 기계화하면 애초에 장식이 들어가지 않는다. 둘은 대체재가 아니라
#   같은 결함의 앞뒤를 막는 쌍이다 — 정규화는 과거 queue·수기 편집까지 커버하고,
#   이 스크립트는 앞으로의 유입을 끊는다.
#
# 설계 선택:
#   - **행 전체를 재조립하지 않는다.** 마지막 컬럼만 치환한다. 설명 컬럼에 `|` 가 없다는
#     보장이 없고(한국어 설명에 흔하다), 재조립하면 그 내용을 잃는다.
#   - **알 수 없는 라벨은 거부한다.** 이 스크립트를 통과한 값은 소비자가 인식하는
#     라벨임이 보장돼야 한다 — 아니면 기계화의 의미가 없다.
#   - **FR-ID 중복이면 거부한다.** 어느 행을 고칠지 모르는 상태에서 하나를 골라 고치면
#     조용히 틀린 행을 갱신한다.
set -u

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SELF_DIR/queue-lib.sh"

QUEUE="${1:-}"; FR_ID="${2:-}"; NEW="${3:-}"; NEW_FID="${4:-}"

if [ -z "$QUEUE" ] || [ -z "$FR_ID" ] || [ -z "$NEW" ] || [ "$#" -gt 4 ]; then
  echo "usage: $(basename "$0") <queue.md> <FR-ID> <STATUS> [FID]" >&2
  echo "  STATUS: $QUEUE_KNOWN_LABELS" >&2
  echo "  FID: 그 행의 FID 칸도 함께 채운다(YYYYMMDD-slug). IMPL_DONE 은 FID 칸이 채워져 있어야 한다." >&2
  exit 2
fi
FID_RE='^[0-9]{8}-[a-z0-9-]+$'
if [ -n "$NEW_FID" ] && ! printf '%s' "$NEW_FID" | grep -qE "$FID_RE"; then
  echo "QUEUE-SET: FID 형식이 아니다 '$NEW_FID' (YYYYMMDD-slug)" >&2; exit 1
fi
[ -f "$QUEUE" ] || { echo "QUEUE-SET: 파일 없음 ($QUEUE)" >&2; exit 2; }

NEW=$(queue::qnorm "$NEW")
# 라벨 검증 — 단일 출처 목록과 **정확히** 일치해야 한다.
#   extglob `@(...)` 을 쓰지 않는다: 셸 옵션에 의존하면 호출 환경에 따라 검증이 조용히
#   꺼진다 — 이 FID 가 막으려는 "게이트가 소리 없이 안 도는" 상황과 같은 형태다.
#   IFS 조작도 쓰지 않는다: 전역 IFS 를 바꾸면 그 구간의 모든 분리 동작이 영향을 받고,
#   중간에 early-return 이 생기면 복원이 누락된다(semgrep bash.lang.security.ifs-tampering).
#   구분자로 감싼 부분문자열 매칭이면 IFS 도 서브셸도 필요 없다.
_label_ok=0
case "|${QUEUE_KNOWN_LABELS}|" in
  *"|${NEW}|"*) _label_ok=1 ;;
esac
if [ "$_label_ok" -ne 1 ]; then
  echo "QUEUE-SET: 알 수 없는 라벨 '$NEW' — 허용: $QUEUE_KNOWN_LABELS" >&2; exit 1
fi

# 대상 행 탐색 — 첫 컬럼(FR-ID)이 정확히 일치하는 표 행만.
#   qnorm 으로 기존 표기 장식도 함께 흡수해 매칭한다.
matches=$(awk -F'|' -v want="$FR_ID" "$QUEUE_AWK_QNORM"'
  /^[[:space:]]*\|/ { if (qnorm($2) == want) print NR }
' "$QUEUE")

count=$(printf '%s\n' "$matches" | grep -c '[0-9]' || true)
if [ "$count" -eq 0 ]; then
  echo "QUEUE-SET: FR-ID '$FR_ID' 미발견 ($QUEUE)" >&2; exit 1
fi
if [ "$count" -gt 1 ]; then
  echo "QUEUE-SET: FR-ID '$FR_ID' 가 ${count}행에 중복 — 어느 행을 갱신할지 판정 불가" >&2
  exit 1
fi

lineno=$(printf '%s\n' "$matches" | grep -m1 '[0-9]')

# FID 칸 (20261009) — batch PR 게이트·RELEASE_READY·게이트 전파는 이 칸으로 그 FR 의 산출물을 찾는다.
#   종전엔 모델이 표를 손으로 고쳐 채웠고, 비어 있으면 검사가 그 행을 건너뛰었다. 이제 스크립트가 채우고,
#   FID 칸이 비어 있는 행은 IMPL_DONE 이 될 수 없다(산출물을 찾을 수 없는 완료 행을 만들지 않는다).
#   표 꼴: `| FR-ID | FID | 설명 | Status |` — Status 는 5번째 필드다. 칸이 모자란 표에는 FID 칸이 없다.
rowinfo=$(awk -v ln="$lineno" -F'|' "$QUEUE_AWK_QNORM"'
  NR == ln { last = 0; for (i = NF; i >= 1; i--) { if (qnorm($i) != "") { last = i; break } } print last "\t" qnorm($3); exit }
' "$QUEUE")
row_last=${rowinfo%%$'\t'*}; cur_fid=${rowinfo#*$'\t'}
has_fid_col=0; [ "${row_last:-0}" -ge 5 ] && has_fid_col=1
if [ -n "$NEW_FID" ] && [ "$has_fid_col" -ne 1 ]; then
  echo "QUEUE-SET: 이 행에는 FID 칸이 없다(칸 수 부족) — FID 를 쓸 수 없다. 표 꼴: | FR-ID | FID | 설명 | Status |" >&2; exit 1
fi
eff_fid="${NEW_FID:-$cur_fid}"
fid_ok=0; printf '%s' "$eff_fid" | grep -qE "$FID_RE" && fid_ok=1
if [ "$has_fid_col" -eq 1 ] && [ "$NEW" = "IMPL_DONE" ] && [ "$fid_ok" -ne 1 ]; then
  echo "QUEUE-SET: $FR_ID 의 FID 칸이 FID 가 아니다('${cur_fid:-(빈칸)}') — IMPL_DONE 으로 바꾸지 않았다." >&2
  echo "  FID 를 함께 준다: $(basename "$0") $QUEUE $FR_ID IMPL_DONE <FID>" >&2
  echo "  (게이트는 FID 칸으로 그 FR 의 evidence·리뷰 산출물을 찾는다 — 비어 있으면 검사할 수 없다.)" >&2
  exit 1
fi

# 마지막 비어있지 않은 컬럼만 교체. 나머지 컬럼은 원문 그대로 둔다.
tmp=$(mktemp) || exit 1
QS_FID="$NEW_FID" awk -v ln="$lineno" -v new="$NEW" -F'|' "$QUEUE_AWK_QNORM"'
  NR != ln { print; next }
  {
    # 마지막 비어있지 않은 필드 index 를 찾는다 (trailing "|" 로 생기는 빈 필드 건너뜀)
    last = 0
    for (i = NF; i >= 1; i--) { if (qnorm($i) != "") { last = i; break } }
    if (last == 0) { print; next }
    out = ""
    for (i = 1; i <= NF; i++) {
      v = (i == last) ? " " new " " : $i
      if (i == 3 && last >= 5 && ENVIRON["QS_FID"] != "") v = " " ENVIRON["QS_FID"] " "
      out = (i == 1) ? v : out "|" v
    }
    print out
  }
' "$QUEUE" > "$tmp" || { rm -f "$tmp"; echo "QUEUE-SET: 갱신 실패" >&2; exit 1; }

# 안전 검증 — 행 수가 바뀌면 표가 깨진 것이다. 덮어쓰지 않는다.
before=$(wc -l < "$QUEUE"); after=$(wc -l < "$tmp")
if [ "$before" != "$after" ]; then
  rm -f "$tmp"
  echo "QUEUE-SET: 행 수 변동 ($before → $after) — 갱신 중단" >&2; exit 1
fi

cat "$tmp" > "$QUEUE" && rm -f "$tmp"
echo "QUEUE-SET: $FR_ID → $NEW${NEW_FID:+ · FID $NEW_FID} (L$lineno)"
if [ "$has_fid_col" -eq 1 ] && [ "$fid_ok" -ne 1 ] && [ "$NEW" = "PLAN_DONE" ]; then
  echo "QUEUE-SET: 경고 — $FR_ID 의 FID 칸이 아직 FID 가 아니다('${cur_fid:-(빈칸)}'). FID 를 함께 준다: … $FR_ID PLAN_DONE <FID> (IMPL_DONE 은 FID 없이는 거부된다)"
fi
