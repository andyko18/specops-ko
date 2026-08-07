#!/usr/bin/env bash
# doctor.sh — specops 설치·환경 건강 진단 (20260807, FID 20260807-specops-doctor)
# Usage: bash scripts/doctor.sh [--json]
# Exit: 0 항상 (조회 도구 — 어떤 흐름도 막지 않는다)
# 환경: SPECOPS_ROOT(기본 .specops)
#
# 왜 필요한가: validate-structure.sh 는 **플러그인 개발자용**이라 사용자 프로젝트의
#   .specops/ 상태를 보는 층이 0곳이었다. 가장 위험한 공백은 git hook 미설치 —
#   install-git-hooks.sh 는 clone 마다 수동 1회이고, 미실행 시 2단 게이트가
#   **조용히 없다**(Claude Code PreToolUse 훅은 Cursor 등 타 도구 커밋에 발화하지 않음).
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"
PLUGIN=$(cd "$(dirname "$0")/.." && pwd)
ROWS=""   # 누적 형식: id|status|detail|fix (bash 3.2 — 연상배열 미사용)

# 구분자 인젝션 차단 — 필드값(FID 디렉토리명 등)에 `|` 나 개행이 있으면 표 셀이 밀리고
#   `--json`(schema_version 있는 기계 계약) 의 fix 필드가 오염돼 **조치 문구가 유실**된다.
#   개행이면 행 자체가 위조된다. 근원이 한 곳이므로 여기서만 봉합한다.
#   순수 bash 치환만 사용 — bash 3.2 호환, 프로세스 스폰 0.
_add() {
  local a out=""
  for a in "$1" "$2" "$3" "$4"; do
    a="${a//|/\/}"                    # 구분자 → 슬래시 (삭제하면 이름이 조용히 합쳐진다)
    a="${a//$'\n'/ }"; a="${a//$'\r'/ }"
    out="${out}${out:+|}${a}"
  done
  ROWS="${ROWS}${out}"$'\n'
}

_chk_hooks() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    _add git_hooks unknown "git repo 아님 — 판정 불가" ""; return
  fi
  local hp missing=""
  hp=$(git config core.hooksPath 2>/dev/null || true)
  [ "$hp" = ".githooks" ] || missing="core.hooksPath"
  for h in pre-commit pre-push; do
    [ -x ".githooks/$h" ] || missing="${missing}${missing:+ · }$h"
  done
  if [ -z "$missing" ]; then
    _add git_hooks ok "2단 게이트 설치됨 (pre-commit · pre-push)" ""
  else
    _add git_hooks warn "누락: $missing" "bash scripts/_internal/install-git-hooks.sh"
  fi
}

