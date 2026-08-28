#!/usr/bin/env bash
# library-only
# queue-lib.sh — queue.md Status 라벨 정규화 단일 출처 (FID 20260828-queue-label-drift)
#
# 왜 필요한가 (실측 계기 — argus batch-20260729):
#   생성기 `init-batch-queue.sh` 는 Status 를 맨 문자열(`PENDING`)로 쓰는데,
#   이후 갱신은 `commands/start-all.md` 산문 지시를 받은 **모델이 손으로** 한다.
#   모델이 `**IMPL_DONE**`(굵게)로 적었고, 소비자 3곳이 전부 `^IMPL_DONE` 앵커라
#   전건 불일치했다. 결과는 오탐이 아니라 **무음 통과**였다 —
#   산출물·review-skip 검사가 IMPL_DONE 행만 수집하므로 **대상 0건 → 조용히 pass**.
#   FR 31건이 무검증으로 남았고 아무도 red 를 보지 못했다.
#
# 왜 읽는 쪽인가:
#   쓰는 쪽(모델 손편집)은 강제할 수단이 없다. 소비자는 셋인데 정규화 지점은
#   하나로 수렴하므로, 읽는 쪽에서 흡수하는 것이 가장 값싸고 넓게 막는다.
#   (근본 해법은 `queue-set-status.sh` 로 손편집 자체를 없애는 것 — 이 FID 가 함께 낸다.)
#
# 흡수 범위 — **표기 장식만** 벗긴다. 라벨 자체는 바꾸지 않는다:
#   `**IMPL_DONE**` · `` `IMPL_DONE` `` · `  IMPL_DONE  ` · `IMPL_DONE\r` → `IMPL_DONE`
#   `DONE`·`PLAN_DONE` 같은 **다른 라벨은 그대로 둔다** — 정규화가 과하면
#   미완을 완료로 만들어 이 FID 가 막으려는 것보다 나쁜 결함이 된다.
#
# 사용 (awk):
#   awk "$QUEUE_AWK_QNORM"'{ st = qnorm($NF); ... }'
# 사용 (shell):
#   label=$(queue::qnorm "$raw")

# awk 함수 정의 — 각 소비자가 자기 awk 프로그램 앞에 붙여 쓴다.
#   ★ 셸 함수로 감싸 파이프하지 않는 이유: 소비자들이 awk 안에서 필드 단위로
#     정규화해야 하는데, 밖에서 줄 단위로 처리하면 어느 필드가 Status 인지
#     다시 판정해야 해 그 로직이 또 3벌로 갈라진다.
# shellcheck disable=SC2034  # 소비 스크립트가 source 후 awk 프로그램에 삽입한다
QUEUE_AWK_QNORM='
function qnorm(s) {
  gsub(/\r$/, "", s)
  gsub(/^[ \t]+|[ \t]+$/, "", s)
  gsub(/^\*\*|\*\*$/, "", s)      # 굵게 (실측 발생 형태)
  gsub(/^`|`$/, "", s)            # 인라인 코드
  gsub(/^_|_$/, "", s)            # 기울임
  gsub(/^[ \t]+|[ \t]+$/, "", s)  # 장식 제거 후 잔여 공백
  return s
}
'

# 셸 측 등가 — 스크립트가 awk 밖에서 라벨 1개를 다룰 때.
queue::qnorm() {  # <raw> → 정규화 라벨
  local s="${1-}"
  s="${s%$'\r'}"
  s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"
  s="${s#\*\*}"; s="${s%\*\*}"
  s="${s#\`}";  s="${s%\`}"
  s="${s#_}";   s="${s%_}"
  s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# queue.md 에서 인식하는 Status 라벨 전체 — 라벨 오염 검사의 단일 출처.
#   ★ 종전엔 이 목록이 `batch-state.sh` 안에만 있었고 `--gate` 모드에서만 검사했다.
#     그래서 하류 teeth 가 꺼진 사실을 **PR 시도 전까지 아무도 몰랐다**.
#     조용한 통과를 막으려고 만든 검사가 정작 조용한 구간에서 안 돌았다.
QUEUE_KNOWN_LABELS='IMPL_DONE|MERGED|TODO|WIP|DOING|PENDING|HELD|SKIP|BLOCKED|PLAN_DONE|CODE_DONE'
