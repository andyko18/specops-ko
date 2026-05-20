<!-- FID: 20260426-b64-cli -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: github/spec-kit plan-template.md + obra/superpowers writing-plans -->
<!-- layer: Lifecycle-Artifact -->

# Base64 CLI 3종 구현 플랜 — 20260426-b64-cli

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: Base64 인코딩(`b64enc.sh`)·디코딩(`b64dec.sh`)·검증(`b64val.sh`) 3종을 서로 의존 없는 독립 bash CLI로 구현한다.

**아키텍처**: 3종 모두 `scripts/` 하위 독립 파일. 인자+stdin 겸용 입력, 시스템 `base64` 명령 위임(인코더·디코더), bash 정규식 자체 검증(검증기). 기존 `slug.sh` 패턴 그대로 따른다.

**기술 스택**: bash 3.2+, 시스템 `base64` 명령 (macOS/Linux 기본 탑재)

**관련 AC**: AC-1~AC-12

---

## 1. 가정 (5원칙 5번)

- 시스템에 `base64` 명령이 존재한다.
- macOS에서는 `base64 -D`, Linux에서는 `base64 -d` 옵션이 동작한다.
- macOS `base64 -D`는 허용 문자셋 외 입력 시 non-zero exit를 반환한다 (Red 단계에서 실측 확인 필요).

## 2. 파일 구조

### 생성
- `scripts/b64enc.sh` — Base64 인코더 (인자+stdin, 한 줄 출력)
- `scripts/b64dec.sh` — Base64 디코더 (인자+stdin, macOS/Linux 자동 감지)
- `scripts/b64val.sh` — Base64 검증기 (문자셋 + 패딩 규칙, 자체 구현)
- `scripts/tests/test-b64enc.sh` — b64enc.sh 단위 테스트
- `scripts/tests/test-b64dec.sh` — b64dec.sh 단위 테스트
- `scripts/tests/test-b64val.sh` — b64val.sh 단위 테스트

---

## Task 1: b64enc.sh + test-b64enc.sh

**커버 AC**: AC-1 (인자 인코딩), AC-2 (stdin 인코딩), AC-3 (입력 없음 usage), AC-11 (빈 문자열)

**파일**:
- 생성: `scripts/b64enc.sh`
- 테스트: `scripts/tests/test-b64enc.sh`

- [ ] **Step 1: 실패 테스트 작성**

`scripts/tests/test-b64enc.sh` 전체 작성:

```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/b64enc.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# T1.a: 인자 인코딩 "hello" → "aGVsbG8=" (AC-1)
out=$("$SCRIPT" "hello"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "aGVsbG8=" ] \
  && ok "T1.a 인자 인코딩" || fail "T1.a (rc=$rc out='$out')"

# T1.b: stdin 인코딩 echo -n "hello" → "aGVsbG8=" (AC-2)
out=$(printf '%s' "hello" | "$SCRIPT"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "aGVsbG8=" ] \
  && ok "T1.b stdin 인코딩" || fail "T1.b (rc=$rc out='$out')"

# T1.c: 빈 인자 → 빈 출력 exit 0 (AC-11)
out=$("$SCRIPT" ""); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "" ] \
  && ok "T1.c 빈 문자열 exit 0" || fail "T1.c (rc=$rc out='$out')"

# T1.d: --help → exit 0 + "Usage" 출력
out=$("$SCRIPT" --help 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "Usage" \
  && ok "T1.d --help" || fail "T1.d (rc=$rc out='$out')"

# T1.e: 공백 포함 문자열 인자 (AC-1 확장)
out=$("$SCRIPT" "hello world"); rc=$?
expected=$(printf '%s' "hello world" | base64 | tr -d '\n')
[ "$rc" -eq 0 ] && [ "$out" = "$expected" ] \
  && ok "T1.e 공백 포함 인코딩" || fail "T1.e (rc=$rc out='$out' expected='$expected')"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-b64enc.sh
```

예상: `FAIL T1.a` ~ `FAIL T1.e` (스크립트 미존재)

- [ ] **Step 3: b64enc.sh 구현**

`scripts/b64enc.sh` 작성:

```bash
#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: b64enc.sh [STRING]\n'
  printf '       echo STRING | b64enc.sh\n\n'
  printf 'Base64 encode a string (single-line output, no line wrapping).\n'
}

encode() {
  printf '%s' "$1" | base64 | tr -d '\n'
  printf '\n'
}

if [ $# -ge 1 ]; then
  case "$1" in
    --help) usage; exit 0 ;;
    *)      encode "$1" ;;
  esac
elif [ -t 0 ]; then
  usage; exit 1
else
  input=$(cat)
  encode "$input"
fi
```

