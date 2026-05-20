<!-- FID: 20260426-epoch-iso-cli -->
<!-- OWNER_COMMAND: /plan -->
<!-- layer: Lifecycle-Artifact -->

# epoch ↔ ISO 8601 양방향 변환 CLI 구현 플랜 — 20260426-epoch-iso-cli

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko`. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: `scripts/epoch.sh` 단일 bash 스크립트로 epoch 정수 ↔ ISO 8601 UTC 문자열을 양방향 변환한다.

**아키텍처**: 입력을 숫자(epoch) vs ISO 문자열로 자동 감지해 방향을 결정한다. macOS `date`(BSD)와 Linux `date`(GNU) 분기를 스크립트 시작 시 1회 감지해 변수로 관리한다. 밀리초는 자릿수(13자리) 또는 `.mmm` 패턴으로 감지한다.

**기술 스택**: bash 3.2+ · POSIX `date`, `grep`, `sed` · 기존 slug.sh / test-slug.sh 컨벤션 준수

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8

---

## 1. 가정 (5원칙 5번)

- `date --version` 실패 시 BSD date (macOS), 성공 시 GNU date (Linux)로 판별 가능
- Linux GNU date는 `date -d "...Z" +%s` 에서 Z suffix를 UTC로 파싱함 (문서 기반, 실측 미확인)
- `date -j -f "%Y-%m-%dT%H:%M:%SZ"` 가 macOS bash 3.2에서 동작함 (macOS 실측 예정)
- 10자리·13자리 자릿수 기준 초/밀리초 구분이 2001~2286년 범위에서 충분

## 2. 파일 구조

### 생성
- `scripts/epoch.sh` — 양방향 변환 메인 스크립트 (usage / detect_platform / epoch_to_iso / iso_to_epoch / main)
- `scripts/tests/test-epoch.sh` — bash 테스트 (test-slug.sh 컨벤션 준수)

### 수정
없음

### 삭제
없음

## 3. 함수 시그니처 계약

```bash
# 플랫폼 감지 — IS_GNU_DATE 전역 변수 설정
detect_platform()

# epoch 정수(초 또는 ms) → ISO 8601 UTC 문자열 → stdout
# $1: epoch 정수 (10자리=초, 13자리=ms)
epoch_to_iso() { local epoch="$1"; ... }

# ISO 8601 UTC 문자열 → epoch 정수(초 또는 ms) → stdout
# $1: ISO 문자열 (Z 또는 +00:00 suffix, .mmm 선택)
iso_to_epoch() { local iso="$1"; ... }

# 입력 감지 후 라우팅
# $1: 입력 문자열
dispatch() { local input="$1"; ... }

# 사용법 출력
usage()
```

## 4. 태스크 개요

1. **Task 1** — 테스트 파일 스켈레톤 + epoch(초) → ISO 변환 Red→Green
2. **Task 2** — epoch(밀리초) → ISO 변환 Red→Green
3. **Task 3** — ISO → epoch(초) 변환 Red→Green
4. **Task 4** — ISO(밀리초) → epoch(ms) · +00:00 · stdin · 에러 · --help Red→Green

## 5. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| macOS `date -j -f` 포맷 불일치 | H | Task 3에서 macOS 실측, 포맷 문자열 정밀 검증 |
| GNU date Z suffix 미파싱 | M | 정규화: `+00:00` → `Z`, `Z` → `UTC`로 치환 후 `date -d` 전달 |
| 13자리 경계 (2286년 이후 epoch) | L | 스펙 범위 외 — 에러 처리 불필요 |

## 6. 상세 태스크

---

### Task 1: 테스트 스켈레톤 + epoch(초) → ISO 변환

**파일**:
- 생성: `scripts/epoch.sh`
- 생성: `scripts/tests/test-epoch.sh`

- [ ] **Step 1: 테스트 파일 생성 (Red)**

`scripts/tests/test-epoch.sh`:
```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/epoch.sh"

# AC-1: epoch(초) → ISO
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

- [ ] **Step 2: 실패 확인**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `FAIL T1.a` + `FAIL=1`

- [ ] **Step 3: epoch.sh 스텁 생성**

