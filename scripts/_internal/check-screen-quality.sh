#!/usr/bin/env bash
# check-screen-quality.sh — 화면 쌍(.md + .html) 정적 품질 계측
#
# 계기: design-reviewer-ko 의 8관점이 전부 구조·정합이라 "구조는 맞물리는데 쓸 수 없는 화면"이
#       게이트를 그대로 지나갔다. 껍데기 판정도 마커 grep + 섹션 '제목' 존재만 본다.
#
# ★ 계측 전용 — 항상 exit 0. 판정은 design-reviewer-ko 가 한다.
#   휴리스틱이라 오탐이 불가피한데, exit code 로 차단하면 오탐 1건이 배치를 세운다
#   (check-ci-status.sh 와 동형 계약).
#
# 계약: read-only · stdout=리포트 · exit 항상 0 · jq 불요(grep/awk/sed)
# usage: check-screen-quality.sh <screen.md> <screen.html>
#        check-screen-quality.sh --all            # screens/ 전체
set -uo pipefail

_count() { printf '%s' "${1:-0}" | tr -d ' \n'; }

# 판정 불가를 '위반 0' 으로 보고하지 않는다 — 무음 낙관 금지 (doctor.sh v1.78.0 교훈)
_readable() { [ -f "$1" ] && [ -r "$1" ]; }

_NL='
'
_TAB=$(printf '\t')

# ── genre: 화면 원형별 장르 규칙 (DESIGN.md §6.1 — FID 20260929-enterprise-genre-rules) ──
# 계측 규칙 ID 단일 선언 — test-design-contract 가 이 줄만 읽어 §6.1 표와 대조한다.
_GENRE_IDS='G-LIST-PAGING G-LIST-SORT G-LIST-EMPTY-KIND G-FORM-SUBMIT G-FORM-CANCEL G-WIZARD-STEP G-DASH-PERIOD'

_genre_rules() {  # $1=원형 → 계측 규칙 ID(공백 구분). rc 1 = 허용 목록 밖
  case "$1" in
    목록)      echo 'G-LIST-PAGING G-LIST-SORT G-LIST-EMPTY-KIND' ;;
    폼)        echo 'G-FORM-SUBMIT G-FORM-CANCEL' ;;
    '다단 폼') echo 'G-FORM-SUBMIT G-FORM-CANCEL G-WIZARD-STEP' ;;
    대시보드)  echo 'G-DASH-PERIOD' ;;
    상세|기타) echo '' ;;
    *) return 1 ;;
  esac
}

# here-string — `set -o pipefail` 아래 `printf | grep -q` 는 grep 조기 종료로 printf 가 SIGPIPE 를 받으면
#   큰 본문에서 충족을 미충족으로 오판한다(외부 critic 지적).
_has() { grep -qiE "$2" <<<"$1"; }

# 규칙 판정 — rc 0 = 충족. 언급 여부 근사(부정문도 충족 — clarify Q2). 규칙마다 한 줄:
#   되돌려-관찰 변이가 sed 한 줄로 가능해야 한다.
_genre_check() {  # $1=ID $2=본문(override 주석 제거) $3=States 섹션
  case "$1" in
    G-LIST-PAGING)     _has "$2" '페이지네이션|페이징|무한 스크롤|pagination' && _has "$2" '총 건수|전체 건수|total' ;;
    G-LIST-SORT)       _has "$2" '정렬 기준|기본 정렬|sort by|default sort' ;;
    G-LIST-EMPTY-KIND) _has "$3" '데이터 없음|no data' && _has "$3" '결과 없음|no results' ;;
    G-FORM-SUBMIT)     _has "$2" '제출 중|저장 중|submitting' && _has "$2" '비활성|disabled|중복 제출' ;;
    G-FORM-CANCEL)     _has "$2" '취소|cancel' ;;
    G-WIZARD-STEP)     _has "$2" '단계 표시|진행 단계|step indicator' && _has "$2" '이전|previous' && _has "$2" '임시 저장|중간 저장|이탈 시 보존|draft' ;;
    G-DASH-PERIOD)     _has "$2" '기간 선택|기간 필터|date range' ;;
    *) return 1 ;;
  esac
}