실행 권한 부여:
```bash
chmod +x scripts/b64enc.sh
```

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-b64enc.sh
```

예상: `PASS=5 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/b64enc.sh scripts/tests/test-b64enc.sh
git commit -m "feat(b64enc): Base64 인코더 CLI (AC-1,2,3,11)"
```

---

## Task 2: b64dec.sh + test-b64dec.sh

**커버 AC**: AC-4 (인자 디코딩), AC-5 (stdin 디코딩), AC-6 (잘못된 입력 에러)

**파일**:
- 생성: `scripts/b64dec.sh`
- 테스트: `scripts/tests/test-b64dec.sh`

- [ ] **Step 1: 실패 테스트 작성**

`scripts/tests/test-b64dec.sh` 전체 작성:

```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/b64dec.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# T2.a: 인자 디코딩 "aGVsbG8=" → "hello" (AC-4)
out=$("$SCRIPT" "aGVsbG8="); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "hello" ] \
  && ok "T2.a 인자 디코딩" || fail "T2.a (rc=$rc out='$out')"

# T2.b: stdin 디코딩 (AC-5)
out=$(printf '%s' "aGVsbG8=" | "$SCRIPT"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "hello" ] \
  && ok "T2.b stdin 디코딩" || fail "T2.b (rc=$rc out='$out')"

# T2.c: 잘못된 입력 → stderr 에러 + exit 1 (AC-6)
err=$("$SCRIPT" "!!!invalid!!!" 2>&1 1>/dev/null); rc=$?
[ "$rc" -ne 0 ] && [ -n "$err" ] \
  && ok "T2.c 잘못된 입력 exit 1 + stderr" || fail "T2.c (rc=$rc err='$err')"

# T2.d: --help → exit 0 + "Usage" 출력
out=$("$SCRIPT" --help 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "Usage" \
  && ok "T2.d --help" || fail "T2.d (rc=$rc out='$out')"

# T2.e: 패딩 있는 다른 문자열 "dGVzdA==" → "test"
out=$("$SCRIPT" "dGVzdA=="); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "test" ] \
  && ok "T2.e 패딩 2개 디코딩" || fail "T2.e (rc=$rc out='$out')"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-b64dec.sh
```

예상: `FAIL T2.a` ~ `FAIL T2.e` (스크립트 미존재)

- [ ] **Step 3: b64dec.sh 구현**

`scripts/b64dec.sh` 작성:

```bash
#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: b64dec.sh [BASE64_STRING]\n'
  printf '       echo BASE64_STRING | b64dec.sh\n\n'
  printf 'Base64 decode a string.\n'
}

decode() {
  local input="$1"
  local flag="-d"
  [ "$(uname)" = "Darwin" ] && flag="-D"
  if ! printf '%s' "$input" | base64 "$flag" 2>/dev/null; then
    printf 'Error: decode failed — input is not valid base64\n' >&2
    return 1
  fi
}

if [ $# -ge 1 ]; then
  case "$1" in
    --help) usage; exit 0 ;;
    *)      decode "$1" || exit 1 ;;
  esac
elif [ -t 0 ]; then
  usage; exit 1
else
  input=$(cat)
  decode "$input" || exit 1
fi
```

실행 권한 부여:
```bash
chmod +x scripts/b64dec.sh
```

> **구현 주의**: macOS `base64 -D`가 `!!!` 입력 시 non-zero 반환을 실측 확인할 것. 만약 0을 반환하면(lenient), `b64val.sh`로 사전 검증 후 디코딩하는 방식으로 전환 — 단, 두 스크립트 간 직접 호출 금지 (AC-10). 대신 inline 검증 로직 복제.

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-b64dec.sh
```

예상: `PASS=5 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/b64dec.sh scripts/tests/test-b64dec.sh
git commit -m "feat(b64dec): Base64 디코더 CLI (AC-4,5,6)"
```

---

## Task 3: b64val.sh + test-b64val.sh

**커버 AC**: AC-7 (유효 검증), AC-8 (잘못된 문자), AC-9 (잘못된 패딩), AC-12 (빈 문자열 거부)

**파일**:
- 생성: `scripts/b64val.sh`
- 테스트: `scripts/tests/test-b64val.sh`

- [ ] **Step 1: 실패 테스트 작성**

`scripts/tests/test-b64val.sh` 전체 작성:

```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/b64val.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# T3.a: 유효한 base64 "aGVsbG8=" → "valid" exit 0 (AC-7)
out=$("$SCRIPT" "aGVsbG8="); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "valid" ] \
  && ok "T3.a valid base64" || fail "T3.a (rc=$rc out='$out')"

# T3.b: 허용 안 되는 문자 "hello!" → "invalid: invalid characters" exit 1 (AC-8)
out=$("$SCRIPT" "hello!"); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid characters" ] \
  && ok "T3.b invalid characters" || fail "T3.b (rc=$rc out='$out')"

# T3.c: 패딩 누락 "aGVsbG8" (길이 7) → "invalid: invalid padding" exit 1 (AC-9)
out=$("$SCRIPT" "aGVsbG8"); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.c invalid padding (missing)" || fail "T3.c (rc=$rc out='$out')"

# T3.d: 빈 문자열 → "invalid: empty input" exit 1 (AC-12)
out=$("$SCRIPT" ""); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: empty input" ] \
  && ok "T3.d empty input" || fail "T3.d (rc=$rc out='$out')"

# T3.e: 중간에 = 포함 "aG=sbG8=" → "invalid: invalid padding" exit 1
out=$("$SCRIPT" "aG=sbG8="); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.e = in middle" || fail "T3.e (rc=$rc out='$out')"

# T3.f: stdin 입력 (AC-7 stdin 경로)
out=$(printf '%s' "dGVzdA==" | "$SCRIPT"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "valid" ] \
  && ok "T3.f stdin valid" || fail "T3.f (rc=$rc out='$out')"

# T3.g: 패딩 3개 "aGVs===" → "invalid: invalid padding" exit 1
out=$("$SCRIPT" "aGVs==="); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.g triple padding" || fail "T3.g (rc=$rc out='$out')"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-b64val.sh
```

예상: `FAIL T3.a` ~ `FAIL T3.g` (스크립트 미존재)

- [ ] **Step 3: b64val.sh 구현**

`scripts/b64val.sh` 작성:

```bash
#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: b64val.sh [BASE64_STRING]\n'
  printf '       echo BASE64_STRING | b64val.sh\n\n'
  printf 'Validate a base64 string (charset + padding rules).\n'
  printf '  Exit 0: valid\n'
  printf '  Exit 1: invalid\n'
}

validate() {
  local input="$1"

  if [ -z "$input" ]; then
    printf 'invalid: empty input\n'
    return 1
  fi

  if printf '%s' "$input" | grep -qE '[^A-Za-z0-9+/=]'; then
    printf 'invalid: invalid characters\n'
    return 1
  fi

  if ! printf '%s' "$input" | grep -qE '^[A-Za-z0-9+/]*={0,2}$'; then
    printf 'invalid: invalid padding\n'
    return 1
  fi

  local len=${#input}
  if [ $((len % 4)) -ne 0 ]; then
    printf 'invalid: invalid padding\n'
    return 1
  fi

  printf 'valid\n'
  return 0
}

if [ $# -ge 1 ]; then
  case "$1" in
    --help) usage; exit 0 ;;
    *)      validate "$1"; exit $? ;;
  esac
elif [ -t 0 ]; then
  usage; exit 1
else
  input=$(cat)
  validate "$input"; exit $?
fi
```

실행 권한 부여:
```bash
chmod +x scripts/b64val.sh
```

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-b64val.sh
```

예상: `PASS=7 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/b64val.sh scripts/tests/test-b64val.sh
git commit -m "feat(b64val): Base64 검증기 CLI (AC-7,8,9,12)"
```

---

## Task 4: 독립성 확인 + 전체 통합 실행

**커버 AC**: AC-10 (3종 독립성), 전체 PASS 확인

**파일**: 수정 없음 (검증만)

- [ ] **Step 1: AC-10 독립성 검사**

```bash
grep -rn 'source\|b64enc\|b64dec\|b64val' scripts/b64enc.sh scripts/b64dec.sh scripts/b64val.sh
```

예상: 출력 없음 (교차 참조 없음)

- [ ] **Step 2: 전체 테스트 실행**

```bash
bash scripts/tests/test-b64enc.sh && \
bash scripts/tests/test-b64dec.sh && \
bash scripts/tests/test-b64val.sh
```

예상: 각 `PASS=N FAIL=0`, exit 0

- [ ] **Step 3: 커밋 (변경 없으면 생략)**

변경사항이 있다면:
```bash
git add -p
git commit -m "chore(b64): AC-10 독립성 확인 완료"
```

---

## 자체 검토

**스펙 커버리지**:
- FR-1~FR-10: Task 1(FR-1,2), Task 2(FR-3,4,5), Task 3(FR-6,7,8,9), Task 4(FR-10) ✓
- AC-1~AC-12: 모두 태스크에 배정됨 ✓

**플레이스홀더 스캔**: TBD, TODO 없음 ✓

**타입 일관성**: bash 스크립트로 함수명 충돌 없음 (`encode`, `decode`, `validate` 각 파일 내 독립) ✓

**b64dec.sh macOS 주의사항**: macOS `base64 -D`의 lenient 동작 가능성을 Task 2 Step 3에 명시. Red 단계에서 실측 확인 후 inline 검증 로직 복제 방식으로 전환 가능.

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-b64-cli · 생성 커맨드: /plan*
