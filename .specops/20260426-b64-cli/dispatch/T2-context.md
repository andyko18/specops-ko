# Dispatch Context: T2 (FID 20260426-b64-cli)

> leaf subagent가 받는 5 컨텍스트. 부모(implementing-ko)가 dispatch 직전 작성.

## 1. 담당 AC

- AC-4: Given b64dec.sh 실행 권한 / When `b64dec.sh "aGVsbG8="` / Then stdout `hello` + exit 0
- AC-5: Given b64dec.sh 실행 권한 / When `printf '%s' "aGVsbG8=" | b64dec.sh` / Then stdout `hello` + exit 0
- AC-6: Given b64dec.sh 실행 권한 / When `b64dec.sh "!!!invalid!!!"` / Then stderr 에러 메시지 + exit 1

## 2. 관련 spec.md 섹션

- `.specops/20260426-b64-cli/spec.md` §4 기능 요구사항 FR-3, FR-4, FR-5
- `.specops/20260426-b64-cli/acceptance-criteria.md` AC-4, AC-5, AC-6

## 3. 테스트 명령

```bash
bash scripts/tests/test-b64dec.sh
```

기대 출력: `PASS=5 FAIL=0`

## 4. 수정 허용 파일 (whitelist)

- `scripts/b64dec.sh`
- `scripts/tests/test-b64dec.sh`

> ⚠️ 위 외 파일 수정 금지. spec/AC/plan/tasks 같은 sprint contract은 read-only.

## 5. 작업 디렉터리

- `/Users/mac/code/specops-auto-ko/.worktrees/20260426-b64-cli-T2/`

> ⚠️ leaf는 이 디렉터리 안에서만 작업. 부모 main worktree 직접 수정 금지.

---

## 구현 지시

다음 TDD 5스텝을 순서대로 실행한다:

**스텝 1 RED**: `scripts/tests/test-b64dec.sh` 를 아래 내용으로 생성하고 `chmod +x` 부여:

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

# T2.d: --help → exit 0 + "Usage" 포함
out=$("$SCRIPT" --help 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "Usage" \
  && ok "T2.d --help" || fail "T2.d (rc=$rc out='$out')"

# T2.e: 패딩 2개 "dGVzdA==" → "test" (AC-4 확장)
out=$("$SCRIPT" "dGVzdA=="); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "test" ] \
  && ok "T2.e 패딩 2개 디코딩" || fail "T2.e (rc=$rc out='$out')"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

**스텝 2 FAIL 검증**: `bash scripts/tests/test-b64dec.sh` 실행 → FAIL 확인

**스텝 3 GREEN**: `scripts/b64dec.sh` 를 아래 내용으로 생성하고 `chmod +x` 부여:

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
  # 허용 문자셋 외 입력은 직접 거부 (macOS base64 -D lenient 방어)
  if printf '%s' "$input" | grep -qE '[^A-Za-z0-9+/=]'; then
    printf 'Error: decode failed — input is not valid base64\n' >&2
    return 1
  fi
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

**스텝 4 PASS 검증**: `bash scripts/tests/test-b64dec.sh` 실행 → `PASS=5 FAIL=0` 확인

**스텝 5 COMMIT**: 아래 명령으로 커밋:

```bash
git add scripts/b64dec.sh scripts/tests/test-b64dec.sh
git commit -m "feat(b64dec): Base64 디코더 CLI

인자+stdin 겸용, macOS/Linux base64 플래그 자동 감지.
잘못된 입력 시 charset 사전 검사 + stderr 에러 + exit 1.

관련 AC: AC-4, AC-5, AC-6"
```
