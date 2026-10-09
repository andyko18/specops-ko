#!/usr/bin/env bash
# check-stack-decided.sh — foundation 기술스택 확정 증거 게이트 (20260806, clarify 층 봉합)
# Usage: check-stack-decided.sh <FID>
# Exit: 0 = PASS 또는 해당 없음(skip) · 1 = FAIL(스택 결정 증거 전무)
#
# 배경: clarifying-ko 는 "§유형=foundation 이고 architecture 문서에 placeholder 가 있으면
#   기술 프레임워크 확정을 BLOCKING 으로 강제, RESOLVED 전 planning 진입 차단" 을 선언한다.
#   판정기(check-decisions-ledger.sh)를 만들어 눈대중은 없앴지만 **호출은 산문 의무**로 남았다 —
#   clarify 단계엔 스크립트가 반드시 지나는 관문이 없기 때문(specify→clarify→plan 모두 대화).
#   그래서 결정의 **증거**를 다음 하드 관문(emit-context = 구현 직전)에서 검사한다.
#
# 증거로 인정하는 것 (둘 중 하나):
#   ① `.specops/memory/decisions.md` 에 스택 확정 행 — clarifying HARD 규약이
#      "RESOLVED 된 아키텍처·스택 결정은 decisions.md 에 행 upsert" 를 요구하므로 이게 정규 경로.
#   ② `.specops/<FID>/clarifications.md` 에 스택 관련 **RESOLVED** 기록 —
#      원장 upsert 를 빠뜨린 경우의 구제(경고 출력). `status: ASSUMED` 는 불인정(가정은 결정이 아님).
#
# 발동 조건(전부 충족): §유형=foundation · architecture 문서 존재 · 그 문서의 **스택을 적는 줄**에 미확정 잔존.
#   미확정이 없으면 스택은 이미 문서로 확정된 것이므로 물을 게 없다.
#   architecture 문서가 없으면 막지 않고, 스택 근거가 어디에도 없을 때만 알린다(`STACK-DECIDED: NOTE`).
# fail-open: spec.md 부재 등 판정 불가.
set -u

FID="${1:?usage: $0 <FID>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
SPEC="$SPECOPS/$FID/spec.md"
CLARIF="$SPECOPS/$FID/clarifications.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCAN="$PLUGIN/scripts/_internal/scan-enrich-placeholders.sh"
LEDGER_SH="$PLUGIN/scripts/_internal/check-decisions-ledger.sh"

[ -f "$SPEC" ] || { echo "STACK-DECIDED: SKIP (spec.md 부재)"; exit 0; }

grep -qE '^\*\*§유형\*\*:[[:space:]]*foundation' "$SPEC" 2>/dev/null || {
  echo "STACK-DECIDED: SKIP (§유형≠foundation)"; exit 0
}

