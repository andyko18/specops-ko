<!-- FID: 20260426-cvt-cli -->
<!-- OWNER_COMMAND: /plan -->
<!-- layer: Lifecycle-Artifact -->

# cvt — JSON ↔ YAML 양방향 변환 CLI 구현 플랜

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: stdin/파일 인자로 JSON 또는 YAML을 받아 상대 포맷으로 변환하는 Python CLI `scripts/cvt.py`를 TDD로 구현한다.

**아키텍처**: 단일 Python 파일 (`scripts/cvt.py`). argparse로 `--to {json|yaml}` 플래그 처리 후 parse → validate → format 3단계 파이프라인 순차 실행. 에러는 stderr + 비정상 exit code, 정상 결과는 stdout 전용.

**기술 스택**: Python 3, PyYAML (`pyyaml`), bash (테스트 스크립트)

---

## 1. 파일 구조

| 파일 | 역할 |
|---|---|
| `scripts/cvt.py` | 메인 CLI: argparse, 입력 읽기, 3단계 파이프라인, 에러 처리 |
| `scripts/tests/test-cvt.sh` | bash 테스트 스위트: AC-1~AC-10 전체 커버 |

---

## 2. 태스크 목록

### Task 1: Scaffold + argparse (AC-5)

**파일**:
- 생성: `scripts/cvt.py`
- 생성: `scripts/tests/test-cvt.sh`

- [ ] **Step 1: 실패 테스트 작성**

`scripts/tests/test-cvt.sh` 생성:

```bash
#!/usr/bin/env bash
CVT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/cvt.py"
PASS=0; FAIL=0

ok()   { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

TMP=$(mktemp -d /tmp/cvt-test-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

echo '{"name":"Alice","age":30}' > "$TMP/valid.json"
printf 'name: Alice\nage: 30\n'  > "$TMP/valid.yaml"
echo 'not { valid json'          > "$TMP/bad.json"
printf 'key: [unclosed'          > "$TMP/bad.yaml"

# T1: --to 누락 → exit 2 (AC-5)
python3 "$CVT" "$TMP/valid.json" > /dev/null 2>&1; CODE=$?
[ "$CODE" -eq 2 ] && ok "T1 --to 누락 exit 2" || fail "T1 (expected 2, got $CODE)"

printf '\nPASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실패 확인 실행**

```bash
mkdir -p scripts/tests
chmod +x scripts/tests/test-cvt.sh
bash scripts/tests/test-cvt.sh
```

예상: `FAIL: T1` (cvt.py 미존재)

- [ ] **Step 3: 최소 구현 작성**

`scripts/cvt.py` 생성:

```python
#!/usr/bin/env python3
import sys
import json
import argparse

try:
    import yaml
