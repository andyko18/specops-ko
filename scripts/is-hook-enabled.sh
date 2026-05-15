#!/usr/bin/env bash
# specops config YAML hook 활성 여부 판단
# Usage: is-hook-enabled.sh <hook-name>
# Env:   SPECOPS_CONFIG=<path> (기본: ~/.specops/config.yaml)
set -u

HOOK_NAME="${1:?usage: is-hook-enabled.sh <hook-name>}"
CONFIG="${SPECOPS_CONFIG:-$HOME/.specops/config.yaml}"

# config 파일 없으면 기본 활성 (AC-14)
[ -f "$CONFIG" ] || exit 0

# pyyaml 가용성 확인 (AC-18: 미설치 시 graceful exit 0 + 경고)
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "pyyaml not available, defaulting to enabled" >&2
  exit 0
fi

# YAML 파싱: 우선순위 enforce_all_hooks > enforce_all_disabled > hooks.<name>.enabled
SPECOPS_CONFIG="$CONFIG" SPECOPS_HOOK_NAME="$HOOK_NAME" python3 - <<'PYEOF'
import yaml, sys, os
config_path = os.environ['SPECOPS_CONFIG']
hook = os.environ['SPECOPS_HOOK_NAME']
with open(config_path) as f:
    cfg = yaml.safe_load(f) or {}
profile_name = cfg.get('profile', '')
profiles = cfg.get('profiles', {})
profile = profiles.get(profile_name, {})
# strict override: enforce_all_hooks (AC-17)
if profile.get('enforce_all_hooks'):
    sys.exit(0)
# none override: enforce_all_disabled (AC-21)
if profile.get('enforce_all_disabled'):
    sys.exit(1)
# 개별 hook 설정 (AC-15, AC-16)
hooks = cfg.get('hooks', {})
hook_cfg = hooks.get(hook, {})
enabled = hook_cfg.get('enabled', True)
sys.exit(0 if enabled else 1)
PYEOF