_genre_miss() {  # $1=ID → 빠진 요소(상세줄 문구)
  case "$1" in
    G-LIST-PAGING)     echo '페이징(또는 무한 스크롤)과 총 건수 표시' ;;
    G-LIST-SORT)       echo '기본 정렬 기준' ;;
    G-LIST-EMPTY-KIND) echo "States 에서 '데이터 없음'과 '검색·필터 결과 없음' 구분" ;;
    G-FORM-SUBMIT)     echo '제출 중 비활성(중복 제출 방지)' ;;
    G-FORM-CANCEL)     echo '취소 경로' ;;
    G-WIZARD-STEP)     echo '단계 표시 · 이전 단계 · 중간 저장(또는 이탈 시 보존)' ;;
    G-DASH-PERIOD)     echo '기간 선택' ;;
  esac
}

_gadd() { genre_det="${genre_det:+$genre_det$_NL}$1"; }

# 결과: genre · genre_det (호출자 _analyze 의 local — bash 동적 스코프)
_genre() {  # $1=md
  genre="unknown"; genre_det=""
  local why='장르 규칙을 계측하지 않았다(위반 없음이 아니다)'
  if ! _readable "$1"; then _gadd "  [genre] 화면 스펙 판독 불가 — $why"; return 0; fi
  local line val a rs r rules="" nv=0
  line=$(awk '/^## /{exit} /^\*\*원형\*\*:/{print; exit}' "$1")
  if [ -z "$line" ]; then _gadd "  [genre] 원형 미선언 — $why"; return 0; fi
  val=$(printf '%s' "${line#*:}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$val" in ''|\[*) _gadd "  [genre] 원형 자리표시자 그대로 — $why"; return 0 ;; esac
  # 복합 원형(쉼표) — 하나라도 목록 밖이면 전체 unknown (부분 계측으로 위장 금지)
  while IFS= read -r a; do
    a=$(printf '%s' "$a" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$a" ] || continue
    if ! rs=$(_genre_rules "$a"); then _gadd "  [genre] 원형 값 판독 불가: $a — $why"; return 0; fi
    nv=$((nv+1))
    for r in $rs; do case " $rules " in *" $r "*) ;; *) rules="$rules $r" ;; esac; done
  done <<EOF
$(printf '%s\n' "$val" | tr ',' '\n')
EOF
  [ "$nv" -gt 0 ] || { _gadd "  [genre] 원형 자리표시자 그대로 — $why"; return 0; }
  rules="${rules# }"
  [ -n "$rules" ] || { genre="n/a"; return 0; }

  # override — 주석 구간만 본문에서 지운다(같은 줄 다른 내용 보존 · 사유가 키워드로 새지 않게)
  local body st o id reason ovmap="" ok=0 n=0
  body=$(sed -E 's/<!--[[:space:]]*genre-override:[^>]*-->//g' "$1")
  st=$(printf '%s\n' "$body" | awk '/^## States/{f=1;next} f&&/^## /{exit} f')
  while IFS= read -r o; do
    [ -n "$o" ] || continue
    o=$(printf '%s' "$o" | sed -E 's/^<!--[[:space:]]*genre-override:[[:space:]]*//; s/[[:space:]]*-->$//')
    id=${o%%[[:space:]]*}; reason=""
    [ "$id" = "$o" ] || reason=$(printf '%s' "${o#"$id"}" | sed 's/^[[:space:]]*//')
    case " $rules " in
      *" $id "*)
        if [ -n "$reason" ]; then ovmap="${ovmap}${id}${_TAB}${reason}${_NL}"
        else _gadd "  [genre] $id override 사유 없음 — 억제하지 않음"; fi ;;
      *) _gadd "  [genre] $id override 대상 아님 — 이 화면 원형의 계측 규칙이 아니다" ;;
    esac
  done <<EOF
