#!/usr/bin/env bash
# foundation 재사용 게이트 (소비측) 기계화 — 20260806 /start-foundation 정밀분석
#
# 생산측(manifest 산출)은 check-foundation-manifest.sh 로 닫혔다. 소비측 —
# "§유형≠foundation 이고 manifest 가 있으면 각 task 에 `**재사용 foundation**` 또는
#  `**미재사용 근거**` 를 반드시 기재, 누락 시 implementing-ko 호출 금지" — 는
# decomposing-ko 산문뿐이었다(검사 스크립트 0곳). 모델이 안 쓰면 그대로 통과.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-foundation-reuse.sh"

_mk() {  # $1=dir $2=fid $3=§유형 $4=manifest여부(y/n)
  mkdir -p "$1/.specops/$2" "$1/.specops/memory"
  printf '**§유형**: %s\n' "$3" > "$1/.specops/$2/spec.md"
  [ "$4" = "y" ] && printf '| 라우팅 | `src/router.ts` | 라우트 | `import` |\n' \
    > "$1/.specops/memory/foundation-manifest.md"
  return 0
}
_tasks() {  # $1=경로 $2=T1선언 $3=T2선언 (빈 문자열=선언 없음)
  { printf '# 태스크 목록\n\n## 태스크 1: 로그인 폼\n\n**파일**: src/login.ts\n'
    [ -n "$2" ] && printf '%s\n' "$2"
    printf '\n## 태스크 2: 세션 저장\n\n**파일**: src/session.ts\n'
    [ -n "$3" ] && printf '%s\n' "$3"
    printf '\n## 의존 그래프\n'
  } > "$1"
}

# T1: 전 task 선언 있음 → PASS
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '**재사용 foundation**: 라우팅' '**미재사용 근거**: 순수 유틸이라 공통부 범위 밖'
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T1 전 task 선언 → PASS" || nope "T1" "rc=$rc"
rm -rf "$TD"