`scripts/epoch.sh`:
```bash
#!/usr/bin/env bash
set -u

IS_GNU_DATE=false

usage() {
  printf 'Usage: epoch.sh [VALUE]\n'
  printf '       echo VALUE | epoch.sh\n\n'
  printf 'Convert between epoch integer and ISO 8601 UTC string.\n'
  printf '  epoch(10-digit sec / 13-digit ms) → ISO 8601\n'
  printf '  ISO 8601 (Z or +00:00)            → epoch integer\n'
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
    if "$IS_GNU_DATE"; then
      TZ=UTC date -d "@${epoch}" "+%Y-%m-%dT%H:%M:%SZ"
    else
      TZ=UTC date -r "${epoch}" "+%Y-%m-%dT%H:%M:%SZ"
    fi
  fi
}

dispatch() {
  local input="$1"
  if [ -z "$input" ]; then
    printf 'epoch.sh: error: empty input\n' >&2; exit 1
  fi
  if printf '%s' "$input" | grep -qE '^[0-9]+$'; then
    epoch_to_iso "$input"
  else
    printf 'epoch.sh: error: unrecognized input: %s\n' "$input" >&2; exit 1
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

- [ ] **Step 4: 통과 확인**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS T1.a` + `PASS=1 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/epoch.sh scripts/tests/test-epoch.sh
git commit -m "feat(epoch-iso): T1 epoch(초)→ISO 변환 + 테스트 스켈레톤"
```

---

### Task 2: epoch(밀리초) → ISO 변환

**파일**:
- 수정: `scripts/epoch.sh` — `epoch_to_iso()` 13자리 분기 추가
- 수정: `scripts/tests/test-epoch.sh` — AC-2 테스트 추가

- [ ] **Step 1: 테스트 추가 (Red)**

`scripts/tests/test-epoch.sh` 에 T1.a 블록 뒤에 추가:
```bash
# AC-2: epoch(밀리초) → ISO
out=$("$SCRIPT" 1777161600123 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "2026-04-26T00:00:00.123Z" ]; then
  PASS=$((PASS+1)); echo "PASS T1.b epoch-ms-to-iso"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (rc=$rc got='$out')"
fi
```

- [ ] **Step 2: 실패 확인**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `FAIL T1.b` + `FAIL=1`

- [ ] **Step 3: epoch_to_iso() 13자리 분기 추가**

`epoch_to_iso()` 함수의 `if [ "$len" -eq 10 ]` 블록 뒤에 추가:
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
```

- [ ] **Step 4: 통과 확인**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS T1.a` + `PASS T1.b` + `PASS=2 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/epoch.sh scripts/tests/test-epoch.sh
git commit -m "feat(epoch-iso): T2 epoch(ms)→ISO 변환"
```

---

### Task 3: ISO → epoch(초) 변환

**파일**:
- 수정: `scripts/epoch.sh` — `iso_to_epoch()` 구현 + `dispatch()` ISO 분기 연결
- 수정: `scripts/tests/test-epoch.sh` — AC-3 테스트 추가

- [ ] **Step 1: 테스트 추가 (Red)**

```bash
# AC-3: ISO → epoch(초)
out=$("$SCRIPT" "2026-04-26T00:00:00Z" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "1777161600" ]; then
  PASS=$((PASS+1)); echo "PASS T2.a iso-to-epoch-sec"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (rc=$rc got='$out')"
fi
```

- [ ] **Step 2: 실패 확인**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `FAIL T2.a` + `FAIL=1`

- [ ] **Step 3: iso_to_epoch() 구현 + dispatch 연결**

`epoch.sh` 에 `iso_to_epoch()` 함수 추가 (epoch_to_iso 뒤에):
```bash
iso_to_epoch() {
  local iso="$1"
  # +00:00 → Z 정규화
  local normalized="${iso/+00:00/Z}"
  local has_ms=false
  local ms_part=""

  # .mmm 추출
  if printf '%s' "$normalized" | grep -qE '\.[0-9]+Z$'; then
    ms_part=$(printf '%s' "$normalized" | grep -oE '\.[0-9]+' | tr -d '.')
    normalized=$(printf '%s' "$normalized" | sed 's/\.[0-9]*//')
    has_ms=true
  fi

  local sec
  if $IS_GNU_DATE; then
    # GNU date: Z를 UTC로 변환
    local gnu_input="${normalized/Z/ UTC}"
    sec=$(TZ=UTC date -d "$gnu_input" "+%s" 2>/dev/null)
  else
    # BSD date
    sec=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$normalized" "+%s" 2>/dev/null)
  fi

  if [ -z "$sec" ]; then
    printf 'epoch.sh: error: cannot parse ISO 8601: %s\n' "$1" >&2; exit 1
  fi

  if $has_ms; then
    # ms_part를 3자리로 패딩
    local ms_3
    ms_3=$(printf '%s000' "$ms_part" | cut -c1-3)
    printf '%s%s\n' "$sec" "$ms_3"
  else
    printf '%s\n' "$sec"
  fi
}
```

`dispatch()` 함수의 `epoch_to_iso` 뒤 else 분기를 수정:
```bash
  else
    iso_to_epoch "$input"
  fi
```

