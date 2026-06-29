#!/usr/bin/env bash
# self-config-collect.sh — specops 플러그인 자기 설정 표면 read-only 번들
# AC-1·AC-2·AC-9. read-only: find/cat/printf/wc 만, 쓰기 0.
# 공백 포함 경로 안전: find -print0 + while read -d '' (단어분리 없음, bash 3.2 호환).
#   정렬 미적용 — macOS(BSD) sort 는 -z(NUL) 미지원. 감사 번들은 파일 순서 무관.
set -u
ROOT="${1:-.}"

# AC-9: 플러그인 마커 검증 — 부재 시 거부 (사용자 임의 경로 차단)
if [ ! -f "$ROOT/.claude-plugin/plugin.json" ]; then
  echo "self-config-collect: specops 플러그인 루트 아님 (.claude-plugin/plugin.json 부재) — 거부" >&2
  exit 2
fi

bundle=""
surfaces=0  # 수집된 표면 파일 누적 (AC-2: 빈손 명시용)
_emit() {  # label; NUL 구분 경로를 stdin 으로 수신 (공백 경로 안전)
  local label="$1"
  local f n=0
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    bundle="${bundle}"$'\n'"===== ${label}: ${f#$ROOT/} ====="$'\n'"$(cat "$f")"
    n=$((n+1))
    surfaces=$((surfaces+1))
  done
  # AC-2: 라벨별 0건(표면 미발견) 시 stderr 경고 1줄 (read-only — 쓰기 아님)
  [ "$n" -eq 0 ] && echo "self-config-collect: 경고 — ${label} 표면 미발견" >&2
}

# process substitution `< <(...)` — 같은 셸 실행이라 bundle/surfaces 누적 유지 (파이프 서브셸 회피)
_emit hook     < <(find "$ROOT/hooks" -maxdepth 1 -name '*.sh' -print0 2>/dev/null)
_emit skill    < <(find "$ROOT/skills" -maxdepth 2 -name 'SKILL.md' -print0 2>/dev/null)
_emit rules    < <(printf '%s\0' "$ROOT/hooks/rules.jsonl")
_emit plugin   < <(printf '%s\0' "$ROOT/.claude-plugin/plugin.json")
_emit settings < <(find "$ROOT" -maxdepth 2 -name 'settings*.json' -not -path '*/.git/*' -print0 2>/dev/null)

printf '%s\n' "$bundle"
# AC-2: 전체 표면 0건 시 빈손 명시 (graceful)
[ "$surfaces" -eq 0 ] && echo "self-config-collect: 경고 — 수집된 표면 0건" >&2
echo "self-config-collect: 번들 완료 (read-only, surfaces=${surfaces}, lines=$(printf '%s' "$bundle" | wc -l))" >&2
exit 0