# T2: ★ 한 task 누락 → FAIL (핵심 — 산문일 때 통과하던 케이스)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '**재사용 foundation**: 라우팅' ''
out=$(cd "$TD" && bash "$CHK" 20260806-f 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '태스크 2' \
  && ok "T2 1건 누락 → FAIL + 해당 태스크 지목" || nope "T2" "rc=$rc out=$out"
rm -rf "$TD"

# T3: 전 task 누락 → FAIL
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '' ''
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T3 전 task 누락 → FAIL" || nope "T3" "rc=$rc"
rm -rf "$TD"

# T4: manifest 부재 → 게이트 비발동 (foundation 미사용 프로젝트에 월권 금지)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 n
_tasks "$TD/.specops/20260806-f/tasks.md" '' ''
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T4 manifest 부재 → skip" || nope "T4" "rc=$rc"
rm -rf "$TD"

# T5: §유형=foundation 자신 → skip (자기 자신에게 재사용 요구 금지)
TD=$(mktemp -d); _mk "$TD" 20260806-f foundation y
_tasks "$TD/.specops/20260806-f/tasks.md" '' ''
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T5 §유형=foundation → skip" || nope "T5" "rc=$rc"
rm -rf "$TD"

# T6: 선언은 있으나 값이 placeholder → FAIL (형식만 갖춘 통과 차단)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '**재사용 foundation**: <모듈명>' '**미재사용 근거**: 범위 밖'
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T6 placeholder 값 → FAIL" || nope "T6" "rc=$rc"
rm -rf "$TD"

# T7: 선언은 있으나 값이 비어 있음 → FAIL
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '**미재사용 근거**:' '**미재사용 근거**: 범위 밖'
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T7 빈 값 → FAIL" || nope "T7" "rc=$rc"
rm -rf "$TD"

# T8: tasks.md·spec.md 부재 → fail-open
TD=$(mktemp -d); mkdir -p "$TD/.specops/20260806-f"
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T8 산출물 부재 → fail-open" || nope "T8" "rc=$rc"
rm -rf "$TD"

# ── T11: 태스크 원천 불일치 (20260806 /start-all-auto 분석) ──────────────────
# 결함: 본 게이트는 `## 태스크 N:` **마크다운 절**만 순회하는데, `emit-context` 가
#   실제로 dispatch 하는 태스크 원천은 **YAML DAG** 다. 두 원천이 어긋나면
#   (YAML 3개 · 마크다운 절 1개) 나머지 태스크는 **검사 자체를 안 받고 통과**한다.
#   무인(`/start-all-auto`)에서는 사람이 눈으로 못 잡으므로 그대로 구현에 들어간다.
# T11.a: YAML 2 태스크 · 마크다운 절 1개(선언 보유) → 미선언 태스크 적발
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
cat > "$TD/.specops/20260806-f/tasks.md" <<'EOF'
# 태스크

## 태스크 1: 첫 작업
**재사용 foundation**: 라우팅

## 의존 그래프

```yaml
tasks:
  - id: T1
    test_command: "bash t.sh"
    outputs: [a]
  - id: T2
    test_command: "bash t2.sh"
    outputs: [b]
```
EOF
out=$(cd "$TD" && bash "$CHK" 20260806-f 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'T2' \
  && ok "T11.a YAML 태스크 수 > 절 수 → 미선언 태스크 적발" || nope "T11.a" "rc=$rc out=$out"
rm -rf "$TD"

# T11.b: YAML·절 개수 일치 + 전부 선언 → PASS (정상 흐름 무손상)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
cat > "$TD/.specops/20260806-f/tasks.md" <<'EOF'
# 태스크

## 태스크 1: 첫 작업
**재사용 foundation**: 라우팅

## 태스크 2: 둘째 작업
**미재사용 근거**: 공통부 범위 밖 순수 유틸

## 의존 그래프

```yaml
tasks:
  - id: T1
    test_command: "bash t.sh"
    outputs: [a]
  - id: T2
    test_command: "bash t2.sh"
    outputs: [b]
```
EOF
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T11.b 개수 일치 + 전부 선언 → PASS" || nope "T11.b" "rc=$rc"
rm -rf "$TD"

# T9: emit-context 배선 — 구현 **전** 차단 지점에 연결됐는가
grep -q 'check-foundation-reuse.sh' "$PLUGIN/scripts/dag/emit-context.sh" \
  && ok "T9 emit-context 배선 (구현 전 fail-fast)" || nope "T9" "미배선 — 산문 잔존"

# T10: decomposing-ko 가 스크립트를 SoT 로 지목
grep -q 'check-foundation-reuse.sh' "$PLUGIN/skills/decomposing-ko/SKILL.md" \
  && ok "T10 decomposing-ko 스크립트 지목" || nope "T10" "스킬 본문 미갱신"

# ── T12: 태스크 제목 표기 (20261009 /start-foundation 점검) ────────────────────
# 결함: 게이트가 `## 태스크 N:` 만 절로 셌다. 그런데 플러그인이 가르치는 형식은 셋이다 —
#   templates/tasks.md `## 태스크 N:` · decomposing-ko·planning-ko 예시 `### Task N:` ·
#   plan-to-tasks.sh 출력 `## Task N:`. 선언을 다 적어도 "선언 누락"으로 막혔다
#   (실기록: 3개 프로젝트에서 실제 발화한 FAIL 7건이 전부 이 경우 · 진짜 누락 적발 0건).
#   판정 규칙은 골격 생성기(plan-to-tasks.sh)와 같아야 한다: 2~3단 제목 · Task|태스크 · 번호 · 코드펜스 밖.
_yaml2() { printf '\n## 의존 그래프\n\n```yaml\ntasks:\n  - id: T1\n    test_command: "bash t.sh"\n    outputs: [a]\n  - id: T2\n    test_command: "bash t2.sh"\n    outputs: [b]\n```\n'; }
_hdr_case() {  # $1=id $2=설명 $3=제목 printf 형식(%s=번호) $4=T2 선언 $5=기대 rc
  local td out rc
  td=$(mktemp -d); _mk "$td" 20260806-f 신규 y
  {
    printf '# 태스크\n\n'
    # shellcheck disable=SC2059
    printf "$3\n\n**재사용 foundation**: 라우팅\n\n" 1
    # shellcheck disable=SC2059
    printf "$3\n\n" 2
    [ -n "$4" ] && printf '%s\n' "$4"
    _yaml2
  } > "$td/.specops/20260806-f/tasks.md"
  out=$(cd "$td" && bash "$CHK" 20260806-f 2>&1); rc=$?
  [ "$rc" -eq "$5" ] && ok "$1 $2" || nope "$1" "rc=$rc(기대 $5) out=$out"
  LAST_OUT="$out"
  rm -rf "$td"
}
_hdr_case T12.a '`## Task N:` + 전부 선언 → PASS' '## Task %s: 제목' '**미재사용 근거**: 문서만 고친다' 0
_hdr_case T12.b '`### Task N:` + 전부 선언 → PASS' '### Task %s: 제목' '**미재사용 근거**: 문서만 고친다' 0
_hdr_case T12.c '`### 태스크 N:` + 전부 선언 → PASS' '### 태스크 %s: 제목' '**미재사용 근거**: 문서만 고친다' 0
_hdr_case T12.d '`## Task N:` 에서도 누락은 잡는다 → FAIL' '## Task %s: 제목' '' 1
printf '%s' "$LAST_OUT" | grep -q 'Task 2' \
  && ok "T12.e 누락 태스크를 제목으로 지목" || nope "T12.e" "out=$LAST_OUT"

# T12.f: 골격 생성기 출력에 선언만 얹으면 통과해야 한다 (생성기 ↔ 게이트 계약)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
cat > "$TD/.specops/20260806-f/plan.md" <<'EOF'
# plan

## Task 1: 라우트 추가

**파일**: src/a.ts

- [ ] **Step 1: RED**

```bash
echo red
```

## Task 2: 문서

**파일**: README.md

- [ ] **Step 1: RED**

```bash
echo red
```
EOF
(cd "$TD" && bash "$PLUGIN/scripts/dag/plan-to-tasks.sh" 20260806-f > skel.md 2>/dev/null); skel_rc=$?
{ awk '{ print } /^\*\*파일\*\*: src\/a.ts/ { print ""; print "**재사용 foundation**: 라우팅" }
       /^\*\*파일\*\*: README.md/ { print ""; print "**미재사용 근거**: 문서만 고친다" }' "$TD/skel.md"
  _yaml2; } > "$TD/.specops/20260806-f/tasks.md"
out=$(cd "$TD" && bash "$CHK" 20260806-f 2>&1); rc=$?
[ "$skel_rc" -eq 0 ] && [ "$rc" -eq 0 ] \
  && ok "T12.f plan-to-tasks 골격 + 선언 → PASS" || nope "T12.f" "skel_rc=$skel_rc rc=$rc out=$out"
rm -rf "$TD"

# T12.g: 코드펜스 안의 선언은 선언이 아니다 (manifest 본문을 싣는 태스크가 선언한 것처럼 보이면 안 된다)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
{ printf '# 태스크\n\n## 태스크 1: a\n\n**재사용 foundation**: 라우팅\n\n## 태스크 2: b\n\n```markdown\n**재사용 foundation**: 예시 문구\n```\n'
  _yaml2; } > "$TD/.specops/20260806-f/tasks.md"
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T12.g 펜스 안 선언은 불인정 → FAIL" || nope "T12.g" "rc=$rc"
rm -rf "$TD"

# T12.h: 코드펜스 안의 제목은 절이 아니다 (YAML 2 · 실제 절 1 → 미검사 태스크 적발)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
{ printf '# 태스크\n\n## 태스크 1: a\n\n**재사용 foundation**: 라우팅\n\n````markdown\n```\n(위 3백틱은 4백틱 펜스를 닫지 못한다)\n## 태스크 2: 예시\n**재사용 foundation**: 예시\n````\n'
  _yaml2; } > "$TD/.specops/20260806-f/tasks.md"
out=$(cd "$TD" && bash "$CHK" 20260806-f 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'T2' \
  && ok "T12.h 펜스 안 제목은 절로 세지 않는다 → 미검사 T2 적발" || nope "T12.h" "rc=$rc out=$out"
rm -rf "$TD"

# T12.i: 번호 없는 제목(`## 태스크 개요`)은 절이 아니다
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
{ printf '# 태스크\n\n## 태스크 개요\n\n**재사용 foundation**: 라우팅\n\n## 태스크 1: a\n\n**재사용 foundation**: 라우팅\n'
  _yaml2; } > "$TD/.specops/20260806-f/tasks.md"
out=$(cd "$TD" && bash "$CHK" 20260806-f 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'T2' \
  && ok "T12.i 번호 없는 제목은 절로 세지 않는다" || nope "T12.i" "rc=$rc out=$out"
rm -rf "$TD"

# T12.j: 절을 하나도 못 찾으면 사유가 '선언 누락'이 아니라 **제목 표기**임을 말한다
#   (종전: "재사용 선언 누락·무효" 만 나와 호출자가 검사기 소스를 읽어 원인을 알아냈다)
_hdr_case T12.j '인식 못 하는 제목(`## T1:`) → FAIL' '## T%s: 제목' '**미재사용 근거**: 문서만 고친다' 1
printf '%s' "$LAST_OUT" | grep -q '제목' && printf '%s' "$LAST_OUT" | grep -qE '## (Task|태스크) N' \
  && ok "T12.k 제목 표기가 원인임을 알리고 인정 형식을 보여 준다" || nope "T12.k" "out=$LAST_OUT"

# ── T12.l~: 독립 리뷰 반영 ──────────────────────────────────────────────────────
_raw_case() {  # $1=id $2=설명 $3=기대 rc $4=출력에 있어야 할 문자열(선택) · stdin=tasks.md 본문(그대로)
  local td out rc
  td=$(mktemp -d); _mk "$td" 20260806-f 신규 y
  cat > "$td/.specops/20260806-f/tasks.md"
  out=$(cd "$td" && bash "$CHK" 20260806-f 2>&1); rc=$?
  if [ "$rc" -eq "$3" ] && { [ -z "${4:-}" ] || printf '%s' "$out" | grep -qF -- "$4"; }; then ok "$1 $2"
  else nope "$1" "rc=$rc(기대 $3) out=$out"; fi
  rm -rf "$td"
}
# CRLF: 줄 끝 CR 이 값으로 남아 빈 선언·placeholder 선언이 통과하면 안 된다
_raw_case T12.l 'CRLF + placeholder 선언 → FAIL' 1 < <(printf '## 태스크 1: a\r\n**재사용 foundation**: <모듈명>\r\n')
_raw_case T12.m 'CRLF + 빈 선언 → FAIL' 1 < <(printf '## 태스크 1: a\r\n**재사용 foundation**: \r\n')
_raw_case T12.n 'CRLF + 정상 선언 → PASS' 0 < <(printf '## 태스크 1: a\r\n**재사용 foundation**: 라우팅\r\n')
# 닫히지 않은 펜스: 뒤 태스크가 통째로 가려진다 — YAML 대조가 없어도 막는다
_raw_case T12.o '닫히지 않은 펜스(DAG 없음) → FAIL + 사유' 1 '닫히지 않은 코드펜스' < <(printf '## 태스크 1: a\n**재사용 foundation**: 라우팅\n```bash\necho\n\n## 태스크 2: b\n')
# 한 줄 인라인 코드(```echo hi```)는 펜스가 아니다 — 뒤 태스크를 가리지 않는다
_raw_case T12.p '한 줄 인라인 코드 뒤의 미선언 태스크 → FAIL + 지목' 1 '태스크 2' < <(printf '## 태스크 1: a\n**재사용 foundation**: 라우팅\n```echo hi```\n\n## 태스크 2: b\n')
_raw_case T12.q '한 줄 인라인 코드가 있어도 전부 선언이면 PASS' 0 < <(printf '## 태스크 1: a\n**재사용 foundation**: 라우팅\n```echo hi```\n\n## 태스크 2: b\n**미재사용 근거**: 문서\n')
# 물결 펜스는 백틱으로 닫히지 않는다
_raw_case T12.r '물결 펜스 안의 제목은 절이 아니다 → PASS(절 1개)' 0 < <(printf '## 태스크 1: a\n**재사용 foundation**: 라우팅\n~~~\n```\n## 태스크 2: 예시\n~~~\n')

finish