$(grep -oE '<!--[[:space:]]*genre-override:[^>]*-->' "$1" 2>/dev/null)
EOF
  for id in $rules; do
    n=$((n+1))
    reason=$(printf '%s' "$ovmap" | awk -F"$_TAB" -v k="$id" '$1==k{print $2; exit}')
    if [ -n "$reason" ]; then ok=$((ok+1)); _gadd "  [genre] $id override — $reason"
    elif _genre_check "$id" "$body" "$st"; then ok=$((ok+1))
    else _gadd "  [genre] $id 미충족 — $(_genre_miss "$id")"; fi
  done
  genre="$ok/$n"
}

_analyze() {  # $1=md $2=html
  local md="$1" html="$2" name
  name=$(basename "$md" .md)

  # ── states: empty·loading·error 3종. 영문+한글 둘 다 인정 ──
  # 영문만 보면 한국어 문서에서 항상 0/3 이 나와 검사가 무의미해진다.
  local st=0 sec miss="" states a11y semantic token microcopy genre genre_det
  if _readable "$md"; then
    # 종료 앵커를 `^## ` 로 두고 시작줄만 제외한다 — `/^## [^S]/` 는 후속 헤딩이 S 로
    # 시작하면(## Summary 등) 범위가 새어 다음 섹션까지 먹는다(외부 critic 지적).
    sec=$(awk '/^## States/{f=1;next} f&&/^## /{exit} f' "$md")
    # ★ 누락 '항목명' 을 남긴다 — 리뷰어 표는 심각도를 종류로 가른다
    #   (empty·error 미정의=Important / loading 만 누락=Minor). 비율만 내면 그 판정을
    #   계측 결과에서 도출할 수 없어 리뷰어가 md 를 재독하게 되고, 그건 추측 판정 금지 계약과 어긋난다.
    if printf '%s' "$sec" | grep -qiE 'empty|빈 상태|빈상태'; then st=$((st+1)); else miss="$miss,empty"; fi
    if printf '%s' "$sec" | grep -qiE 'loading|로딩'; then st=$((st+1)); else miss="$miss,loading"; fi
    if printf '%s' "$sec" | grep -qiE 'error|오류|에러'; then st=$((st+1)); else miss="$miss,error"; fi
    miss="${miss#,}"
    states="$st/3"
  else
    states="unknown"
  fi

  # ── microcopy: 에러 메시지 섹션의 무정보 문구 단독 행 ──
  if _readable "$md"; then
    # States 와 동일한 종료 앵커를 쓴다 — `/^## 에러 메시지/,0` 은 EOF 까지 열려 있어
    # 뒤따르는 섹션의 `- 오류` 같은 행까지 먹는다(States 에서 막은 것과 같은 범위 누수).
    sec=$(awk '/^## 에러 메시지/{f=1;next} f&&/^## /{exit} f' "$md")
    microcopy=$(_count "$(printf '%s' "$sec" | grep -cE '^-[[:space:]]*(오류|실패|에러)[[:space:]]*$' || true)")
  else
    microcopy="unknown"
  fi

  if _readable "$html"; then
    # ── a11y-label: label 수 / 입력 요소 수 ──
    local inp lab
    # hidden input(csrf 등)은 label 대상이 아니다 — 세면 오탐이 된다(외부 리뷰 M-1)
    local hid
    inp=$(_count "$(grep -oE '<(input|select|textarea)\b' "$html" | wc -l)")
    hid=$(_count "$(grep -oE '<input[^>]*type=["'"'"']?hidden' "$html" | wc -l)")
    inp=$((inp - hid)); [ "$inp" -lt 0 ] && inp=0
    lab=$(_count "$(grep -oE '<label\b' "$html" | wc -l)")
    a11y="$lab/$inp"
    # ── semantic: 랜드마크 요소 수 ──
    semantic=$(_count "$(grep -oE '<(main|nav|header|section|aside|footer)\b' "$html" | wc -l)")
    # ── token: 색 리터럴 중 `--이름:` 정의부를 뺀 하드코딩 ──
    # ★ 정의부(`--color-primary: #7C3AED;`)는 정상이다 — 실측(screens/login.html 전수):
    #   hex 12건 중 정의부 10건, 하드코딩 2건(:70 #6B7280 · :89 #6D28D9). 정의부를 빼지
    #   않으면 정상 코드 10건이 전부 위반으로 잡힌다. rgba() 등가색은 세지 않는다 — 정당한 투명도(그림자 등)까지
    #   물들이면 노이즈가 급증해 리뷰어가 검사를 무시하게 된다.
    #   ★ var 명 문자셋은 `[A-Za-z0-9-]` — `[a-z-]` 로 좁히면 `--gray-100`·`--Color-Primary`
    #     같은 scale/대문자 명명을 정의부로 못 잡아 **정상 코드가 전부 하드코딩으로 오탐**된다
    #     (실측: 정의부 3건 fixture 가 def=0 → token=4). 리뷰어 기준이 "3건 이상=Important" 라
    #     그 오탐이 곧바로 오판정이 된다.
    local all def
    all=$(_count "$(grep -oE '#[0-9A-Fa-f]{6}' "$html" | wc -l)")
    def=$(_count "$(grep -oE '\-\-[A-Za-z0-9-]+:[[:space:]]*#[0-9A-Fa-f]{6}' "$html" | wc -l)")
    token=$((all - def))
    [ "$token" -lt 0 ] && token=0
  else
    a11y="unknown"; semantic="unknown"; token="unknown"
  fi

  _genre "$md"

  printf 'SCREEN-QUALITY: %s  states=%s  a11y-label=%s  semantic=%s  token=%s  microcopy=%s  genre=%s\n' \
    "$name" "$states" "$a11y" "$semantic" "$token" "$microcopy" "$genre"

  # 상세 — 위반이 있을 때만
  case "$states" in
    0/3|1/3|2/3) printf '  [states] 미정의: %s (%s)\n' "${miss:-?}" "$states" ;;
  esac
  if [ "$a11y" != "unknown" ]; then
    local l="${a11y%%/*}" i="${a11y##*/}"
    [ "$i" -gt "$l" ] && printf '  [a11y-label] 입력 %s개 중 label %s개 — %s개 누락\n' "$i" "$l" "$((i-l))"
  fi
  [ "$semantic" = "0" ] && printf '  [semantic] 랜드마크 요소 0개 — div 수프 의심\n'
  case "$token" in unknown|0) ;; *) printf '  [token] 색 리터럴 하드코딩 %s건 — var(--…) 사용 권고\n' "$token" ;; esac
  case "$microcopy" in unknown|0) ;; *) printf '  [microcopy] 무정보 에러 문구 %s건 — 사용자가 무엇을 해야 하는지 쓰기\n' "$microcopy" ;; esac
  [ -n "$genre_det" ] && printf '%s\n' "$genre_det"
  return 0
}

