<!-- FID: 20260426-epoch-iso-cli -->
<!-- OWNER_COMMAND: /tasks -->
<!-- MUTABLE_BY: /implement (상태 마킹만) -->
<!-- layer: Lifecycle-Artifact -->

# epoch ↔ ISO 8601 CLI 태스크 목록 — 20260426-epoch-iso-cli

> 각 태스크는 TDD 5 스텝(RED → 검증 → GREEN → 검증 → COMMIT)을 따릅니다.

**관련 플랜**: `.specops/20260426-epoch-iso-cli/plan.md`
**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8

## AC → Task 매핑

| AC | must/should | Task(s) |
|---|---|---|
| AC-1 epoch(초)→ISO | must | Task 1 |
| AC-2 epoch(ms)→ISO | must | Task 2 |
| AC-3 ISO(Z)→epoch(초) | must | Task 3 |
| AC-4 ISO(.mmm)→epoch ms | must | Task 4 |
| AC-5 stdin 입력 | must | Task 4 |
| AC-6 인식 불가 → exit 1 | must | Task 4 |
| AC-7 --help | should | Task 4 |
| AC-8 +00:00 offset 입력 | should | Task 4 |

**must AC 커버리지**: 6/6 (100%)

---

## 태스크 1: 테스트 스켈레톤 + epoch(초) → ISO 변환

**파일**:
- Create: `scripts/epoch.sh`
- Create: `scripts/tests/test-epoch.sh`

**관련 AC**: AC-1

- [ ] **스텝 1: RED — 실패 테스트 작성**

`scripts/tests/test-epoch.sh` 를 아래 내용으로 생성:

```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/epoch.sh"

# T1.a AC-1: epoch(초) → ISO
out=$("$SCRIPT" 1777161600 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "2026-04-26T00:00:00Z" ]; then
  PASS=$((PASS+1)); echo "PASS T1.a epoch-sec-to-iso"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (rc=$rc got='$out')"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

```bash
chmod +x scripts/tests/test-epoch.sh
```

- [ ] **스텝 2: FAIL 검증**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `FAIL T1.a` + `FAIL=1`

- [ ] **스텝 3: GREEN — epoch.sh 최소 구현**

`scripts/epoch.sh` 를 아래 내용으로 생성:

```bash
#!/usr/bin/env bash
set -u

IS_GNU_DATE=false

usage() {
  printf 'Usage: epoch.sh [VALUE]\n'
  printf '       echo VALUE | epoch.sh\n\n'
  printf 'Convert between epoch integer and ISO 8601 UTC string.\n'
  printf '  epoch (10-digit sec / 13-digit ms) → ISO 8601 UTC\n'
  printf '  ISO 8601 (Z or +00:00 suffix)      → epoch integer\n'
}

detect_platform() {
  if date --version >/dev/null 2>&1; then
    IS_GNU_DATE=true
  fi
}

epoch_to_iso() {
  local epoch="$1"
  local len="${#epoch}"
  if [ "$len" -eq 10 ]; then
    if $IS_GNU_DATE; then
      TZ=UTC date -d "@${epoch}" "+%Y-%m-%dT%H:%M:%SZ"
    else
      TZ=UTC date -r "${epoch}" "+%Y-%m-%dT%H:%M:%SZ"
    fi
  else
    printf 'epoch.sh: error: unrecognized epoch length: %s\n' "$epoch" >&2; exit 1
  fi
}

iso_to_epoch() {
  printf 'epoch.sh: error: ISO parsing not yet implemented\n' >&2; exit 1
}

dispatch() {
  local input="$1"
  if [ -z "$input" ]; then
    printf 'epoch.sh: error: empty input\n' >&2; exit 1
  fi
  if printf '%s' "$input" | grep -qE '^[0-9]+$'; then
    epoch_to_iso "$input"
  else
    iso_to_epoch "$input"
  fi
}

