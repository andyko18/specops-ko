#!/usr/bin/env bash
# specops-ko · hooks/ensure-session-progress.sh 회귀 테스트
# 검증 분기: 멱등성·is-hook-enabled disabled·template 부재·project 치환·mkdir -p
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
HOOK="$PLUGIN/hooks/ensure-session-progress.sh"


# setup_temp_plugin: $tmp_plugin 디렉토리에 ensure 실행에 필요한 최소 PLUGIN_ROOT 구성
# 인자 1: with-template (true|false) — templates/session-progress.md 포함 여부
setup_temp_plugin() {
  local tmp_plugin="$1"
  local with_template="$2"
  mkdir -p "$tmp_plugin/hooks" "$tmp_plugin/scripts/_internal"
  cp "$PLUGIN/hooks/ensure-session-progress.sh" "$tmp_plugin/hooks/"
  cp "$PLUGIN/scripts/_internal/is-hook-enabled.sh" "$tmp_plugin/scripts/_internal/"
  if [ "$with_template" = "true" ]; then
    mkdir -p "$tmp_plugin/templates"
    cp "$PLUGIN/templates/session-progress.md" "$tmp_plugin/templates/"
  fi
}

# ── T1.a 멱등성 ──────────────────────────────────────────────────────────
tmp=$(mktemp -d)
(cd "$tmp" && bash "$HOOK" >/dev/null 2>&1)   # 첫 호출 — 생성
T1a_out=$(cd "$tmp" && bash "$HOOK" 2>&1)
T1a_rc=$?
[ "$T1a_rc" -eq 0 ] && [ -z "$T1a_out" ] \
  && ok "T1.a 멱등 — target 존재 시 noop (stdout 빈, rc=0)" \
  || fail "T1.a 멱등 — target 존재 시 noop (rc=$T1a_rc, out='$T1a_out')"
rm -rf "$tmp"

# ── T1.b is-hook-enabled disabled (SPECOPS_CONFIG mock) ─────────────────
# prereq: python3 + pyyaml. is-hook-enabled.sh 가 graceful degradation
# (pyyaml 부재 시 default enabled, exit 0) 하므로 미설치 환경에서는
# disable 시뮬레이션 자체가 불가. project 패턴 일관 — validate-structure.sh:98
# 도 동일 graceful SKIP 사용.
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c "import yaml" 2>/dev/null; then
  skip "T1.b (python3+pyyaml 부재 — is-hook-enabled disable 시뮬레이션 불가)"
else
  tmp=$(mktemp -d)
  cat > "$tmp/config.yaml" <<'YAML'
profile: test-disabled
profiles:
  test-disabled:
    enforce_all_disabled: true
YAML
  T1b_out=$(cd "$tmp" && SPECOPS_CONFIG="$tmp/config.yaml" bash "$HOOK" 2>&1)
  T1b_rc=$?
  [ "$T1b_rc" -eq 0 ] && [ ! -f "$tmp/.specops/session-progress.md" ] \
    && ok "T1.b is-hook-enabled disabled → exit 0 + 파일 생성 안 함" \
    || fail "T1.b is-hook-enabled disabled (rc=$T1b_rc, file 존재=$([ -f \"$tmp/.specops/session-progress.md\" ] && echo yes || echo no))"
  rm -rf "$tmp"
fi

# ── T1.c template 부재 → exit 1 + stderr 에러 ─────────────────────────
tmp=$(mktemp -d)
tmp_plugin="$tmp/plugin"
setup_temp_plugin "$tmp_plugin" "false"   # templates/ 미생성
tmp_work="$tmp/work"
mkdir -p "$tmp_work"
T1c_out=$(cd "$tmp_work" && bash "$tmp_plugin/hooks/ensure-session-progress.sh" 2>&1)
T1c_rc=$?
[ "$T1c_rc" -eq 1 ] && echo "$T1c_out" | grep -q "template not found" \
  && [ ! -f "$tmp_work/.specops/session-progress.md" ] \
  && ok "T1.c template 부재 → exit 1 + stderr 'template not found'" \
  || fail "T1.c template 부재 (rc=$T1c_rc, out='$T1c_out')"