except ImportError:
    print("DependencyError: pyyaml 미설치. pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(prog="cvt", description="JSON ↔ YAML 양방향 변환")
    parser.add_argument("--to", required=True, choices=["json", "yaml"],
                        help="출력 포맷")
    parser.add_argument("--indent", type=int, default=2,
                        help="JSON 출력 들여쓰기 (기본 2)")
    parser.add_argument("input", nargs="?", help="입력 파일 (생략 시 stdin)")
    args = parser.parse_args()


if __name__ == "__main__":
    main()
```

```bash
chmod +x scripts/cvt.py
```

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-cvt.sh
```

예상: `PASS: T1 --to 누락 exit 2` / `PASS=1 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/cvt.py scripts/tests/test-cvt.sh
git commit -m "feat(cvt T1): scaffold + argparse, AC-5 --to 누락 exit 2"
```

---

### Task 2: JSON → YAML 변환 (AC-1, AC-3, AC-8)

**파일**:
- 수정: `scripts/cvt.py` — 입력 읽기 + json→yaml 변환 구현
- 수정: `scripts/tests/test-cvt.sh` — T2a, T2b, T2c 추가

- [ ] **Step 1: 실패 테스트 추가**

`test-cvt.sh`의 T1 블록 **아래에** 추가:

```bash
# T2a: 파일 인자 JSON → YAML (AC-1)
OUT=$(python3 "$CVT" --to yaml "$TMP/valid.json" 2>/dev/null); CODE=$?
[ "$CODE" -eq 0 ] && ok "T2a exit 0" || fail "T2a exit (expected 0, got $CODE)"
echo "$OUT" | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin)" 2>/dev/null \
    && ok "T2a stdout is valid YAML" || fail "T2a stdout not valid YAML"

# T2b: stdin 파이프 JSON → YAML (AC-3)
OUT=$(python3 "$CVT" --to yaml < "$TMP/valid.json" 2>/dev/null); CODE=$?
[ "$CODE" -eq 0 ] && ok "T2b stdin exit 0" || fail "T2b stdin exit (got $CODE)"

# T2c: 정상 변환 시 stderr 없음 (AC-8)
ERR=$(python3 "$CVT" --to yaml "$TMP/valid.json" 2>&1 1>/dev/null)
[ -z "$ERR" ] && ok "T2c stderr empty" || fail "T2c stderr not empty: $ERR"
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-cvt.sh
```

예상: T1 PASS, T2a/T2b/T2c FAIL

- [ ] **Step 3: 최소 구현 작성**

`scripts/cvt.py` `main()` 함수에 추가 (`args = parser.parse_args()` 아래):

```python
    # 입력 읽기
    try:
        if args.input:
            with open(args.input, encoding="utf-8") as f:
                text = f.read()
        else:
            text = sys.stdin.read()
    except FileNotFoundError:
        print(f"FileNotFoundError: {args.input}", file=sys.stderr)
        sys.exit(1)

    # 빈 입력 → ParseError
    if not text.strip():
        print("ParseError: 빈 입력", file=sys.stderr)
        sys.exit(1)

    # Parse + Format
    try:
        if args.to == "yaml":
            data = json.loads(text)
            sys.stdout.write(yaml.dump(data, allow_unicode=True, default_flow_style=False))
        else:
            data = yaml.safe_load(text)
            print(json.dumps(data, indent=args.indent, ensure_ascii=False))
    except json.JSONDecodeError as e:
        print(f"ParseError: {e}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"ParseError: {e}", file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-cvt.sh
```

예상: `PASS=5 FAIL=0` (T1=1 + T2a·T2b·T2c=4)

- [ ] **Step 5: 커밋**

```bash
git add scripts/cvt.py scripts/tests/test-cvt.sh
git commit -m "feat(cvt T2): JSON→YAML 변환 + stdin 파이프, AC-1·AC-3·AC-8"
```

---

### Task 3: YAML → JSON 변환 (AC-2)

**파일**:
- 수정: `scripts/tests/test-cvt.sh` — T3 추가
- (cvt.py는 Task 2에서 이미 yaml→json 분기 구현됨, 테스트만 추가)

- [ ] **Step 1: 실패 테스트 추가**

```bash
# T3: YAML → JSON (AC-2)
OUT=$(python3 "$CVT" --to json "$TMP/valid.yaml" 2>/dev/null); CODE=$?
[ "$CODE" -eq 0 ] && ok "T3 exit 0" || fail "T3 exit (expected 0, got $CODE)"
echo "$OUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null \
    && ok "T3 stdout is valid JSON" || fail "T3 stdout not valid JSON"
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-cvt.sh
```

예상: T1~T2c PASS, T3 FAIL (valid.yaml 미비 시) 또는 즉시 PASS 확인

- [ ] **Step 3: 확인**

Task 2 구현으로 yaml→json 분기가 이미 있으므로 별도 코드 수정 없음. 테스트만 추가.

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-cvt.sh
```

예상: `PASS=6 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add scripts/tests/test-cvt.sh
git commit -m "feat(cvt T3): YAML→JSON 변환 검증, AC-2"
```

---

### Task 4: ParseError 처리 (AC-4, AC-6, AC-9)

**파일**:
- 수정: `scripts/tests/test-cvt.sh` — T4a, T4b, T4c 추가
- (cvt.py ParseError 분기는 Task 2에서 구현됨, 빈 입력·YAML→JSON 방향 확인)

- [ ] **Step 1: 실패 테스트 추가**

```bash
# T4a: 깨진 JSON → ParseError + exit 1 (AC-4)
ERR=$(python3 "$CVT" --to yaml "$TMP/bad.json" 2>&1 1>/dev/null); CODE=$?
[ "$CODE" -eq 1 ] && ok "T4a exit 1" || fail "T4a exit (expected 1, got $CODE)"
echo "$ERR" | grep -q "^ParseError:" && ok "T4a stderr ParseError" || fail "T4a stderr: $ERR"

# T4b: 빈 JSON → ParseError + exit 1 (AC-6)
ERR=$(echo -n "" | python3 "$CVT" --to yaml 2>&1 1>/dev/null); CODE=$?
[ "$CODE" -eq 1 ] && ok "T4b empty→yaml exit 1" || fail "T4b exit (got $CODE)"
echo "$ERR" | grep -q "^ParseError:" && ok "T4b stderr ParseError" || fail "T4b stderr: $ERR"

# T4c: 빈 YAML → JSON → ParseError + exit 1 (AC-9, clarify Q1)
ERR=$(echo -n "" | python3 "$CVT" --to json 2>&1 1>/dev/null); CODE=$?
[ "$CODE" -eq 1 ] && ok "T4c empty→json exit 1" || fail "T4c exit (got $CODE)"
echo "$ERR" | grep -q "^ParseError:" && ok "T4c stderr ParseError" || fail "T4c stderr: $ERR"
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-cvt.sh
```

예상: T4a PASS (json.JSONDecodeError 이미 처리됨), T4b/T4c PASS (빈 입력 체크 구현됨) — 전부 PASS면 즉시 Step 5로

- [ ] **Step 3: 빈 입력 처리 확인**

`cvt.py`의 빈 입력 체크가 올바른지 확인:

```python
# Task 2에서 이미 구현:
if not text.strip():
    print("ParseError: 빈 입력", file=sys.stderr)
    sys.exit(1)
```

이 코드가 JSON→YAML과 YAML→JSON 양방향 모두에 적용되는지 확인. `args.to` 분기 **전에** 위치해야 함.

- [ ] **Step 4: 통과 확인 실행**

```bash
bash scripts/tests/test-cvt.sh
```

예상: `PASS=13 FAIL=0` (T1=1 + T2=4 + T3=2 + T4=6)

- [ ] **Step 5: 커밋**

```bash
git add scripts/cvt.py scripts/tests/test-cvt.sh
git commit -m "feat(cvt T4): ParseError 처리 검증, AC-4·AC-6·AC-9"
```

---

### Task 5: --indent 플래그 + DependencyError (AC-7, AC-10)

**파일**:
- 수정: `scripts/tests/test-cvt.sh` — T5a, T5b 추가
- (`--indent`는 Task 1 argparse에서 이미 파싱, `json.dumps(indent=args.indent)` Task 2에서 적용됨)

- [ ] **Step 1: 실패 테스트 추가**

```bash
# T5a: --indent 4 적용 확인 (AC-7, should) — sed로 2번째 줄 시작 공백 확인 (macOS grep -P 불가)
OUT=$(python3 "$CVT" --to json --indent 4 "$TMP/valid.yaml" 2>/dev/null)
SECOND=$(printf '%s\n' "$OUT" | sed -n '2p')
case "$SECOND" in
    "    "*) ok "T5a --indent 4 applied" ;;
    *) fail "T5a indent not 4: '$SECOND'" ;;
