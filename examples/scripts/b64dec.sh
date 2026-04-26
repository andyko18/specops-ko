#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: b64dec.sh [BASE64_STRING]\n'
  printf '       echo BASE64_STRING | b64dec.sh\n\n'
  printf 'Base64 decode a string.\n'
}

decode() {
  local input="$1"
  # 허용 문자셋 외 입력은 직접 거부 (macOS base64 -D lenient 방어)
  if printf '%s' "$input" | grep -qE '[^A-Za-z0-9+/=]'; then
    printf 'Error: decode failed — input is not valid base64\n' >&2
    return 1
  fi
  # 길이 4배수 검사 — macOS base64 -D가 패딩 누락 입력을 부분 디코딩함
  local len=${#input}
  if [ $((len % 4)) -ne 0 ]; then
    printf 'Error: decode failed — input is not valid base64\n' >&2
    return 1
  fi
  local flag="-d"
  [ "$(uname)" = "Darwin" ] && flag="-D"
  if ! printf '%s' "$input" | base64 "$flag" 2>/dev/null; then
    printf 'Error: decode failed — input is not valid base64\n' >&2
    return 1
  fi
}

if [ $# -ge 1 ]; then
  case "$1" in
    --help) usage; exit 0 ;;
    *)      decode "$1" || exit 1 ;;
  esac
elif [ -t 0 ]; then
  usage; exit 1
else
  input=$(cat)
  decode "$input" || exit 1
fi
