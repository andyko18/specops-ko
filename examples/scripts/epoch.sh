#!/usr/bin/env bash
set -u

IS_GNU_DATE=false

usage() {
  printf 'Usage: epoch.sh [VALUE]\n'
  printf '       echo VALUE | epoch.sh\n\n'
  printf 'Convert between epoch integer and ISO 8601 UTC string.\n'
  printf '  epoch (10-digit sec / 13-digit ms) → ISO 8601 UTC\n'
  printf '  ISO 8601 (Z or +00:00 suffix)      → epoch integer\n'
}

detect_platform() {
  if date --version >/dev/null 2>&1; then
    IS_GNU_DATE=true
  fi
}

epoch_to_iso() {
  local epoch="$1"
  local len="${#epoch}"
  if [ "$len" -eq 10 ]; then
    local result
    if $IS_GNU_DATE; then
      result=$(TZ=UTC date -d "@${epoch}" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    else
      result=$(TZ=UTC date -r "${epoch}" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    fi
    if [ -z "$result" ]; then
      printf 'epoch.sh: error: cannot convert epoch: %s\n' "$epoch" >&2; exit 1
    fi
    printf '%s\n' "$result"
  elif [ "$len" -eq 13 ]; then
    local sec=$((epoch / 1000))
    local ms=$((epoch % 1000))
    local iso_sec
    if $IS_GNU_DATE; then
      iso_sec=$(TZ=UTC date -d "@${sec}" "+%Y-%m-%dT%H:%M:%S")
    else
      iso_sec=$(TZ=UTC date -r "${sec}" "+%Y-%m-%dT%H:%M:%S")
    fi
    if [ -z "$iso_sec" ]; then
      printf 'epoch.sh: error: cannot convert epoch: %s\n' "$epoch" >&2; exit 1
    fi
    printf '%s.%03dZ\n' "$iso_sec" "$ms"
  else
    printf 'epoch.sh: error: unrecognized epoch length: %s\n' "$epoch" >&2; exit 1
  fi
}

iso_to_epoch() {
  local iso="$1"
  local normalized="${iso/+00:00/Z}"
  local has_ms=false
  local ms_part=""

  if printf '%s' "$normalized" | grep -qE '\.[0-9]+Z$'; then
    ms_part=$(printf '%s' "$normalized" | grep -oE '\.[0-9]+' | tr -d '.')
    normalized=$(printf '%s' "$normalized" | sed 's/\.[0-9]*//')
    has_ms=true
  fi

  local sec
  if $IS_GNU_DATE; then
    local gnu_input="${normalized/Z/ UTC}"
    sec=$(TZ=UTC date -d "$gnu_input" "+%s" 2>/dev/null)
  else
    sec=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$normalized" "+%s" 2>/dev/null)
  fi

  if [ -z "$sec" ]; then
    printf 'epoch.sh: error: cannot parse ISO 8601: %s\n' "$1" >&2; exit 1
  fi

  if $has_ms; then
    local ms_3
    ms_3=$(printf '%s000' "$ms_part" | cut -c1-3)
    printf '%s%s\n' "$sec" "$ms_3"
  else
    printf '%s\n' "$sec"
  fi
}

dispatch() {
  local input="$1"
  if [ -z "$input" ]; then
    printf 'epoch.sh: error: empty input\n' >&2; exit 1
  fi
  if printf '%s' "$input" | grep -qE '^[0-9]+$'; then
    epoch_to_iso "$input"
  else
    iso_to_epoch "$input"
  fi
}

detect_platform
if [ $# -ge 1 ]; then
  if [ "$1" = "--help" ]; then usage; exit 0; fi
  dispatch "$1"
else
  input=$(cat)
  dispatch "$input"
fi
