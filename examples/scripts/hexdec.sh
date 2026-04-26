#!/usr/bin/env bash
set -uo pipefail

usage() {
  printf 'Usage: hexdec.sh [HEX_STRING]\n'
  printf '       echo HEX_STRING | hexdec.sh\n\n'
  printf 'Decode a hex string to text.\n'
}

validate_hex() {
  local input="$1"
  if [ $(( ${#input} % 2 )) -ne 0 ]; then
    printf 'Error: hex string has odd length\n' >&2
    exit 1
  fi
  if printf '%s' "$input" | grep -qE '[^0-9a-fA-F]'; then
    printf 'Error: invalid hex character\n' >&2
    exit 1
  fi
}

decode() {
  local input="$1"
  if [ -z "$input" ]; then
    printf '\n'
    return
  fi
  validate_hex "$input"
  printf '%s' "$input" | xxd -r -p
  printf '\n'
}

if [ $# -gt 0 ]; then
  decode "$1"
elif [ ! -t 0 ]; then
  input=$(cat)
  decode "$input"
else
  usage >&2
  exit 1
fi