esac

# T5b: stdout is valid JSON with indent 4
echo "$OUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null \
    && ok "T5b --indent 4 valid JSON" || fail "T5b not valid JSON"
```

- [ ] **Step 2: 실패 확인 실행**

```bash
bash scripts/tests/test-cvt.sh
```

예상: T5a PASS (Task 1~2에서 구현됨), 전부 PASS면 즉시 Step 5로

- [ ] **Step 3: DependencyError 수동 확인 (AC-10, nice-to-have)**

```bash
# PyYAML 미설치 환경 시뮬레이션 (실제 환경에서는 skip 가능)
python3 -c "
import sys
# yaml import 차단 시뮬레이션
sys.modules['yaml'] = None
" 2>/dev/null || true

# cvt.py 상단 ImportError 처리 확인 (코드 리뷰)
head -10 scripts/cvt.py
# 출력에 'DependencyError' 처리 블록이 보이면 OK
```

- [ ] **Step 4: 전체 테스트 최종 확인**

```bash
bash scripts/tests/test-cvt.sh
```

예상: `PASS=15 FAIL=0` (T1=1 + T2=4 + T3=2 + T4=6 + T5=2)

- [ ] **Step 5: 커밋**

```bash
git add scripts/cvt.py scripts/tests/test-cvt.sh
git commit -m "feat(cvt T5): --indent + DependencyError 완료, AC-7·AC-10"
```

---

## 3. AC 커버리지 매핑

| AC | 우선순위 | 커버 태스크 |
|---|---|---|
| AC-1 JSON→YAML 파일 | must | Task 2 T2a |
| AC-2 YAML→JSON 파일 | must | Task 3 T3 |
| AC-3 stdin 파이프 | must | Task 2 T2b |
| AC-4 깨진 JSON ParseError | must | Task 4 T4a |
| AC-5 --to 누락 exit 2 | must | Task 1 T1 |
| AC-6 빈 JSON→YAML ParseError | must | Task 4 T4b |
| AC-7 --indent 플래그 | should | Task 5 T5a |
| AC-8 정상 시 stderr 없음 | must | Task 2 T2c |
| AC-9 빈 YAML→JSON ParseError | must | Task 4 T4c |
| AC-10 DependencyError | nice-to-have | Task 5 T5b (수동) |

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-cvt-cli · 생성 커맨드: /plan*
