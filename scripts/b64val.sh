#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: b64val.sh [BASE64_STRING]\n'
  printf '       echo BASE64_STRING | b64val.sh\n\n'
  printf 'Validate a base64 string (charset + padding rules).\n'
  printf '  Exit 0 + "valid":             valid base64\n'
  printf '  Exit 1 + "invalid: <reason>": invalid\n'
}

validate() {
  local input="$1"

  if [ -z "$input" ]; then
    printf 'invalid: empty input\n'
    return 1
  fi

  if printf '%s' "$input" | grep -qE '[^A-Za-z0-9+/=]'; then
    printf 'invalid: invalid characters\n'
    return 1
  fi

  if ! printf '%s' "$input" | grep -qE '^[A-Za-z0-9+/]*={0,2}$'; then
    printf 'invalid: invalid padding\n'
    return 1
  fi

  local len=${#input}
  if [ $((len % 4)) -ne 0 ]; then
    printf 'invalid: invalid padding\n'
    return 1
  fi

  printf 'valid\n'
  return 0
}

if [ $# -ge 1 ]; then
  case "$1" in
    --help) usage; exit 0 ;;
    *)      validate "$1"; exit $? ;;
  esac
elif [ -t 0 ]; then
  usage; exit 1
else
  input=$(cat)
  validate "$input"; exit $?
fi
