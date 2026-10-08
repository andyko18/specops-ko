#!/usr/bin/env bash
# design-overview.sh — /init-project 산출 설계 문서를 읽기 전용 HTML 한 장으로 묶는다 (20261008)
# Usage: design-overview.sh [--check] [--out <path>] [<project-root>]
#   (무인자)  cwd 의 설계 문서로 .specops/design-overview.html 생성
#   --check   생성하지 않고 기존 HTML 이 원본과 같은 지문인지만 본다
#   --out     출력 경로 (기본 <root>/.specops/design-overview.html)
# Exit: 0 = 생성 / --check 시 최신 · 1 = --check 시 낡음·부재 · 2 = 설계 문서 없음·사용 오류·python3 부재
#
# 왜 필요한가: 설계 문서 14종이 루트와 .specops/memory/ 에 흩어져 있어 사람이 전체를 한 번에 훑기 어렵다.
#   승인 게이트에서 사용자가 실제로 보는 건 요약뿐이다 — 구성도·프로세스 흐름·추적표·미확정 목록을 한 화면에 모은다.
# 원본은 계속 마크다운이다: 이 HTML 은 생성물이고 lifecycle 은 읽지 않는다. 고칠 때는 .md 를 고치고 다시 생성한다.
# 외부 리소스(CDN 스크립트·폰트)를 참조하지 않는다 — 폐쇄망에서 파일만 열어도 보인다. 의존은 python3 표준 라이브러리뿐.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECK=""; OUT=""; ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK="--check"; shift ;;
    --out) OUT="${2:-}"; [ -n "$OUT" ] || { echo "design-overview: --out 에 경로가 필요하다" >&2; exit 2; }; shift 2 ;;
    -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "design-overview: 알 수 없는 옵션 $1" >&2; exit 2 ;;
    *) [ -z "$ROOT" ] || { echo "design-overview: 프로젝트 경로는 하나만" >&2; exit 2; }; ROOT="$1"; shift ;;
  esac
done
ROOT="${ROOT:-.}"
[ -d "$ROOT" ] || { echo "design-overview: 디렉터리 아님 — $ROOT" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "design-overview: python3 가 필요하다" >&2; exit 2; }
OUT="${OUT:-$ROOT/.specops/design-overview.html}"
# -E: PYTHON* 환경변수 무시 · -B: __pycache__ 를 플러그인 디렉터리에 남기지 않는다. 모듈은 스크립트 디렉터리에서만 찾는다(cwd 의 동명 파일이 끼어들지 않게 build.py 가 경로를 고정).
if [ -n "$CHECK" ]; then
  exec python3 -E -B "$HERE/_internal/design-overview/build.py" "$ROOT" "$OUT" --check
fi
exec python3 -E -B "$HERE/_internal/design-overview/build.py" "$ROOT" "$OUT"
