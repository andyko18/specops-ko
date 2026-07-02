#!/usr/bin/env bash
# v0.4a W2 — dispatch-context.md 5 컨텍스트 키 존재 검증
# Usage: validate-context.sh <context-md-path>
# Exit: 0 = 5 컨텍스트 모두 존재 + whitelist 비어있지 않음
#       1 = 누락 또는 빈 항목 발견 (stderr에 누락 항목 출력)
#       2 = 사용법 오류 또는 파일 없음
#
# 검증 항목 (5 컨텍스트):
#   1. ## 1. 담당 AC          — 최소 AC-N/AC-R-N 1건
#   2. ## 2. 관련 spec.md 섹션 — 최소 .specops/<FID>/spec.md 또는 acceptance-criteria.md 1개
#   3. ## 3. 테스트 명령       — bash 코드 블록 1개 (`bash` shebang 또는 명령 라인)
#   4. ## 4. 수정 허용 파일   — 최소 1 파일 (whitelist 비어있지 않음)
#   5. ## 5. 작업 디렉터리    — .worktrees/ 또는 절대 경로 1개
#
# 참조: templates/dispatch-context.md, 마스터 plan §6 v0.4a W2

set -u

if [ "$#" -ne 1 ]; then
  echo "usage: validate-context.sh <context-md-path>" >&2
  exit 2
fi

CTX=$1

if [ ! -f "$CTX" ]; then
  echo "error: context 파일 없음 — $CTX" >&2
  exit 2
fi

MISSING=()

# 각 섹션 헤더 + 본문에 의미 있는 데이터가 있는지 검증
# 헤더와 다음 ## 사이의 라인 추출 후 빈 라인·placeholder·코멘트만 있는지 검사

extract_section() {
  local header="$1"
  awk -v h="^## ${header}" '
    $0 ~ h { in_sec = 1; next }
    /^## / && in_sec { exit }
    in_sec { print }
  ' "$CTX"
}

# 섹션 본문에서 placeholder (<...>) 와 빈 라인·인용 라인·헤더 제외
# 의미있는 데이터 라인 1+ 있어야 PASS
has_meaningful_content() {
  local body="$1" pattern="$2"
  printf '%s' "$body" | grep -Eq "$pattern"
}

# 1. 담당 AC — 최소 "AC-N" 또는 "AC-R-N" 패턴 1건 (placeholder <Given/When/Then ...> 제외)
sec1=$(extract_section "1\\. 담당 AC")
if ! printf '%s' "$sec1" | grep -E '^- AC-(R-)?[0-9]+' | grep -vq '<' ; then
  MISSING+=("1. 담당 AC (AC-N 1건 이상 필요)")
fi

# 2. 관련 spec.md 섹션 — .specops/ 경로 1+
sec2=$(extract_section "2\\. 관련 spec.md 섹션")
if ! printf '%s' "$sec2" | grep -Eq '\.specops/[^/<]+/(spec|acceptance-criteria)\.md'; then
  MISSING+=("2. 관련 spec.md 섹션 (.specops/<FID>/spec.md 또는 acceptance-criteria.md 경로 필요)")
fi

# 3. 테스트 명령 — bash 코드 블록 안에 명령 라인 1+
sec3=$(extract_section "3\\. 테스트 명령")
# fenced code block 안 라인 추출 (bash 또는 sh fence)
# fence 상태 추적 — 닫는 ``` 가 (bash|sh)? 빈 매치로 여는 패턴에 걸려 in_b 가 안 꺼지는 결함 방지.
# 모든 ``` 줄이 fence 상태를 토글하고, bash/sh/bare 여는 fence 일 때만 내용 캡처.
test_cmd=$(printf '%s' "$sec3" | awk '
  /^```/ {
    if (in_fence) { in_fence=0; capture=0 }
    else { in_fence=1; capture = ($0 ~ /^```(bash|sh)?$/) }
    next
  }
  capture' | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#')
if [ -z "$test_cmd" ]; then
  MISSING+=("3. 테스트 명령 (bash fenced block 안에 실제 명령 라인 필요)")
fi

# 4. 수정 허용 파일 (whitelist) — 최소 1 파일 경로 (placeholder <...> 제외)
sec4=$(extract_section "4\\. 수정 허용 파일")
whitelist=$(printf '%s' "$sec4" | grep -E '^- `[^`<]+`' | grep -v '<')
if [ -z "$whitelist" ]; then
  MISSING+=("4. 수정 허용 파일 (whitelist) — 최소 1 파일 경로 필요")
fi

# 5. 작업 디렉터리 — .worktrees/ 또는 / 시작 경로
sec5=$(extract_section "5\\. 작업 디렉터리")
if ! printf '%s' "$sec5" | grep -Eq '^- `[^`<]*(\.worktrees/|/)[^`]+`'; then
  MISSING+=("5. 작업 디렉터리 (.worktrees/ 또는 절대 경로 필요)")
fi

if [ ${#MISSING[@]} -eq 0 ]; then
  exit 0
fi

echo "validate-context: 누락 항목 ${#MISSING[@]} 개:" >&2
for m in "${MISSING[@]}"; do
  echo "  - $m" >&2
done
exit 1