# 증거 판정 — ① 결정 원장의 확정 행(정규 경로) ② clarifications.md 의 스택 RESOLVED(원장 upsert 누락 구제)
#   $1 = 원장 주제 정규식. 반환 0 = 증거 있음(EVID 에 출처) · 1 = 없음.
#   ② 의 형식은 clarifying-ko `## clarifications.md 포맷` 을 따른다(20261009 — 종전엔 테스트 픽스처에만 있는 형식을 읽어
#   실파일과 구조적으로 만나지 못했다):
#     파일 머리 `**status**: RESOLVED`(전체 상태) + `## Q1 · <주제> · BLOCKING` 블록 + `**답변**: …`
#   블록 안에 자체 `status:` 가 있으면 그것이 우선한다(구 형식 · §auto 의 Q 블록 `status: ASSUMED`).
#   인정 조건(스택을 다룬 Q 블록 하나 이상): 답이 적혀 있고 · 가정(ASSUMED — 제목 표기 또는 블록 status)이 아니며 ·
#     유효 상태가 정확히 RESOLVED. 채우지 않은 머리줄(`RESOLVED | BLOCKED | ASSUMED`)은 확정이 아니다.
EVID=""
_has_evidence() {
  if [ -f "$LEDGER_SH" ] && SPECOPS_ROOT="$SPECOPS" bash "$LEDGER_SH" "$1" >/dev/null 2>&1; then
    EVID=ledger; return 0
  fi
  if [ -f "$CLARIF" ] && awk '
    function val(s) { gsub(/\*/, "", s); sub(/^[ \t]*status[ \t]*:[ \t]*/, "", s); gsub(/[ \t\r]+$/, "", s); return s }
    function flush() {
      if (inblk && kw && ans && !assumed && (bst == "RESOLVED" || (bst == "" && fst == "RESOLVED"))) found = 1
    }
    # 무정보 답(미정·TBD 등 — 결정 원장 판정기와 같은 목록)은 답이 아니다
    function real(a) {
      gsub(/^[ \t]+|[ \t]+$/, "", a)
      if (a == "" || a ~ /^</) return 0
      if (a ~ /^(TBD|tbd|N\/A|n\/a|-|—|\(미정\)|미정|미확정|해당없음|해당 없음|\?\?\?)$/) return 0
      return 1
    }
    { sub(/\r$/, "") }
    # Q 블록 경계는 **2단 제목만** — 블록 안의 3단 소제목(### 옵션 …)이 블록을 끊지 않는다
    /^##[ \t]/ {
      flush()
      inblk = 1; bst = ""; ans = 0; pend = 0
      kw = ($0 ~ /스택|프레임워크|[Ff]ramework|아키텍처|런타임|[Rr]untime/)
      assumed = ($0 ~ /ASSUMED/)
      next
    }
    {
      t = $0; gsub(/\*/, "", t)
      if (t ~ /^[ \t]*status[ \t]*:/) {
        v = val($0)
        if (inblk) { bst = v; if (v ~ /ASSUMED/) assumed = 1 }
        else if (fst == "") fst = v
      }
      if (inblk && t ~ /^[ \t]*답변[^:]*:/) {
        a = t; sub(/^[ \t]*답변[^:]*:/, "", a)
        if (a ~ /^[ \t]*$/) pend = 1      # 답을 다음 줄에 적은 형태
        else { pend = 0; if (real(a)) ans = 1 }
      } else if (inblk && pend && t !~ /^[ \t]*$/) {
        pend = 0
        # 다음 필드(**영향**: …)·제목이 바로 오면 답이 비어 있는 것이다
        if ($0 !~ /^[ \t]*\*\*[^*]+\*\*[ \t]*:/ && $0 !~ /^#/ && real(t)) ans = 1
      }
    }
    END { flush(); exit(found ? 0 : 1) }
  ' "$CLARIF"; then
    EVID=clarif; return 0
  fi
  return 1
}

# 아키텍처 문서가 없는 프로젝트(CLI·라이브러리 · init 을 거치지 않은 저장소) — 막지 않는다(문서를 강제하지 않는다).
#   다만 스택 근거가 어디에도 없으면 알린다 — 종전엔 통째로 SKIP 이라 근거 0 으로 조용히 구현에 들어갔다(20261009).
arch_docs=""
for d in "$SPECOPS/memory/frontend-architecture.md" "$SPECOPS/memory/backend-architecture.md"; do
  [ -f "$d" ] && arch_docs="${arch_docs} $d"
done
if [ -z "$arch_docs" ]; then
  if _has_evidence '스택|프레임워크|프론트|백엔드|언어|런타임'; then
    echo "STACK-DECIDED: SKIP (architecture 문서 부재 — 스택 결정은 ${EVID} 에 있음)"
  else
    echo "STACK-DECIDED: NOTE — architecture 문서가 없어 스택 확정을 검사하지 않았다 (차단 아님)"
    echo "  결정 원장(decisions.md)·clarifications.md 에도 스택·언어·런타임 결정이 없다."
    echo "  정했다면 원장에 행으로 남기세요 — 후속 FR 이 같은 질문을 반복하지 않는다."
  fi
  exit 0
fi