- [ ] **Step 4: 통과 확인**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS T1.a`, `PASS T1.b`, `PASS T2.a` + `PASS=3 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/epoch.sh scripts/tests/test-epoch.sh
git commit -m "feat(epoch-iso): T3 ISO→epoch(초) 변환"
```

---

### Task 4: ISO(ms)→epoch ms · +00:00 · stdin · 에러 · --help

**파일**:
- 수정: `scripts/tests/test-epoch.sh` — AC-4 ~ AC-8 테스트 추가
- 수정: `scripts/epoch.sh` — 필요 시 버그 수정 (Task 3 구현이 이미 대부분 커버)

- [ ] **Step 1: 나머지 테스트 추가 (Red)**

```bash
# AC-4: ISO(.mmm) → epoch ms
out=$("$SCRIPT" "2026-04-26T00:00:00.123Z" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "1777161600123" ]; then
  PASS=$((PASS+1)); echo "PASS T2.b iso-ms-to-epoch-ms"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.b (rc=$rc got='$out')"
fi

# AC-5: stdin
out=$(printf '%s' "1777161600" | "$SCRIPT" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "2026-04-26T00:00:00Z" ]; then
  PASS=$((PASS+1)); echo "PASS T3.a stdin"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a (rc=$rc got='$out')"
fi

# AC-6: 인식 불가 입력 → stderr + exit 1
out=$("$SCRIPT" "not-valid" 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then
  PASS=$((PASS+1)); echo "PASS T4.a invalid-input"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (rc=$rc got='$out')"
fi

# AC-7: --help → exit 0 + "Usage"
out=$("$SCRIPT" --help 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "Usage"; then
  PASS=$((PASS+1)); echo "PASS T4.b --help"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.b (rc=$rc out=$out)"
fi

# AC-8: +00:00 offset 입력
out=$("$SCRIPT" "2026-04-26T00:00:00+00:00" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "1777161600" ]; then
  PASS=$((PASS+1)); echo "PASS T4.c plus00-offset"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.c (rc=$rc got='$out')"
fi
```

- [ ] **Step 2: 실패 확인**

```bash
bash scripts/tests/test-epoch.sh
```
예상: T2.b ~ T4.c 중 일부 FAIL

- [ ] **Step 3: 버그 수정 (있으면)**

T2.b (AC-4) 는 Task 3 구현으로 이미 커버됨. 실패 시:
- `ms_part` 3자리 패딩 로직을 `iso_to_epoch()` 에서 확인
- `printf '%s%s\n' "$sec" "$ms_3"` 에서 `$ms_3` 가 정확히 3자리인지 검증

T3.a (AC-5) stdin 은 `dispatch()` 의 `cat` 경로가 이미 커버.

T4.c (AC-8) `+00:00` 정규화: `dispatch()` 에서 ISO 판별 전에 `input="${input/+00:00/Z}"` 추가 (iso_to_epoch 내 정규화와 중복 방지를 위해 iso_to_epoch 내부에서만 처리하는 것이 현재 설계 — dispatch에서 별도 처리 불필요):
```bash
# dispatch() 내 else 분기 — iso_to_epoch 내부 정규화가 처리하므로 그대로 전달
iso_to_epoch "$input"
```

- [ ] **Step 4: 전체 테스트 통과 확인**

```bash
bash scripts/tests/test-epoch.sh
```
예상: `PASS=8 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/epoch.sh scripts/tests/test-epoch.sh
git commit -m "feat(epoch-iso): T4 ISO(ms)·+00:00·stdin·에러·help — AC-1~8 PASS"
```

---

## 7. 자체 검토

- [x] **투명성**: 각 태스크 카테고리에 "왜"가 포함됨
- [x] **문지기**: 파괴적 작업 없음
- [x] **주권 존중**: 사용자 승인 지점 없음 (기존 패턴 준수)
- [x] **한계 고백**: §1 가정 4건 기록됨

**스펙 커버리지 확인**:
- FR-1 (epoch 초→ISO): Task 1 ✓
- FR-2 (epoch ms→ISO): Task 2 ✓
- FR-3 (ISO→epoch 초): Task 3 ✓
- FR-4 (ISO ms→epoch ms): Task 4 ✓
- FR-5 (stdin/$1): Task 1 + Task 4 ✓
- FR-6 (macOS/Linux 분기): Task 1 detect_platform ✓
- FR-7 (--help): Task 4 ✓
- FR-8 (에러 exit 1): Task 1 dispatch + Task 4 ✓

AC 전체 커버: AC-1 ~ AC-8 ✓

## 8. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음.

## 9. 다음 단계

`specops-auto-ko:decomposing-ko` → `specops-auto-ko:implementing-ko`

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-epoch-iso-cli · 생성 커맨드: /plan*
