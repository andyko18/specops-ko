#!/usr/bin/env bash
set -uo pipefail

usage() {
  printf 'Usage: hexenc.sh [TEXT]\n'
  printf '       echo TEXT | hexenc.sh\n\n'
  printf 'Encode text to lowercase hex string.\n'
}

encode() {
  printf '%s' "$1" | xxd -p | tr -d '\n'
  printf '\n'
}

if [ $# -gt 0 ]; then
  encode "$1"
elif [ ! -t 0 ]; then
  input=$(cat)
  # empty stdin is treated as "no input" (distinguishable from hexenc.sh "" which
  # explicitly encodes an empty string and outputs an empty line)
  if [ -z "$input" ]; then
    usage >&2
    exit 1
  fi
  encode "$input"
else
  usage >&2
  exit 1
fi
