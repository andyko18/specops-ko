#!/usr/bin/env bash
# 자유작업 FID 귀속/신규 판정. 종결된 lifecycle 오귀속 차단.
# Usage: freework-resolve-fid.sh <candidate-fid>
#   출력: NEW (mini-FID 생성)  |  ATTACH:<fid> (활성 FID 귀속)
set -u

fid="${1:-}"
# 1) 빈 후보 → 순수 자유작업
[ -z "$fid" ] && { echo "NEW"; exit 0; }
# 1b) FID 포맷 불량(정규식 메타문자 등) → awk 동적정규식 오판정 차단·오귀속 방지 위해 신규 처리
printf '%s' "$fid" | grep -Eq '^[0-9]{8}-[a-z0-9-]+$' || { echo "NEW"; exit 0; }

progress=".specops/session-progress.md"
[ -f "$progress" ] || { echo "ATTACH:$fid"; exit 0; }

# 2) 해당 FID 섹션의 첫 활동 줄(최신 — 섹션 헤더 바로 아래 '- ' 줄) 추출
latest=$(awk -v f="## $fid" '
  $0 ~ "^"f"( |$)" {insec=1; next}
  insec && /^## / {exit}
  insec && /^- / {print; exit}
' "$progress")

# 3) 종결 마커 검사 — 종결이면 NEW, 아니면 ATTACH
#    AC-12 의 'PR #<n>' 는 false-positive(진행중 줄 "PR #999 참조") 차단 위해 '생성' 인접 필수로 협소 적용.
#    command 슬래시 앵커(/lifecycle·/finish)로 본문 우연 매칭 배제.
if printf '%s' "$latest" | grep -qE '/(lifecycle|finish)[[:space:]]+DONE|PR[[:space:]]*#[0-9]+[[:space:]]+생성'; then
  echo "NEW"
else
  echo "ATTACH:$fid"
fi