_chk_memory() {
  local dir="$SPECOPS/memory" scan="$PLUGIN/scripts/_internal/scan-enrich-placeholders.sh"
  if [ ! -d "$dir" ]; then
    _add memory unknown "$dir 부재 — 부트스트랩 안 됨" "/init-project"; return
  fi
  local files
  files=$(ls "$dir"/*.md 2>/dev/null || true)
  if [ -z "$files" ]; then
    _add memory unknown "memory 문서 0건" "/init-project"; return
  fi
  if [ ! -f "$scan" ]; then
    _add memory unknown "판정기 부재 — $scan" ""; return
  fi
  # 판정 SoT 재사용 — doctor.sh 안에 placeholder 규칙을 다시 구현하지 않는다(드리프트 방지)
  local bad=0 f
  while IFS= read -r f; do            # 공백 포함 파일명 대응 (word splitting 금지)
    [ -n "$f" ] || continue
    bash "$scan" "$f" >/dev/null 2>&1 || bad=$((bad + 1))
  done <<EOF_FILES
$files
EOF_FILES
  if [ "$bad" -eq 0 ]; then
    _add memory ok "placeholder 잔존 0건" ""
  else
    _add memory warn "미채움 ${bad}건" "해당 문서를 실제 값으로 채우세요"
  fi
}

_chk_orphan() {
  local d fid names="" n=0
  for d in "$SPECOPS"/*/; do
    [ -d "$d" ] || continue
    fid=$(basename "$d")
    [ "$fid" = "memory" ] && continue
    [ -f "$d/spec.md" ] || continue
    # 경과일은 보지 않는다 — clarifications.md §Q1 확정(임계 없음, 경고만)
    if [ ! -f "$d/tasks.md" ] && [ ! -f "$d/evidence.md" ]; then
      n=$((n + 1)); names="${names}${names:+ }$fid"
    fi
  done
  if [ "$n" -eq 0 ]; then
    _add orphan_fid ok "고아 FID 없음" ""
  else
    _add orphan_fid warn "${n}건: $names" "진행하거나 정리하세요"
  fi
}

_chk_progress() {
  local sp="$SPECOPS/session-progress.md"
  if [ ! -f "$sp" ]; then
    _add progress unknown "session-progress.md 부재" ""; return
  fi
  # `/verify PASS` 를 기록한 FID 인데 evidence.md 가 없는 경우.
  #   포맷 정규식은 느슨하게 — gbrain 20260615-append-idempotency-fix:
  #   "session-progress 텍스트 소비는 출력 포맷 불변이 회귀 가드"
  # ⚠️ 줄당 프로세스 스폰 금지 — session-progress.md 는 append-only 라 선형 성장한다
  #   (실측 1,791줄). 리뷰 A/B 실측: 줄당 `printf | grep` 이 ~1.1s 를 차지해
  #   NFR-2(2초) 를 넘겼다. 순수 bash 문자열 연산만 쓴다.
  local bad="" n=0 cur=""
  while IFS= read -r line; do
    case "$line" in
      "## "*) cur="${line#\#\# }"; cur="${cur%% *}"
              # 헤더는 신뢰 입력이 아니다 — 경로 구분자·상위 참조가 섞이면 .specops 밖을
              #   프로브하게 된다(read-only 라 무해하나 무검증). 실측: 실 repo 헤더 126건 중
              #   `/`·`..` 포함 0건 — 정상 FID 를 떨어뜨리지 않는다.
              case "$cur" in */*|*..*) cur="" ;; esac ;;
      # `*"/verify"*PASS*` 는 `- ... /verify FAIL — PASSWORD 마스킹 회귀` 를 오탐한다
      #   (PASSWORD 의 PASS). 실측: 실 repo 에서 loose 113줄 = `/verify PASS` 113줄 —
      #   loose-only 0줄이라 조여도 검출력 손실이 없다.
      *) if [ -n "$cur" ] && case "$line" in *"/verify PASS"*) true ;; *) false ;; esac; then
           if [ ! -f "$SPECOPS/$cur/evidence.md" ]; then
             case " $bad " in *" $cur "*) ;; *) bad="${bad}${bad:+ }$cur"; n=$((n + 1)) ;; esac
           fi
           cur=""
         fi ;;
    esac
  done < "$sp"
  if [ "$n" -eq 0 ]; then
    _add progress ok "verify PASS 기록 ↔ evidence.md 정합" ""
  else
    # 실 repo 실측(리뷰 3회차): 불일치 83건 — 전체 나열 시 표 한 셀이 수천 자가 된다.
    #   AC-5 는 "지목"만 요구하므로 앞 5건 + "외 N건" 으로 절단한다.
    local head5 rest
    head5=$(printf '%s' "$bad" | tr ' ' '\n' | head -5 | tr '\n' ' ')
    rest=$((n - 5)); [ "$rest" -gt 0 ] && head5="${head5}외 ${rest}건"
    _add progress warn "${n}건 불일치: $head5" "evidence.md 확인 또는 /verify 재실행"
  fi
}

JSON=0
[ "${1:-}" = "--json" ] && JSON=1

# 비-specops repo 면제 — 플러그인은 자기 관할만 통제한다(5원칙 4 주권)
if [ ! -d "$SPECOPS" ]; then
  if [ "$JSON" -eq 1 ]; then
    echo '{"schema_version":1,"checks":[],"warn_count":0}'
  else
    echo "specops 미사용 프로젝트입니다 ($SPECOPS 부재) — 진단할 대상이 없습니다."
  fi
  exit 0
fi

_chk_hooks
_chk_memory
_chk_orphan
_chk_progress

if [ "$JSON" -eq 1 ]; then
  printf '%s' "$ROWS" | jq -Rs '
    [ split("\n")[] | select(length > 0) | split("|")
      | {id: .[0], status: .[1], detail: .[2], fix: .[3]} ] as $c
    | {schema_version: 1, checks: $c,
       warn_count: ([$c[] | select(.status != "ok")] | length)}'
  exit 0
fi

printf '### specops 건강 진단\n\n| 항목 | 상태 | 상세 | 조치 |\n|---|---|---|---|\n'
printf '%s' "$ROWS" | while IFS='|' read -r id st detail fix; do
  [ -n "$id" ] || continue
  case "$st" in ok) icon="✅" ;; *) icon="⚠️" ;; esac
  printf '| %s | %s | %s | %s |\n' "$id" "$icon" "$detail" "$fix"
done
exit 0
