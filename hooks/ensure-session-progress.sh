#!/usr/bin/env bash
# specops-ko v0.2 · pre-command hook
# .specops/session-progress.md 부재 시 templates로부터 자동 생성
# 존재하면 noop (idempotent). `.specops/` 디렉토리가 없으면 noop — 디렉토리는 만들지 않는다(관할 한정).
# 사용 예: hooks/ensure-session-progress.sh [project-name]
set -u

# v0.2 묶음 3: config guard — disabled 시 조용히 exit 0
script_dir_guard=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root_guard=$(dirname "$script_dir_guard")
bash "$plugin_root_guard/scripts/_internal/is-hook-enabled.sh" ensure-session-progress || exit 0

# 하위 디렉토리에서 발화한 세션 — cwd 에 `.specops/` 가 없고 프로젝트 루트에 있으면 루트 기준으로 본다
#   (posttool·stop 과 같은 앵커). cwd 에 있으면 그대로 둔다 — session-progress-append 가 이 스크립트를 cwd 기준으로 부른다.
if [ ! -e ".specops" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR}/.specops" ]; then
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
fi

target=".specops/session-progress.md"
if [ -f "$target" ]; then
  exit 0
fi

# 관할 한정 — `.specops/` 가 없는 저장소에는 아무것도 만들지 않는다(5원칙 4 주권).
#   Stop 훅은 플러그인이 설치된 모든 저장소에서 발화한다. 여기서 디렉토리를 만들면 그 저장소가
#   관할로 편입돼 이후 커밋이 R-1 차단 대상이 된다(실측 20261009: 플러그인을 쓰지 않는 저장소 4곳에
#   session-progress.md 만 든 `.specops/` 가 남았고, 하위 디렉토리에서 발화한 `.specops/.specops` 도 있었다).
#   디렉토리는 관할을 여는 쪽이 만든다 — `/init-project` · specifying-ko 의 FID 생성 · session-progress-append.
#   symlink 는 아래 가드가 사유를 말하도록 통과시킨다.
[ -d ".specops" ] || [ -L ".specops" ] || exit 0

# symlink 가드 (#144 log_friction 대칭) — .specops 디렉토리 또는 target 이 symlink 면
# mkdir -p / sed > / cp 가 따라가 외부 path 로 관통. 세션 훅이라 조용히 exit 0 (fail-open).
[ ! -L ".specops" ] || { echo "ensure-session-progress: .specops 가 symlink — 쓰기 거부(path-escape 차단)" >&2; exit 0; }
[ ! -L "$target" ] || { echo "ensure-session-progress: $target 가 symlink — 쓰기 거부" >&2; exit 0; }

# 이중화 복원 — target 부재 시 .bak 있으면 복원 (빈 template 대신 작업 이력 유지 — AC-3, 조용히, template 무관)
if [ -f "$target.bak" ]; then
  cp "$target.bak" "$target" 2>/dev/null && exit 0
fi

# 플러그인 루트 경로 해결: 이 스크립트는 <plugin-root>/hooks/ 에 위치
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(dirname "$script_dir")
template="$plugin_root/templates/session-progress.md"

if [ ! -f "$template" ]; then
  echo "error: template not found at $template" >&2
  exit 1
fi

project=${1:-$(basename "$(pwd)")}

# <project-name> 플레이스홀더 치환 후 복사
# sed 메타문자 안전화 — 디렉토리명에 \ & / | 가 있어도 표현식 미파손 (fallback basename 경로 대비)
esc_project=${project//\\/\\\\}
esc_project=${esc_project//&/\\&}
esc_project=${esc_project//|/\\|}
sed "s|<project-name>|${esc_project}|g" "$template" > "$target"
echo "created: $target (project=$project)"
