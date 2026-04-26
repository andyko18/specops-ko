#!/usr/bin/env bash
set -uo pipefail

usage() {
  printf 'Usage: urldecode.sh [TEXT]\n'
  printf '       echo TEXT | urldecode.sh\n\n'
  printf 'Decode percent-encoded TEXT (+ is NOT treated as space).\n'
}

decode() {
  printf '%s' "$1" | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))"
}

if [ $# -gt 0 ]; then
  decode "$1"
elif [ ! -t 0 ]; then
  input=$(cat)  # command substitution strips trailing newlines; use arg form to preserve them
  if [ -z "$input" ]; then
    usage >&2
    exit 1
  fi
  decode "$input"
else
  usage >&2
  exit 1
fi
