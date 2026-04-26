#!/usr/bin/env bash
set -uo pipefail

usage() {
  printf 'Usage: urlencode.sh [TEXT]\n'
  printf '       echo TEXT | urlencode.sh\n\n'
  printf 'Percent-encode TEXT (RFC 3986, safe="").\n'
}

encode() {
  printf '%s' "$1" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))"
}

if [ $# -gt 0 ]; then
  encode "$1"
elif [ ! -t 0 ]; then
  input=$(cat)  # command substitution strips trailing newlines; use arg form to preserve them
  if [ -z "$input" ]; then
    usage >&2
    exit 1
  fi
  encode "$input"
else
  usage >&2
  exit 1
fi
