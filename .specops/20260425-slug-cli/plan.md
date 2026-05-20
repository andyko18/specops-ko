<!-- FID: 20260425-slug-cli -->
<!-- OWNER_COMMAND: /plan -->
<!-- layer: Lifecycle-Artifact -->

# 한국어/영문 URL Slug 변환 CLI 구현 플랜

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: 한국어/영문 혼합 문자열을 pure bash + POSIX `od`로 URL slug로 변환하는 CLI `scripts/slug.sh`를 TDD로 구현한다.

**아키텍처**: `od -An -tu1`로 입력을 바이트 정수 배열로 변환, bash 산술로 UTF-8 코드포인트 계산, 한글 음절(U+AC00-U+D7A3)은 초/중/종성 분해 후 배열 매핑으로 로마자 변환, ASCII는 인라인 처리. 결과 문자열은 `tr -s`로 연속 `-` 축약 + bash 파라미터 확장으로 앞뒤 제거.

**기술 스택**: bash 3.2+, POSIX `od`, POSIX `tr`

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8

---

## 1. 가정 (5원칙 5번)

- `od -An -tu1`이 bash 3.2 + macOS 환경에서 정확히 동작함 (실측 Task 1에서 검증)
- bash 배열 인덱스 계산(`${arr[$i]}`)이 bash 3.2에서 정상 동작함
- `tr -s '-'`가 POSIX 표준으로 연속 dash 축약에 동작함
- 한글 음절 범위 외 3-byte UTF-8(CJK 한자 등)은 `-` 치환으로 충분

## 2. 파일 구조

### 생성
- `scripts/slug.sh` — 메인 CLI: 입력 파싱, UTF-8 바이트 변환, 로마자 매핑, 후처리
- `scripts/tests/test-slug.sh` — bash 테스트 스위트: AC-1~AC-8 전체 커버

### 수정
- 없음

## 3. 로마자 매핑 테이블 (구현 상수)

**초성 (CHO, 19개 — 인덱스 0~18)**:
```
g kk n d tt r m b pp s ss "" j jj ch k t p h
```

**중성 (JUNG, 21개 — 인덱스 0~20)**:
```
a ae ya yae eo e yeo ye o wa wae oe yo u wo we wi yu eu ui i
```

**종성 (JONG, 28개 — 인덱스 0~27, 0=없음)**:
```
"" k kk ks n nj nh t l lk lm lb ls lt lp lh m p ps s ss ng j ch k t p h
```

**분해 공식** (코드포인트 `cp` 기준):
```
idx      = cp - 44032
cho_i    = idx / 588
jung_i   = (idx % 588) / 28
jong_i   = idx % 28
```

**검증 예시**:
- `안` (U+C548, cp=50504): idx=6472, cho=11(ㅇ→""), jung=0(ㅏ→a), jong=4(ㄴ→n) → `an`
- `녕` (U+B155, cp=45397): idx=1365, cho=2(ㄴ→n), jung=6(ㅕ→yeo), jong=21(ㅇ→ng) → `nyeong`
- `안녕` → `annyeong` ✓

## 4. 태스크 개요

1. **Task 1** — 테스트 scaffold + `--help` (AC-6)
2. **Task 2** — ASCII 처리: 소문자화, 특수문자→dash, 후처리 (AC-2, AC-4, AC-7)
3. **Task 3** — 한글 로마자 변환: 3-byte UTF-8 파싱 + 배열 매핑 (AC-1, AC-3)
4. **Task 4** — 빈 입력 + stdin 지원 (AC-5, AC-8)

---

## Task 1: 테스트 scaffold + `--help`

**파일**:
- 생성: `scripts/slug.sh`
- 생성: `scripts/tests/test-slug.sh`

**관련 AC**: AC-6

- [ ] **Step 1: 실패 테스트 작성**

`scripts/tests/test-slug.sh` 생성:

```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/slug.sh"

# T1.a --help exits 0 and prints Usage
out=$("$SCRIPT" --help 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "Usage"; then
  PASS=$((PASS+1)); echo "PASS T1.a --help"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (rc=$rc out=$out)"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

- [ ] **Step 2: 실패 확인 실행**

```bash
chmod +x scripts/tests/test-slug.sh
bash scripts/tests/test-slug.sh
```

예상: `FAIL T1.a` (slug.sh 미존재)

- [ ] **Step 3: 최소 구현 작성**

`scripts/slug.sh` 생성:

```bash
#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: slug.sh [STRING]\n'
  printf '       echo STRING | slug.sh\n\n'
  printf 'Convert Korean/English string to URL slug.\n'
  printf '  - Korean syllables: romanized (국립국어원 revised romanization)\n'
  printf '  - Uppercase: lowercased\n'
  printf '  - Non-alphanumeric: replaced with -\n'
}

if [ $# -ge 1 ] && [ "$1" = "--help" ]; then
  usage; exit 0
fi
```

```bash
chmod +x scripts/slug.sh
```

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-slug.sh
```

예상: `PASS T1.a`, `PASS=1 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/slug.sh scripts/tests/test-slug.sh
git commit -m "feat(slug): scaffold + --help (AC-6)"
```

---

## Task 2: ASCII 처리 (소문자화·특수문자·후처리)

**파일**:
- 수정: `scripts/slug.sh`
- 수정: `scripts/tests/test-slug.sh`

**관련 AC**: AC-2, AC-4, AC-7

- [ ] **Step 1: 실패 테스트 작성**

`scripts/tests/test-slug.sh`에 추가 (T1.a 블록 아래, SUMMARY 위):

```bash
# T2.a "Hello World" → "hello-world"
out=$("$SCRIPT" "Hello World"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "hello-world" ]; then
  PASS=$((PASS+1)); echo "PASS T2.a uppercase"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (got='$out')"
fi

# T2.b "  hello   world  " → "hello-world"
out=$("$SCRIPT" "  hello   world  "); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "hello-world" ]; then
  PASS=$((PASS+1)); echo "PASS T2.b leading/trailing/consecutive spaces"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.b (got='$out')"
fi

# T2.c "hello!@#world" → "hello-world"
out=$("$SCRIPT" "hello!@#world"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "hello-world" ]; then
  PASS=$((PASS+1)); echo "PASS T2.c special chars"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.c (got='$out')"
fi
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-slug.sh
```

예상: `FAIL T2.a`, `FAIL T2.b`, `FAIL T2.c`

- [ ] **Step 3: 최소 구현 작성**

`scripts/slug.sh`에 `usage()` 다음, `--help` 분기 전에 추가:

```bash
to_slug() {
  local input="$1"
  local result=""
  local bytes i n b1 new_byte
  bytes=($(printf '%s' "$input" | od -An -tu1))
  i=0
  n=${#bytes[@]}

  while [ "$i" -lt "$n" ]; do
    b1=${bytes[$i]}

    if [ "$b1" -lt 128 ]; then
      if [ "$b1" -ge 65 ] && [ "$b1" -le 90 ]; then
        # A-Z → a-z
        new_byte=$((b1 + 32))
        result="${result}$(printf "\\$(printf '%03o' "$new_byte")")"
      elif { [ "$b1" -ge 97 ] && [ "$b1" -le 122 ]; } || \
           { [ "$b1" -ge 48 ] && [ "$b1" -le 57 ]; }; then
        # a-z or 0-9
        result="${result}$(printf "\\$(printf '%03o' "$b1")")"
      else
        result="${result}-"
      fi
      i=$((i + 1))
    else
      # non-ASCII (한글 포함) — Task 3에서 구현. 지금은 skip
      i=$((i + 1))
    fi
  done

  # collapse consecutive dashes, strip leading/trailing
  result=$(printf '%s' "$result" | tr -s '-')
  result="${result#-}"
  result="${result%-}"
  printf '%s\n' "$result"
}
```

`--help` 분기 이후 파일 끝에 추가:

```bash
if [ $# -ge 1 ]; then
  to_slug "$1"
else
  input=$(cat)
  to_slug "$input"
fi
```

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-slug.sh
```

예상: T1.a·T2.a·T2.b·T2.c PASS, `PASS=4 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/slug.sh scripts/tests/test-slug.sh
git commit -m "feat(slug): ASCII 소문자화 + 특수문자→dash + 후처리 (AC-2·4·7)"
```

---

## Task 3: 한글 로마자 변환

**파일**:
- 수정: `scripts/slug.sh` (to_slug 내 non-ASCII 분기 구현)
- 수정: `scripts/tests/test-slug.sh`

**관련 AC**: AC-1, AC-3

- [ ] **Step 1: 실패 테스트 작성**

```bash
# T3.a "안녕" → "annyeong"
out=$("$SCRIPT" "안녕"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "annyeong" ]; then
  PASS=$((PASS+1)); echo "PASS T3.a 한글 only"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a (got='$out')"
fi

# T3.b "안녕 World 2024" → "annyeong-world-2024"
out=$("$SCRIPT" "안녕 World 2024"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "annyeong-world-2024" ]; then
  PASS=$((PASS+1)); echo "PASS T3.b 한글+영문 혼합"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.b (got='$out')"
fi

# T3.c "Hello 세계" → "hello-segye"
out=$("$SCRIPT" "Hello 세계"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "hello-segye" ]; then
  PASS=$((PASS+1)); echo "PASS T3.c 영문+한글 혼합"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.c (got='$out')"
fi
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-slug.sh
```

예상: T3.a·T3.b·T3.c FAIL (non-ASCII 분기가 아직 `-` 치환)

- [ ] **Step 3: 최소 구현 작성**

`scripts/slug.sh`의 `to_slug()` 최상단 (`local bytes` 전)에 테이블 추가:

```bash
to_slug() {
  local input="$1"
  local CHO JUNG JONG
  CHO=("g" "kk" "n" "d" "tt" "r" "m" "b" "pp" "s" "ss" "" "j" "jj" "ch" "k" "t" "p" "h")
  JUNG=("a" "ae" "ya" "yae" "eo" "e" "yeo" "ye" "o" "wa" "wae" "oe" "yo" "u" "wo" "we" "wi" "yu" "eu" "ui" "i")
  JONG=("" "k" "kk" "ks" "n" "nj" "nh" "t" "l" "lk" "lm" "lb" "ls" "lt" "lp" "lh" "m" "p" "ps" "s" "ss" "ng" "j" "ch" "k" "t" "p" "h")
  local result=""
  local bytes i n b1 b2 b3 new_byte cp idx cho_i jung_i jong_i
  bytes=($(printf '%s' "$input" | od -An -tu1))
  i=0
  n=${#bytes[@]}

  while [ "$i" -lt "$n" ]; do
    b1=${bytes[$i]}

    if [ "$b1" -lt 128 ]; then
      # ASCII (Task 2 구현 그대로)
      if [ "$b1" -ge 65 ] && [ "$b1" -le 90 ]; then
        new_byte=$((b1 + 32))
        result="${result}$(printf "\\$(printf '%03o' "$new_byte")")"
      elif { [ "$b1" -ge 97 ] && [ "$b1" -le 122 ]; } || \
           { [ "$b1" -ge 48 ] && [ "$b1" -le 57 ]; }; then
        result="${result}$(printf "\\$(printf '%03o' "$b1")")"
      else
        result="${result}-"
      fi
      i=$((i + 1))

    elif [ "$b1" -ge 224 ] && [ "$b1" -le 239 ]; then
      # 3-byte UTF-8 (BMP U+0800..U+FFFF)
      if [ $((i + 2)) -lt "$n" ]; then
        b2=${bytes[$((i+1))]}
        b3=${bytes[$((i+2))]}
        cp=$(( ((b1 & 15) << 12) | ((b2 & 63) << 6) | (b3 & 63) ))
        if [ "$cp" -ge 44032 ] && [ "$cp" -le 55203 ]; then
          idx=$((cp - 44032))
          cho_i=$((idx / 588))
          jung_i=$(( (idx % 588) / 28 ))
          jong_i=$((idx % 28))
          result="${result}${CHO[$cho_i]}${JUNG[$jung_i]}${JONG[$jong_i]}"
        else
          result="${result}-"
        fi
      else
        result="${result}-"
      fi
      i=$((i + 3))

    elif [ "$b1" -ge 192 ] && [ "$b1" -le 223 ]; then
      # 2-byte UTF-8 — not Korean
      result="${result}-"
      i=$((i + 2))

    elif [ "$b1" -ge 240 ]; then
      # 4-byte UTF-8 (emoji etc)
      result="${result}-"
      i=$((i + 4))

    else
      # continuation byte or invalid
      i=$((i + 1))
    fi
  done

  result=$(printf '%s' "$result" | tr -s '-')
  result="${result#-}"
  result="${result%-}"
  printf '%s\n' "$result"
}
```

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-slug.sh
```

예상: 전체 PASS, `PASS=7 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/slug.sh scripts/tests/test-slug.sh
git commit -m "feat(slug): 한글 로마자 변환 (3-byte UTF-8 + 초/중/종성 매핑) (AC-1·3)"
```

---

## Task 4: 빈 입력 + stdin 지원

**파일**:
- 수정: `scripts/tests/test-slug.sh`

**관련 AC**: AC-5, AC-8

- [ ] **Step 1: 실패 테스트 작성**

```bash
# T4.a 빈 입력 → 빈 출력 + exit 0
out=$("$SCRIPT" ""); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "" ]; then
  PASS=$((PASS+1)); echo "PASS T4.a 빈 입력 exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (rc=$rc got='$out')"
fi

# T4.b stdin 파이프 지원
out=$(printf '%s' "Hello 세계" | "$SCRIPT"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "hello-segye" ]; then
  PASS=$((PASS+1)); echo "PASS T4.b stdin pipe"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.b (rc=$rc got='$out')"
fi
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-slug.sh
```

예상: T4.a·T4.b 모두 PASS (Task 2·3 구현이 이미 처리) 또는 FAIL (edge case 확인)

  > stdin 분기(`else input=$(cat); to_slug "$input"`)는 Task 2 Step 3에서 이미 구현됨. T4.b는 PASS 예상.
  > 빈 입력 `""` → bytes 배열 비어있음 → result="" → 후처리 후 printf "" → T4.a도 PASS 예상.
  > 만약 FAIL이면 Step 3으로 진행.

- [ ] **Step 3: 픽스 (필요 시)**

T4.a FAIL 시 — `to_slug`에서 빈 배열 처리 확인:
```bash
# n=0 이면 루프 건너뜀 → result="" → printf '\n' 출력 확인
# printf '%s\n' "" → 빈 줄 출력 (정상)
```

T4.b FAIL 시 — stdin 분기 확인:
```bash
# slug.sh 끝부분:
if [ $# -ge 1 ] && [ "$1" != "--help" ]; then
  to_slug "$1"
else
  # --help 분기는 이미 처리됨. 여기는 순수 stdin
  input=$(cat)
  to_slug "$input"
fi
```

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-slug.sh
```

예상: `PASS=9 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/slug.sh scripts/tests/test-slug.sh
git commit -m "feat(slug): 빈 입력 + stdin 파이프 검증 (AC-5·8)"
```

---

## 5. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| `od -An -tu1` macOS/Linux 출력 형식 차이 | M | Task 1 Step 2에서 즉시 실측 확인. 실패 시 `od -v -An -tx1`으로 fallback 후 16진수 변환 |
| bash 배열이 비어있을 때 `${#bytes[@]}` = 0 | L | while 조건 `$i -lt $n`이 즉시 거짓 → 안전 |
| 연속 3-byte 시퀀스 경계 오류 | M | `$((i + 2)) -lt $n` 경계 체크로 방지 |
| 4-byte UTF-8 emoji가 `i += 4`로 과도 skip | L | emoji는 `-`로 치환됨 — 의도된 동작 |

## 6. 자체 검토 (5원칙 체크리스트)

- [x] **투명성**: 각 Task에 "왜 이 순서인가" 명시 (ASCII 먼저, 한글 나중 — 의존성 없음)
- [x] **문지기**: 파괴적 작업 없음
- [x] **주권 존중**: 사용자 승인 지점 없음 (새 파일만 생성)
- [x] **한계 고백**: §1 가정에 od 동작 가정 명시

**스펙 커버리지 확인**:
- AC-1 한글 변환 → Task 3 T3.a ✓
- AC-2 영문 소문자 → Task 2 T2.a ✓
- AC-3 혼합 입력 → Task 3 T3.b, T3.c ✓
- AC-4 연속 구분자 → Task 2 T2.b ✓
- AC-5 stdin → Task 4 T4.b ✓
- AC-6 --help → Task 1 T1.a ✓
- AC-7 특수문자 → Task 2 T2.c ✓
- AC-8 빈 입력 → Task 4 T4.a ✓

모든 must AC 커버됨.

## 7. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음.

---

*작성: kohaedong · 2026-04-25 · FID: 20260425-slug-cli · 생성 커맨드: /plan*