# ★ 무출력 exit 0 금지 — 리뷰어가 "위반 없음" 으로 읽는다(T1.h 가 막으려던 무음 낙관과 같은 클래스).
#   대상이 없거나 인자가 틀려도 반드시 unknown 1줄을 낸다.
_unknown_line() {  # $1=name $2=사유
  printf 'SCREEN-QUALITY: %s  states=unknown  a11y-label=unknown  semantic=unknown  token=unknown  microcopy=unknown  genre=unknown\n' "$1"
  printf '  [scope] %s — 계측하지 못했다(위반 없음이 아니다)\n' "$2"
}

if [ "${1:-}" = "--all" ]; then
  # cwd 상대 경로다. repo 루트 밖에서 부르면 대상 0개가 된다 — 그때도 침묵하지 않는다.
  n=0
  for f in screens/*.md; do
    [ -f "$f" ] || continue
    _analyze "$f" "${f%.md}.html"
    n=$((n+1))
  done
  [ "$n" -eq 0 ] && _unknown_line '(none)' 'screens/*.md 대상 0개 — cwd 가 repo 루트인지 확인'
  exit 0
fi

if [ $# -lt 2 ]; then
  echo "usage: check-screen-quality.sh <screen.md> <screen.html> | --all" >&2
  _unknown_line '(none)' '인자 부족'
  exit 0
fi
_analyze "$1" "$2"
exit 0
