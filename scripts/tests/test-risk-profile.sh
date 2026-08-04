#!/usr/bin/env bash
# P1 위험 프로파일 limited-live 분류기 (Wave B)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
RP="$PLUGIN/scripts/_internal/risk-profile.sh"

_setup() {  # $1=dir $2=fid
  mkdir -p "$1/.specops/$2" "$1/src" "$1/docs"
  (cd "$1" && git init -q && printf 'base\n' > README.md && git add README.md \
    && git -c user.name=t -c user.email=t@e.com commit -qm init)
}

# T1: docs-only → lite (mode=live + batch-review-skip allowlist)
TD=$(mktemp -d); FID=20260803-rp-lite
_setup "$TD" "$FID"
printf '# note\n' > "$TD/docs/note.md"
(cd "$TD" && git add docs/note.md)
printf '**§유형**: 신규\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "lite" ] && jq -e '.mode=="live" and .reductions_applied==[] and (.reductions_allowed|index("batch-review-skip"))' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T1 docs-only → lite(live+allowlist)" || nope "T1" "out=$out"
rm -rf "$TD"

# T2: 코드 2파일 → standard (live, allowlist 빈 배열)
TD=$(mktemp -d); FID=20260803-rp-std
_setup "$TD" "$FID"
printf 'x\n' > "$TD/src/a.sh"; printf 'y\n' > "$TD/src/b.sh"
(cd "$TD" && git add src)
printf '**§유형**: 신규\n일반 기능\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "standard" ] && jq -e '.mode=="live" and .reductions_allowed==[]' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T2 코드 2파일 → standard(live·빈 allowlist)" || nope "T2" "out=$out"
rm -rf "$TD"

# T3: auth 키워드 1줄 → strict
TD=$(mktemp -d); FID=20260803-rp-auth
_setup "$TD" "$FID"
printf 'x\n' > "$TD/src/rbac.sh"
(cd "$TD" && git add src)
printf '**§유형**: 신규\n인증 RBAC 조건 1줄 변경\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "strict" ] && jq -e '.mode=="live" and .reductions_allowed==[] and (.signals.strict|index("auth"))' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T3 auth → strict(live·빈 allowlist)" || nope "T3" "out=$out"
rm -rf "$TD"

# T4: migration → strict
TD=$(mktemp -d); FID=20260803-rp-mig
_setup "$TD" "$FID"
mkdir -p "$TD/db/migrations"
printf 'ALTER TABLE t ADD c int;\n' > "$TD/db/migrations/001.sql"
(cd "$TD" && git add db)
printf 'migration 적용\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "strict" ] && ok "T4 migration → strict" || nope "T4" "out=$out"
rm -rf "$TD"

# T5: irreversible → strict
TD=$(mktemp -d); FID=20260803-rp-irr
_setup "$TD" "$FID"
printf 'x\n' > "$TD/src/a.sh"; (cd "$TD" && git add src)
cat > "$TD/.specops/$FID/tasks.md" <<'EOF'
# tasks
## 의존 그래프
```yaml
tasks:
  - id: T1
    irreversible: true
    depends_on: []
    outputs: [src/a.sh]
```
EOF
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "strict" ] && ok "T5 irreversible → strict" || nope "T5" "out=$out"
rm -rf "$TD"

# T6: parallel batch → strict
TD=$(mktemp -d); FID=20260803-rp-par
_setup "$TD" "$FID"
printf 'a\n' > "$TD/src/a.sh"; printf 'b\n' > "$TD/src/b.sh"
(cd "$TD" && git add src)
cat > "$TD/.specops/$FID/tasks.md" <<'EOF'
# tasks
## 의존 그래프
```yaml
tasks:
  - id: T1
    depends_on: []
    outputs: [src/a.sh]
  - id: T2
    depends_on: []
    outputs: [src/b.sh]
```
EOF
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "strict" ] && jq -e '.signals.parallel_batch==true' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T6 parallel → strict" || nope "T6" "out=$out"
rm -rf "$TD"

# T7: floor 상향
TD=$(mktemp -d); FID=20260803-rp-floor
_setup "$TD" "$FID"
printf '# d\n' > "$TD/docs/x.md"; (cd "$TD" && git add docs)
printf 'docs\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" --floor strict 2>/dev/null | tail -1)
[ "$out" = "strict" ] && jq -e '.computed=="lite" and .effective=="strict"' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T7 floor 상향" || nope "T7" "out=$out"
rm -rf "$TD"

# T8: floor 하향 거부
TD=$(mktemp -d); FID=20260803-rp-down
_setup "$TD" "$FID"
if (cd "$TD" && bash "$RP" compute "$FID" --floor lite >/dev/null 2>&1); then
  nope "T8" "하향 허용됨"
else
  ok "T8 floor 하향 거부"
fi
rm -rf "$TD"

# T9: code→md rename 위장 금지 (--no-renames 정합: delete+add로 코드 삭제 감지)
TD=$(mktemp -d); FID=20260803-rp-rename
_setup "$TD" "$FID"
printf 'code\n' > "$TD/src/tool.sh"
(cd "$TD" && git add src/tool.sh && git -c user.name=t -c user.email=t@e.com commit -qm add)
(cd "$TD" && git mv src/tool.sh docs/tool.md)
printf 'x\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
# rename decomposes to delete .sh + add .md → not docs-only → standard or strict
[ "$out" != "lite" ] && ok "T9 rename 위장 ≠ lite" || nope "T9" "out=$out"
rm -rf "$TD"

# T10: mixed docs+code → 비-lite
TD=$(mktemp -d); FID=20260803-rp-mix
_setup "$TD" "$FID"
printf 'd\n' > "$TD/docs/a.md"; printf 'c\n' > "$TD/src/a.sh"
(cd "$TD" && git add docs src)
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" != "lite" ] && ok "T10 mixed ≠ lite" || nope "T10" "out=$out"
rm -rf "$TD"

# T11: metrics append
TD=$(mktemp -d); FID=20260803-rp-met
_setup "$TD" "$FID"
printf '# d\n' > "$TD/docs/x.md"; (cd "$TD" && git add docs)
(cd "$TD" && bash "$RP" compute "$FID" >/dev/null)
jq -e '.phase=="risk-profile"' "$TD/.specops/$FID/metrics.jsonl" >/dev/null \
  && ok "T11 metrics phase=risk-profile" || nope "T11" "missing metric"
rm -rf "$TD"

# T12: bad FID
if bash "$RP" compute bad-id >/dev/null 2>&1; then
  nope "T12" "bad fid accepted"
else
  ok "T12 invalid FID 거부"
fi

# T13: §유형=trivial 단독 ≠ lite 강제
TD=$(mktemp -d); FID=20260803-rp-triv
_setup "$TD" "$FID"
printf 'a\n' > "$TD/src/a.sh"; printf 'b\n' > "$TD/src/b.sh"
(cd "$TD" && git add src)
printf '**§유형**: trivial\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "standard" ] && ok "T13 trivial ≠ lite 강제" || nope "T13" "out=$out"
rm -rf "$TD"

finish
