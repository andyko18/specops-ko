#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: slug.sh [STRING]\n'
  printf '       echo STRING | slug.sh\n\n'
  printf 'Convert Korean/English string to URL slug.\n'
  printf '  - Korean syllables: romanized (국립국어원 revised romanization)\n'
  printf '  - Uppercase: lowercased\n'
  printf '  - Non-alphanumeric: replaced with -\n'
}

to_slug() {
  local input="$1"
  # 국립국어원 개정 로마자 표기법 고정 매핑
  # 초성 (19): ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ
  local CHO JUNG JONG
  CHO=("g" "kk" "n" "d" "tt" "r" "m" "b" "pp" "s" "ss" "" "j" "jj" "ch" "k" "t" "p" "h")
  # 중성 (21): ㅏ ㅐ ㅑ ㅒ ㅓ ㅔ ㅕ ㅖ ㅗ ㅘ ㅙ ㅚ ㅛ ㅜ ㅝ ㅞ ㅟ ㅠ ㅡ ㅢ ㅣ
  JUNG=("a" "ae" "ya" "yae" "eo" "e" "yeo" "ye" "o" "wa" "wae" "oe" "yo" "u" "wo" "we" "wi" "yu" "eu" "ui" "i")
  # 종성 (28, 0=없음): ㄱ ㄲ ㄳ ㄴ ㄵ ㄶ ㄷ ㄹ ㄺ ㄻ ㄼ ㄽ ㄾ ㄿ ㅀ ㅁ ㅂ ㅄ ㅅ ㅆ ㅇ ㅈ ㅊ ㅋ ㅌ ㅍ ㅎ
  JONG=("" "k" "kk" "ks" "n" "nj" "nh" "t" "l" "lk" "lm" "lb" "ls" "lt" "lp" "lh" "m" "p" "ps" "s" "ss" "ng" "j" "ch" "k" "t" "p" "h")

  local result=""
  local bytes i n b1 b2 b3 new_byte cp idx cho_i jung_i jong_i
  bytes=($(printf '%s' "$input" | od -An -tu1))
  i=0
  n=${#bytes[@]}

  while [ "$i" -lt "$n" ]; do
    b1=${bytes[$i]}

    if [ "$b1" -lt 128 ]; then
      # ASCII
      if [ "$b1" -ge 65 ] && [ "$b1" -le 90 ]; then
        new_byte=$((b1 + 32))
        result="${result}$(printf "\\$(printf '%03o' "$new_byte")")"
      elif { [ "$b1" -ge 97 ] && [ "$b1" -le 122 ]; } || \
           { [ "$b1" -ge 48 ] && [ "$b1" -le 57 ]; }; then
        result="${result}$(printf "\\$(printf '%03o' "$b1")")"
      else
        result="${result}-"
      fi
      i=$((i + 1))

    elif [ "$b1" -ge 224 ] && [ "$b1" -le 239 ]; then
      # 3-byte UTF-8 (BMP U+0800..U+FFFF)
      if [ $((i + 2)) -lt "$n" ]; then
        b2=${bytes[$((i+1))]}
        b3=${bytes[$((i+2))]}
        cp=$(( ((b1 & 15) << 12) | ((b2 & 63) << 6) | (b3 & 63) ))
        if [ "$cp" -ge 44032 ] && [ "$cp" -le 55203 ]; then
          # 한글 음절 U+AC00..U+D7A3
          idx=$((cp - 44032))
          cho_i=$((idx / 588))
          jung_i=$(( (idx % 588) / 28 ))
          jong_i=$((idx % 28))
          result="${result}${CHO[$cho_i]}${JUNG[$jung_i]}${JONG[$jong_i]}"
        else
          result="${result}-"
        fi
      else
        result="${result}-"
      fi
      i=$((i + 3))

    elif [ "$b1" -ge 192 ] && [ "$b1" -le 223 ]; then
      # 2-byte UTF-8
      result="${result}-"
      i=$((i + 2))

    elif [ "$b1" -ge 240 ]; then
      # 4-byte UTF-8 (emoji 등)
      result="${result}-"
      i=$((i + 4))

    else
      # continuation byte 또는 invalid
      i=$((i + 1))
    fi
  done

  result=$(printf '%s' "$result" | tr -s '-')
  result="${result#-}"
  result="${result%-}"
  printf '%s\n' "$result"
}

if [ $# -ge 1 ]; then
  if [ "$1" = "--help" ]; then
    usage; exit 0
  fi
  to_slug "$1"
else
  input=$(cat)
  to_slug "$input"
fi