rm -rf "$tmp"

# ── T1.d project 인자 치환 ─────────────────────────────────────────────
# 주: tasks.md 원본의 `|| echo 0` 패턴은 BSD grep -c 와 비호환 (매칭 0 시
# stdout "0" + exit 1 → 두 번 echo). ${var:-0} 패턴으로 정정.
tmp=$(mktemp -d)
T1d_out=$(cd "$tmp" && bash "$HOOK" "my-proj" 2>&1)
T1d_rc=$?
match_count=$(grep -c "my-proj" "$tmp/.specops/session-progress.md" 2>/dev/null)
match_count=${match_count:-0}
placeholder_count=$(grep -c "<project-name>" "$tmp/.specops/session-progress.md" 2>/dev/null)
placeholder_count=${placeholder_count:-0}
[ "$T1d_rc" -eq 0 ] && [ "$match_count" -ge 1 ] && [ "$placeholder_count" -eq 0 ] \
  && ok "T1.d project 인자 치환 (my-proj=${match_count}건, placeholder=${placeholder_count}건)" \
  || fail "T1.d project 인자 치환 (rc=$T1d_rc, my-proj=$match_count, placeholder=$placeholder_count)"
rm -rf "$tmp"

# ── T1.e mkdir -p .specops 자동 생성 ──────────────────────────────────
tmp=$(mktemp -d)
[ ! -d "$tmp/.specops" ] || { echo "FATAL: 사전 조건 위배 — .specops 이미 존재"; exit 99; }
(cd "$tmp" && bash "$HOOK" >/dev/null 2>&1)
T1e_rc=$?
[ "$T1e_rc" -eq 0 ] && [ -d "$tmp/.specops" ] && [ -f "$tmp/.specops/session-progress.md" ] \
  && ok "T1.e mkdir -p .specops → 디렉토리 + 파일 자동 생성" \
  || fail "T1.e mkdir -p .specops (rc=$T1e_rc, dir 존재=$([ -d $tmp/.specops ] && echo yes || echo no), file 존재=$([ -f $tmp/.specops/session-progress.md ] && echo yes || echo no))"
rm -rf "$tmp"

# ── T1.f .specops 디렉토리 symlink → 외부 write-through 차단 (#144 대칭) ──
tmp=$(mktemp -d)
outside=$(mktemp -d)
ln -s "$outside" "$tmp/.specops"
(cd "$tmp" && bash "$HOOK" >/dev/null 2>&1)
T1f_rc=$?
[ "$T1f_rc" -eq 0 ] && [ ! -f "$outside/session-progress.md" ] \
  && ok "T1.f .specops symlink → write 거부 (rc=0, 외부 미생성)" \
  || fail "T1.f .specops symlink write 거부 (rc=$T1f_rc, 외부생성=$([ -f "$outside/session-progress.md" ] && echo yes || echo no))"
rm -rf "$tmp" "$outside"

# ── T1.g session-progress.md dangling symlink → sed 관통 차단 (#144 대칭) ──
tmp=$(mktemp -d)
outside=$(mktemp -d)
mkdir -p "$tmp/.specops"
ln -s "$outside/leak.md" "$tmp/.specops/session-progress.md"   # dangling — L14 -f 통과
(cd "$tmp" && bash "$HOOK" >/dev/null 2>&1)
T1g_rc=$?
[ "$T1g_rc" -eq 0 ] && [ ! -f "$outside/leak.md" ] \
  && ok "T1.g target 파일 symlink → write 거부" \
  || fail "T1.g target 파일 symlink write 거부 (rc=$T1g_rc, 관통=$([ -f "$outside/leak.md" ] && echo yes || echo no))"
rm -rf "$tmp" "$outside"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
