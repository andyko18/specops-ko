#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: b64enc.sh [STRING]\n'
  printf '       echo STRING | b64enc.sh\n\n'
  printf 'Base64 encode a string (single-line output, no line wrapping).\n'
}

encode() {
  printf '%s' "$1" | base64 | tr -d '\n'
  printf '\n'
}

if [ $# -ge 1 ]; then
  case "$1" in
    --help) usage; exit 0 ;;
    *)      encode "$1" ;;
  esac
elif [ -t 0 ]; then
  usage; exit 1
else
  input=$(cat)
  encode "$input"
fi