# 아키텍처 문서의 **스택을 적는 줄**에 미확정이 남았는가 (20261009)
#   종전엔 범용 미채움 스캐너로 문서 전체를 봤다. 두 방향으로 틀렸다:
#     - 다 채운 문서의 코드 표기(`useState<string>`·`<cmd>`)를 미확정으로 읽어 원장 행이 없으면 막았다(거짓 차단).
#     - 템플릿의 긴 선택지 토큰(`<React 18 / Vue 3 / …>` — 40자 초과)과 `<미확정 — 근거 필요>` 줄은 스캐너가 세지 않아
#       프레임워크가 비어 있어도 "이미 확정" 으로 건너뛰었다(조용한 통과).
#   이제 **스택을 적는 줄**(프레임워크·언어·런타임)만 본다 — 호스팅·한도 같은 다른 항목의 미확정은 이 게이트의 일이 아니다.
#   그 줄이 미확정인 경우:
#     ⓐ 템플릿의 자리표시자가 남았다(`fmc_template_leftovers` — 경로 규약 표기 `<feature>`·`<name>` 은 채울 자리가 아니다)
#     ⓑ 값이 꺾쇠 표기로 **시작한다**(`- **주 프레임워크**: <Express / Fastify>` · `| 언어 | <확정 필요> |`) —
#        템플릿과 글자가 다른 자리표시자(고쳐 쓴 선택지·옛 템플릿)도 잡는다. 값 중간의 코드 표기
#        (`Node 22 (\`node --import <loader>\`)` · `useState<string>` · `app/<페이지명>/page.tsx`)는 미확정이 아니다.
CONTENT="$PLUGIN/scripts/_internal/foundation-manifest-content.sh"
stack_ph=""
for d in $arch_docs; do
  rc_l=2; out_l=""
  if [ -f "$CONTENT" ]; then
    # shellcheck source=/dev/null
    . "$CONTENT"
    out_l=$(fmc_template_leftovers "$d" "$PLUGIN/templates/$(basename "$d")" "<feature>
<name>"); rc_l=$?
  fi
  if [ "$rc_l" -eq 2 ] && [ -f "$SCAN" ]; then out_l=$(bash "$SCAN" "$d" 2>/dev/null) || true; fi
  # ⓑ 값이 꺾쇠 표기로 시작하는 줄 — 구분자(`:`·`|`) 바로 뒤(공백·`*`·백틱만 사이에 두고)에 `<…>` 가 오고
  #   그 안이 공백·`-`·`!`·`/` 로 시작하지 않는다(비교식·mermaid 화살표·주석·닫는 태그가 아니다). 코드펜스 안은 보지 않는다.
  val_l=$(LC_ALL=C awk '
    { sub(/\r$/, "") }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /(:|\|)[ \t*`]*<[^<> \t\/!-][^<>]*>/ { print NR ":" $0 }' "$d" 2>/dev/null)
  # 키워드는 **줄 내용**에서만 찾는다 — `파일:행:` 접두까지 보면 경로에 framework·runtime 이 든 프로젝트에서
  #   모든 줄이 스택 줄이 된다. ⓐ 의 접두(`<문서 경로>:`)를 떼어 `행:내용` 으로 맞춘 뒤 고른다.
  doc_ph=$(printf '%s\n%s\n' "$out_l" "$val_l" \
    | LC_ALL=C awk -v p="$d:" '$0 == "" { next } index($0, p) == 1 { print substr($0, length(p) + 1); next } { print }' \
    | LC_ALL=C sort -u | LC_ALL=C sort -t: -k1,1n \
    | grep -E '^[0-9]+:.*(프레임워크|[Ff]ramework|언어|런타임|[Rr]untime|스택)' || true)
  [ -n "$doc_ph" ] && stack_ph="${stack_ph}${stack_ph:+
}$(printf '%s\n' "$doc_ph" | sed "s|^|$(basename "$d"):|")"
done
[ -n "$stack_ph" ] || { echo "STACK-DECIDED: SKIP (architecture 문서의 스택 줄에 미확정 없음 — 이미 확정)"; exit 0; }

if _has_evidence '스택|프레임워크|프론트|백엔드'; then
  if [ "$EVID" = ledger ]; then
    echo "STACK-DECIDED: PASS (decisions.md 확정 행)"
  else
    echo "STACK-DECIDED: PASS (clarifications.md RESOLVED)"
    echo "  WARN: decisions.md 원장 upsert 누락 — clarifying-ko HARD 규약상 RESOLVED 결정은" >&2
    echo "        .specops/memory/decisions.md 에 행 upsert 해야 후속 FR 이 재질문하지 않는다." >&2
  fi
  exit 0
fi

cat <<EOF
STACK-DECIDED: FAIL — foundation 인데 기술스택 확정 증거가 없습니다.
  architecture 문서의 스택 줄에 미확정이 남아 있고(아래),
  decisions.md 에도 clarifications.md 에도 RESOLVED 스택 결정이 없습니다.
  (status: ASSUMED 는 결정이 아니므로 인정되지 않습니다.)

  해법: clarifying-ko BLOCKING 으로 기술 프레임워크를 확정하고
        .specops/memory/decisions.md 에 행을 upsert 하세요.
        확인: bash scripts/_internal/check-decisions-ledger.sh --list

  미확정이 남은 줄:
EOF
printf '%s\n' "$stack_ph" | head -8 | cut -c1-200 | sed 's/^/    /'
exit 1
