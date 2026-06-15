#!/usr/bin/env bash
# session-progress.md FID 섹션 자동 append helper (v0.4-pre P1 신설)
# Usage: scripts/session-progress-append.sh <FID> <command> <status> [memo] [feature-name]
# - FID:     20260426-epoch-iso-cli 형식
# - command: /specify, /clarify, /plan, /tasks, /implement, /verify, /request-review, /receive-review 등
# - status:  완료 | 진행 | BLOCK | DONE | PASS | FAIL 등
# - memo:    선택 — 산출 파일·결과 요약 (예: "spec.md, AC.md")
# - feature-name: 선택 — FID 섹션 생성 시 헤더에 추가 (예: "한국어 URL Slug 변환 CLI")
#
# 동작:
#   1. .specops/session-progress.md 부재 시 templates에서 자동 생성 (ensure-session-progress.sh 호출)
#   2. FID 섹션 (## <FID>) 없으면 파일 상단 (## <FID-1> 자리) 에 신규 섹션 prepend
#   3. 있으면 해당 섹션 첫 줄에 "- <ts> <command> <status> (<memo>)" prepend
#
# 멱등 안전:
#   - 같은 (FID, command, status, memo) 한 줄이 이미 섹션 첫 줄이면 중복 추가 안 함
#
# 참조: templates/session-progress.md (포맷 정의), 마스터 plan v0.4-pre P1

set -u

if [ "$#" -lt 3 ]; then
  cat <<EOF >&2
usage: $0 <FID> <command> <status> [memo] [feature-name]
  FID 형식: YYYYMMDD-kebab-slug (예: 20260426-epoch-iso-cli)
  command:  /specify, /clarify, /plan, /tasks, /implement, /verify 등
  status:   완료 | 진행 | BLOCK | DONE | PASS | FAIL
  memo:     선택, 산출 파일·결과 요약
  feature-name: 선택, FID 섹션 헤더 부속 (신규 섹션 생성 시만)
EOF
  exit 2
fi

FID=$1
COMMAND=$2
STATUS=$3
MEMO=${4:-}
FEATURE=${5:-}

# FID 포맷 검증
if ! printf '%s' "$FID" | grep -Eq '^[0-9]{8}-[a-z0-9-]+$'; then
  echo "error: invalid FID format '$FID' (expected YYYYMMDD-kebab-slug)" >&2
  exit 1
fi

TARGET=".specops/session-progress.md"

# 파일 부재 시 ensure-session-progress.sh 호출하여 생성
if [ ! -f "$TARGET" ]; then
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  plugin_root=$(dirname "$script_dir")
  bash "$plugin_root/hooks/ensure-session-progress.sh" >/dev/null 2>&1
  if [ ! -f "$TARGET" ]; then
    echo "error: failed to create $TARGET" >&2
    exit 1
  fi
fi

# 이중화 — prepend 직전 현 상태를 .bak 1세대로 백업 (best-effort, 실패해도 prepend 계속 — AC-2)
[ -f "$TARGET" ] && cp "$TARGET" "$TARGET.bak" 2>/dev/null || true

TS=$(date +"%Y-%m-%d %H:%M")
LINE="- $TS $COMMAND $STATUS"
if [ -n "$MEMO" ]; then
  LINE="$LINE ($MEMO)"
fi

# FID 섹션 존재 여부 확인
SECTION_HEADER="## $FID"
if grep -qF "$SECTION_HEADER" "$TARGET"; then
  # 섹션 존재 — 섹션 직후 첫 빈 줄 다음에 LINE prepend (멱등 체크 후)
  # 멱등 — 섹션 전체 스캔 (AC-5): FID 섹션 내 동일 line 존재 시 추가 skip
  already=$(LINE="$LINE" FID="$FID" awk '
    /^## / { in_s = ($0 == "## " ENVIRON["FID"] || index($0, "## " ENVIRON["FID"] " ") == 1) ? 1 : 0 }
    in_s && $0 == ENVIRON["LINE"] { found = 1 }
    END { print (found ? "1" : "0") }
  ' "$TARGET")
  if [ "$already" = "1" ]; then
    echo "already present (idempotent): $FID"
    exit 0
  fi
  # awk로 처리: ## <FID> 이후 첫 빈 줄 만나면 LINE 추가, 그 다음 기존 줄들
  TMP=$(mktemp)
  LINE="$LINE" FID="$FID" awk '
    BEGIN { added = 0; in_section = 0 }
    /^## / {
      if (in_section && !added) { print ENVIRON["LINE"]; added = 1 }
      if ($0 == "## " ENVIRON["FID"] || index($0, "## " ENVIRON["FID"] " ") == 1) {
        in_section = 1
        print
        next
      } else {
        in_section = 0
      }
    }
    in_section && !added && /^- / {
      if ($0 != ENVIRON["LINE"]) { print ENVIRON["LINE"] }
      added = 1
      print
      next
    }
    { print }
    END {
      if (in_section && !added) print ENVIRON["LINE"]
    }
  ' "$TARGET" > "$TMP"
  mv "$TMP" "$TARGET"
  echo "appended to existing section: $FID"
else
  # 섹션 없음 — 파일 상단 (구분선 --- 다음 첫 ## 자리) 에 신규 섹션 prepend
  HEADER="## $FID"
  if [ -n "$FEATURE" ]; then
    HEADER="$HEADER · $FEATURE"
  fi
  TMP=$(mktemp)
  HEADER="$HEADER" LINE="$LINE" awk '
    BEGIN { added = 0 }
    /^---$/ && !added {
      print
      print ""
      print ENVIRON["HEADER"]
      print ""
      print ENVIRON["LINE"]
      print ""
      added = 1
      next
    }
    { print }
  ' "$TARGET" > "$TMP"
  mv "$TMP" "$TARGET"
  echo "created new section: $HEADER"
fi
