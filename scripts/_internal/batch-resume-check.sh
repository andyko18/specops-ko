#!/usr/bin/env bash
# batch-resume-check.sh — 미완 batch 자동 표면화 (FID 20260828-batch-resume-teeth)
#
# Usage: batch-resume-check.sh [--hook]
#   항상 exit 0. 미완 batch 가 있을 때만 stdout 1~2줄, 그 외 무출력.
#
# 왜 필요한가 (argus batch-20260729 실측):
#   FR 31건이 IMPL_DONE 에서 멈췄고 Phase 3 완료(batch 보안·통합·성능 → batch PR)가
#   실행되지 않은 채 방치됐다. `ACTIVE` 마커는 **이미 재개 키**인데(start-all Phase 0 이
#   `.specops/batch-*/ACTIVE` 로 진행 중 batch 를 찾는다) 읽는 곳이 `/start-all` 재호출과
#   PR 게이트뿐이라 **사용자가 먼저 물어야만** 알 수 있었다.
#   `/status`(show-fid-status)·`reconcile-check` 는 batch 를 아예 모른다(batch 참조 0건).
#
#   즉 재개 키도 있고 SessionStart 주입 경로도 있는데 **둘을 잇는 판독기만 없었다.**
#   이 스크립트가 그 한 칸이다 — 새 상태를 만들지 않고 기존 마커를 읽기만 한다.
#
# 왜 FID 체인은 멀쩡한데 batch 만 죽는가:
#   FID 체인은 chain.yaml + `## 다음 skill` + 훅 3중으로 잠겨 있다. 그 위를 도는 batch
#   루프는 `commands/start-all.md` 산문뿐이라, 모델이 N개 FR 을 도는 내내 루프를 놓지
#   않아야만 성립한다. 세션이 끝나면 이어받을 주체가 없다.
#
# 설계 — **차단하지 않는다**:
#   경고도 실패도 아니고 **상태 보고**다. batch 를 의도적으로 중단한 경우도 정상이며,
#   그때 매 세션 에러를 내면 잡음이다. 보이기만 하면 사람이 판단한다.
set -u

MODE="${1:-}"
SPECOPS="${SPECOPS_ROOT:-.specops}"

[ -d "$SPECOPS" ] || exit 0

# queue-lib — 라벨 정규화 단일 출처.
#   ★ 여기서 자기 정규식을 새로 쓰면 선행 FID(20260828-queue-label-drift)가 고친
#     드리프트가 이 판독기에서 그대로 재발한다. 소비자는 반드시 공유 규칙을 쓴다.
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/queue-lib.sh"
[ -f "$LIB" ] || exit 0
# shellcheck source=/dev/null
. "$LIB"

# ACTIVE 마커 탐색 — start-all Phase 0·pretool 훅과 **동일 관용구**.
#   마커는 PR 성공 시 Step D 가 제거한다 → 존재 = 미완.
found=0
for marker in "$SPECOPS"/batch-*/ACTIVE; do
  [ -f "$marker" ] || continue
  batch_dir=$(dirname "$marker")
  batch_id=$(basename "$batch_dir")
  queue="$batch_dir/queue.md"
  # 판정 불가는 조용히 넘어간다 — 근거 없이 단정하지 않는다.
  [ -f "$queue" ] || continue

  # 표 행에서 Status 집계. SKIP 은 분모에서 뺀다(시드·공통부 스코프는 batch 대상이 아니다).
  counts=$(awk -F'|' "$QUEUE_AWK_QNORM"'
    /^[[:space:]]*\|/ {
      id = qnorm($2)
      # 헤더(`| FR-ID |`)가 `^FR-` 에 걸린다 — 리터럴로 제외한다. 구분선(`---`)은 자연 배제.
      if (id == "FR-ID" || id !~ /^FR-/) next
      st = ""
      for (i = NF; i >= 1; i--) { if (qnorm($i) != "") { st = qnorm($i); break } }
      if (st == "SKIP") next
      total++
      if (st ~ /^(IMPL_DONE|MERGED)$/) done_n++
    }
    END { printf "%d %d", done_n + 0, total + 0 }
  ' "$queue")
  done_n=${counts% *}; total=${counts#* }

  [ "${total:-0}" -gt 0 ] || continue   # 추적 FR 0건 — 보고할 진행률이 없다

  found=1
  if [ "$done_n" -eq "$total" ]; then
    # argus 가 정확히 이 상태였다. "완료" 가 아니라 "다음 단계가 안 돌았다" 를 말해야 재개된다.
    echo "⚠️ 미완 batch — ${batch_id}: 전 FR 완료(${done_n}/${total})인데 **Phase 3 완료 미실행**(batch 보안·통합·성능 → batch PR). ACTIVE 마커가 남아 있다."
    echo "   재개: /start-all 재호출 시 Phase 0 이 이 batch 를 재개한다. 상태 점검은 bash \${CLAUDE_PLUGIN_ROOT}/scripts/batch-state.sh $batch_dir"
  else
    echo "⚠️ 미완 batch — ${batch_id}: ${done_n}/${total} 완료. ACTIVE 마커가 남아 있다."
    echo "   재개: /start-all 재호출 시 Phase 0 이 이 batch 를 재개한다(PENDING/PLAN_DONE 부터)."
  fi
done

[ "$found" -eq 1 ] || exit 0
[ "$MODE" = "--hook" ] && exit 0
exit 0