detect_platform
if [ $# -ge 1 ]; then
  if [ "$1" = "--help" ]; then usage; exit 0; fi
  dispatch "$1"
else
  input=$(cat)
  dispatch "$input"
fi
```

```bash
chmod +x scripts/epoch.sh
```

- [ ] **스텝 4: PASS 검증**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS T1.a` + `PASS=1 FAIL=0`

- [ ] **스텝 5: COMMIT**

```bash
git add scripts/epoch.sh scripts/tests/test-epoch.sh
git commit -m "feat(epoch-iso): T1 테스트 스켈레톤 + epoch(초)→ISO 변환

관련 AC: AC-1"
```

---

## 태스크 2: epoch(밀리초) → ISO 변환

**파일**:
- Modify: `scripts/epoch.sh` — `epoch_to_iso()` 13자리 분기 추가
- Modify: `scripts/tests/test-epoch.sh` — T1.b 테스트 추가

**관련 AC**: AC-2

- [ ] **스텝 1: RED — 실패 테스트 추가**

`scripts/tests/test-epoch.sh` 의 `echo "--- SUMMARY ---"` 줄 **바로 위**에 추가:

```bash
# T1.b AC-2: epoch(밀리초) → ISO
out=$("$SCRIPT" 1777161600123 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "2026-04-26T00:00:00.123Z" ]; then
  PASS=$((PASS+1)); echo "PASS T1.b epoch-ms-to-iso"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (rc=$rc got='$out')"
fi
```

- [ ] **스텝 2: FAIL 검증**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS T1.a`, `FAIL T1.b` + `FAIL=1`

- [ ] **스텝 3: GREEN — 13자리 분기 구현**

`scripts/epoch.sh` 의 `epoch_to_iso()` 에서 `else` 분기를 교체:

변경 전:
```bash
  else
    printf 'epoch.sh: error: unrecognized epoch length: %s\n' "$epoch" >&2; exit 1
  fi
```

변경 후:
```bash
  elif [ "$len" -eq 13 ]; then
    local sec=$((epoch / 1000))
    local ms=$((epoch % 1000))
    local iso_sec
    if $IS_GNU_DATE; then
      iso_sec=$(TZ=UTC date -d "@${sec}" "+%Y-%m-%dT%H:%M:%S")
    else
      iso_sec=$(TZ=UTC date -r "${sec}" "+%Y-%m-%dT%H:%M:%S")
    fi
    printf '%s.%03dZ\n' "$iso_sec" "$ms"
  else
    printf 'epoch.sh: error: unrecognized epoch length: %s\n' "$epoch" >&2; exit 1
  fi
```

- [ ] **스텝 4: PASS 검증**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS T1.a`, `PASS T1.b` + `PASS=2 FAIL=0`

- [ ] **스텝 5: COMMIT**

```bash
git add scripts/epoch.sh scripts/tests/test-epoch.sh
git commit -m "feat(epoch-iso): T2 epoch(밀리초)→ISO 변환

관련 AC: AC-2"
```

---

## 태스크 3: ISO(Z) → epoch 초 변환

**파일**:
- Modify: `scripts/epoch.sh` — `iso_to_epoch()` 실제 구현
- Modify: `scripts/tests/test-epoch.sh` — T2.a 테스트 추가

**관련 AC**: AC-3

- [ ] **스텝 1: RED — 실패 테스트 추가**

`scripts/tests/test-epoch.sh` 의 `echo "--- SUMMARY ---"` 줄 바로 위에 추가:

```bash
# T2.a AC-3: ISO(Z) → epoch 초
out=$("$SCRIPT" "2026-04-26T00:00:00Z" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "1777161600" ]; then
  PASS=$((PASS+1)); echo "PASS T2.a iso-to-epoch-sec"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (rc=$rc got='$out')"
fi
```

- [ ] **스텝 2: FAIL 검증**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS T1.a`, `PASS T1.b`, `FAIL T2.a` + `FAIL=1`

- [ ] **스텝 3: GREEN — iso_to_epoch() 구현**

`scripts/epoch.sh` 의 `iso_to_epoch()` 전체를 교체:

```bash
iso_to_epoch() {
  local iso="$1"
  local normalized="${iso/+00:00/Z}"
  local has_ms=false
  local ms_part=""

  if printf '%s' "$normalized" | grep -qE '\.[0-9]+Z$'; then
    ms_part=$(printf '%s' "$normalized" | grep -oE '\.[0-9]+' | tr -d '.')
    normalized=$(printf '%s' "$normalized" | sed 's/\.[0-9]*//')
    has_ms=true
  fi

  local sec
  if $IS_GNU_DATE; then
    local gnu_input="${normalized/Z/ UTC}"
    sec=$(TZ=UTC date -d "$gnu_input" "+%s" 2>/dev/null)
  else
    sec=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$normalized" "+%s" 2>/dev/null)
  fi

  if [ -z "$sec" ]; then
    printf 'epoch.sh: error: cannot parse ISO 8601: %s\n' "$1" >&2; exit 1
  fi

  if $has_ms; then
    local ms_3
    ms_3=$(printf '%s000' "$ms_part" | cut -c1-3)
    printf '%s%s\n' "$sec" "$ms_3"
  else
    printf '%s\n' "$sec"
  fi
}
```

- [ ] **스텝 4: PASS 검증**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS T1.a`, `PASS T1.b`, `PASS T2.a` + `PASS=3 FAIL=0`

- [ ] **스텝 5: COMMIT**

```bash
git add scripts/epoch.sh scripts/tests/test-epoch.sh
git commit -m "feat(epoch-iso): T3 ISO(Z)→epoch 초 변환

관련 AC: AC-3"
```

---

## 태스크 4: ISO(ms)·+00:00·stdin·에러·--help

**파일**:
- Modify: `scripts/tests/test-epoch.sh` — T2.b ~ T4.c 테스트 추가
- Modify: `scripts/epoch.sh` — 버그 수정 시에만

**관련 AC**: AC-4, AC-5, AC-6, AC-7, AC-8

- [ ] **스텝 1: RED — 나머지 테스트 추가**

`scripts/tests/test-epoch.sh` 의 `echo "--- SUMMARY ---"` 줄 바로 위에 추가:

```bash
# T2.b AC-4: ISO(.mmm) → epoch ms
out=$("$SCRIPT" "2026-04-26T00:00:00.123Z" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "1777161600123" ]; then
  PASS=$((PASS+1)); echo "PASS T2.b iso-ms-to-epoch-ms"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.b (rc=$rc got='$out')"
fi

# T3.a AC-5: stdin
out=$(printf '%s' "1777161600" | "$SCRIPT" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "2026-04-26T00:00:00Z" ]; then
  PASS=$((PASS+1)); echo "PASS T3.a stdin"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a (rc=$rc got='$out')"
fi

# T4.a AC-6: 인식 불가 입력 → exit 1
out=$("$SCRIPT" "not-valid" 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then
  PASS=$((PASS+1)); echo "PASS T4.a invalid-input"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (rc=$rc got='$out')"
fi

# T4.b AC-7: --help → exit 0 + "Usage"
out=$("$SCRIPT" --help 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "Usage"; then
  PASS=$((PASS+1)); echo "PASS T4.b --help"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.b (rc=$rc out=$out)"
fi

# T4.c AC-8: +00:00 offset → 1777161600
out=$("$SCRIPT" "2026-04-26T00:00:00+00:00" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "1777161600" ]; then
  PASS=$((PASS+1)); echo "PASS T4.c plus00-offset"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.c (rc=$rc got='$out')"
fi
```

- [ ] **스텝 2: FAIL 검증**

```bash
bash scripts/tests/test-epoch.sh
```
예상: T1.a·T1.b·T2.a PASS, T2.b ~ T4.c 중 일부 FAIL

- [ ] **스텝 3: GREEN — 필요 시 수정**

T2.b (AC-4): Task 3 구현이 이미 커버. FAIL 시 `iso_to_epoch()` ms_3 패딩 확인:
```bash
# ms_part 가 "123" 이면 ms_3 = "123"
# ms_part 가 "1" 이면 ms_3 = "100"
ms_3=$(printf '%s000' "$ms_part" | cut -c1-3)
```

T4.a (AC-6): `dispatch()` 가 `iso_to_epoch "$input"` 로 라우팅하고, iso_to_epoch 가 파싱 실패 시 exit 1 — Task 3 구현이 커버.

T4.c (AC-8): `iso_to_epoch()` 첫 줄 `normalized="${iso/+00:00/Z}"` 가 커버.

모든 케이스가 기존 구현으로 PASS 되면 수정 불필요.

- [ ] **스텝 4: PASS 검증**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS=8 FAIL=0`

- [ ] **스텝 5: COMMIT**

```bash
git add scripts/epoch.sh scripts/tests/test-epoch.sh
git commit -m "feat(epoch-iso): T4 ISO(ms)·+00:00·stdin·에러·help — AC-1~8 PASS"
```

---

## 진행 상태

총 태스크 수: 4
완료: 0 / 4
차단: 0

## 참조

- `.specops/20260426-epoch-iso-cli/plan.md` — 상세 설계
- `.specops/20260426-epoch-iso-cli/acceptance-criteria.md` — 계약
- `skills/tdd-ko/SKILL.md` — TDD 5 스텝
- `templates/test-conventions-bash.md` — bash 테스트 컨벤션

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-epoch-iso-cli · 생성 커맨드: /tasks*
