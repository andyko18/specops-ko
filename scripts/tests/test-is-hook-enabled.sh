#!/usr/bin/env bash
# specops-ko v0.2 묶음 3 · scripts/_internal/is-hook-enabled.sh 검증
# T1 config 없음 / T2 enabled:true / T3 enabled:false / T4 strict.enforce_all_hooks override / T5 pyyaml 없음
set -u
PASS=0; FAIL=0
PLUGIN=$(pwd)
SCRIPT="$PLUGIN/scripts/_internal/is-hook-enabled.sh"

# T1 config 파일 없음 → exit 0 (default enabled)
tmp=$(mktemp -d)
SPECOPS_CONFIG="$tmp/missing.yaml" bash "$SCRIPT" any-hook >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T1 config 부재 → exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T1 (rc=$rc, expect 0)"
fi
rm -rf "$tmp"

# T2 lite profile + hooks.foo.enabled:true → exit 0
tmp=$(mktemp -d)
cat > "$tmp/c.yaml" <<EOF
profile: lite
hooks:
  foo:
    enabled: true
profiles:
  lite:
    enforce_all_hooks: false
EOF
SPECOPS_CONFIG="$tmp/c.yaml" bash "$SCRIPT" foo >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T2 enabled:true → exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T2 (rc=$rc, expect 0)"
fi
rm -rf "$tmp"

# T3 lite profile + hooks.foo.enabled:false → exit 1
tmp=$(mktemp -d)
cat > "$tmp/c.yaml" <<EOF
profile: lite
hooks:
  foo:
    enabled: false
profiles:
  lite:
    enforce_all_hooks: false
EOF
SPECOPS_CONFIG="$tmp/c.yaml" bash "$SCRIPT" foo >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then
  PASS=$((PASS+1)); echo "PASS T3 enabled:false → exit 1"
else
  FAIL=$((FAIL+1)); echo "FAIL T3 (rc=$rc, expect 1)"
fi
rm -rf "$tmp"

# T4 strict.enforce_all_hooks=true → 개별 hooks.foo.enabled:false 무시 → exit 0
tmp=$(mktemp -d)
cat > "$tmp/c.yaml" <<EOF
profile: strict
hooks:
  foo:
    enabled: false
profiles:
  strict:
    enforce_all_hooks: true
EOF
SPECOPS_CONFIG="$tmp/c.yaml" bash "$SCRIPT" foo >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T4 strict override → exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T4 (rc=$rc, expect 0)"
fi
rm -rf "$tmp"

# T5 pyyaml 부재 시뮬레이션 → exit 0 + stderr 경고
# fake python3: yaml import 시 항상 exit 1, 다른 호출은 시스템 python3 위임
tmp=$(mktemp -d)
cat > "$tmp/c.yaml" <<EOF
profile: lite
hooks:
  foo:
    enabled: false
profiles:
  lite:
    enforce_all_hooks: false
EOF
mkdir "$tmp/bin"
SYS_PY=$(command -v python3)
cat > "$tmp/bin/python3" <<PYWRAP
#!/bin/sh
# 인자에 'import yaml'이 있으면 무조건 실패 (pyyaml 부재 시뮬)
case "\$*" in
  *"import yaml"*) exit 1 ;;
esac
exec "$SYS_PY" "\$@"
PYWRAP
chmod +x "$tmp/bin/python3"
err=$(SPECOPS_YAML_WARNED= SPECOPS_CONFIG="$tmp/c.yaml" PATH="$tmp/bin:$PATH" bash "$SCRIPT" foo 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 0 ] && echo "$err" | grep -q 'pyyaml'; then
  PASS=$((PASS+1)); echo "PASS T5 pyyaml 부재 → exit 0 + 경고"
else
  FAIL=$((FAIL+1)); echo "FAIL T5 (rc=$rc, err=$err)"
fi
rm -rf "$tmp"

# T6 none.enforce_all_disabled=true → hooks.foo.enabled:true 무시 → exit 1
tmp=$(mktemp -d)
cat > "$tmp/c.yaml" <<EOF
profile: none
hooks:
  foo:
    enabled: true
profiles:
  none:
    enforce_all_disabled: true
EOF
SPECOPS_CONFIG="$tmp/c.yaml" bash "$SCRIPT" foo >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then
  PASS=$((PASS+1)); echo "PASS T6 none.enforce_all_disabled override → exit 1"
else
  FAIL=$((FAIL+1)); echo "FAIL T6 (rc=$rc, expect 1)"
fi
rm -rf "$tmp"

# T7 (보너스) 실행권한
if [ -x "$SCRIPT" ]; then
  PASS=$((PASS+1)); echo "PASS T7 exec-bit"
else
  FAIL=$((FAIL+1)); echo "FAIL T7 exec-bit"
fi

echo "passed=$PASS failed=$FAIL"
exit $FAIL
