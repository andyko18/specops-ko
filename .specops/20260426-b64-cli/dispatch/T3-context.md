# Dispatch Context: T3 (FID 20260426-b64-cli)

> leaf subagent가 받는 5 컨텍스트. 부모(implementing-ko)가 dispatch 직전 작성.

## 1. 담당 AC

- AC-7: Given b64val.sh 실행 권한 / When `b64val.sh "aGVsbG8="` / Then stdout `valid` + exit 0
- AC-8: Given b64val.sh 실행 권한 / When `b64val.sh "hello!"` / Then stdout `invalid: invalid characters` + exit 1
- AC-9: Given b64val.sh 실행 권한 / When `b64val.sh "aGVsbG8"` (길이 7) / Then stdout `invalid: invalid padding` + exit 1
- AC-12: Given b64val.sh 실행 권한 / When `b64val.sh ""` / Then stdout `invalid: empty input` + exit 1

## 2. 관련 spec.md 섹션

- `.specops/20260426-b64-cli/spec.md` §4 기능 요구사항 FR-6, FR-7, FR-8, FR-9
- `.specops/20260426-b64-cli/acceptance-criteria.md` AC-7, AC-8, AC-9, AC-12

## 3. 테스트 명령

```bash
bash scripts/tests/test-b64val.sh
```

기대 출력: `PASS=7 FAIL=0`

## 4. 수정 허용 파일 (whitelist)

- `scripts/b64val.sh`
- `scripts/tests/test-b64val.sh`

> ⚠️ 위 외 파일 수정 금지. spec/AC/plan/tasks 같은 sprint contract은 read-only.

## 5. 작업 디렉터리

- `/Users/mac/code/specops-auto-ko/.worktrees/20260426-b64-cli-T3/`

> ⚠️ leaf는 이 디렉터리 안에서만 작업. 부모 main worktree 직접 수정 금지.

---

## 구현 지시

다음 TDD 5스텝을 순서대로 실행한다:

**스텝 1 RED**: `scripts/tests/test-b64val.sh` 를 아래 내용으로 생성하고 `chmod +x` 부여:

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

# T3.b: 허용 안 되는 문자 "hello!" → "invalid: invalid characters" (AC-8)
out=$("$SCRIPT" "hello!"); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid characters" ] \
  && ok "T3.b invalid characters" || fail "T3.b (rc=$rc out='$out')"

# T3.c: 패딩 누락 "aGVsbG8" (길이 7) → "invalid: invalid padding" (AC-9)
out=$("$SCRIPT" "aGVsbG8"); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.c invalid padding" || fail "T3.c (rc=$rc out='$out')"

# T3.d: 빈 문자열 → "invalid: empty input" exit 1 (AC-12)
out=$("$SCRIPT" ""); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: empty input" ] \
  && ok "T3.d empty input" || fail "T3.d (rc=$rc out='$out')"

# T3.e: 중간에 = 포함 "aG=sbG8=" → "invalid: invalid padding"
out=$("$SCRIPT" "aG=sbG8="); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.e = in middle" || fail "T3.e (rc=$rc out='$out')"

# T3.f: stdin 유효 입력 "dGVzdA==" → "valid" exit 0 (AC-7 stdin)
out=$(printf '%s' "dGVzdA==" | "$SCRIPT"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "valid" ] \
  && ok "T3.f stdin valid" || fail "T3.f (rc=$rc out='$out')"

# T3.g: 패딩 3개 "aGVs===" → "invalid: invalid padding"
out=$("$SCRIPT" "aGVs==="); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.g triple padding" || fail "T3.g (rc=$rc out='$out')"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

**스텝 2 FAIL 검증**: `bash scripts/tests/test-b64val.sh` 실행 → FAIL 확인

**스텝 3 GREEN**: `scripts/b64val.sh` 를 아래 내용으로 생성하고 `chmod +x` 부여:

```bash
#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: b64val.sh [BASE64_STRING]\n'
  printf '       echo BASE64_STRING | b64val.sh\n\n'
  printf 'Validate a base64 string (charset + padding rules).\n'
  printf '  Exit 0 + "valid":             valid base64\n'
  printf '  Exit 1 + "invalid: <reason>": invalid\n'
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

**스텝 4 PASS 검증**: `bash scripts/tests/test-b64val.sh` 실행 → `PASS=7 FAIL=0` 확인

**스텝 5 COMMIT**: 아래 명령으로 커밋:

```bash
git add scripts/b64val.sh scripts/tests/test-b64val.sh
git commit -m "feat(b64val): Base64 검증기 CLI

문자셋([A-Za-z0-9+/=]) + 패딩 규칙(길이 4배수, = 끝에만 최대 2개) 검사.
빈 문자열 거부, stdin 겸용.

관련 AC: AC-7, AC-8, AC-9, AC-12"
```
