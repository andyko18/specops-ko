<!-- specops-auto-ko v0.4a W2 — AC injection contract 표준 포맷 -->
<!-- 위치: .specops/20260426-cvt-cli/dispatch/T1-T5-context.md -->
<!-- 작성: implementing-ko 컨트롤러 (F-12 ESCAPE HATCH 집약 — 동일 파일 쌍 TDD 체인) -->
<!-- 집약 근거: T1~T5 모두 scripts/cvt.py + scripts/tests/test-cvt.sh 수정 / 총 ~150 LOC -->

# Dispatch Context: T1-T5 집약 (FID 20260426-cvt-cli)

> F-12 ESCAPE HATCH 적용 — 5 태스크 전체가 동일 파일 쌍(cvt.py + test-cvt.sh) 을 순차 수정.
> leaf subagent 가 받는 5 컨텍스트의 표준 포맷.
> 누락 또는 모호하다면 `NEEDS_CONTEXT` 반환 — 추측 금지.

## 1. 담당 AC

- AC-1: Given 유효 JSON 파일 / When cvt --to yaml / Then stdout YAML + exit 0
- AC-2: Given 유효 YAML 파일 / When cvt --to json / Then stdout JSON + exit 0
- AC-3: Given 유효 JSON stdin / When cvt --to yaml / Then stdout YAML + exit 0
- AC-4: Given 깨진 JSON / When cvt --to yaml / Then stderr ParseError: + exit 1
- AC-5: Given --to 없이 실행 / When cvt input.json / Then stderr usage + exit 2
- AC-6: Given 빈 JSON stdin / When cvt --to yaml / Then stderr ParseError: + exit 1
- AC-7: Given 유효 YAML / When cvt --to json --indent 4 / Then stdout 들여쓰기 4칸 JSON + exit 0 (should)
- AC-8: Given 유효 입력 / When 변환 실행 / Then stderr 완전히 비어 있음 + exit 0
- AC-9: Given 빈 YAML stdin / When cvt --to json / Then stderr ParseError: + exit 1

## 2. 관련 spec.md 섹션

- `.specops/20260426-cvt-cli/spec.md` §4 기능 요구사항 FR-1~FR-7
- `.specops/20260426-cvt-cli/spec.md` §2 범위 (포함/제외)
- `.specops/20260426-cvt-cli/acceptance-criteria.md` AC-1~AC-9
- `.specops/20260426-cvt-cli/clarifications.md` Q1~Q3 (빈 입력, DependencyError, 다중문서)

## 3. 테스트 명령

```bash
bash scripts/tests/test-cvt.sh
```

기대 출력: `PASS=15 FAIL=0` (T1.a~T5.b 전체 통과)

각 태스크별 중간 기대:
- Task 1 완료 후: `PASS=1 FAIL=0`
- Task 2 완료 후: `PASS=5 FAIL=0`
- Task 3 완료 후: `PASS=7 FAIL=0`
- Task 4 완료 후: `PASS=13 FAIL=0`
- Task 5 완료 후: `PASS=15 FAIL=0`

## 4. 수정 허용 파일 (whitelist)

- `scripts/cvt.py`
- `scripts/tests/test-cvt.sh`

> ⚠️ **위 외 파일 수정 금지**. spec/AC/plan/tasks 같은 sprint contract은 read-only.

## 5. 작업 디렉터리

- `/Users/mac/code/specops-auto-ko`

> F-12 ESCAPE HATCH: 별도 worktree 없음. main worktree에서 직접 작업.
> ⚠️ leaf는 `git commit` / `git push` 금지. `git add <whitelist 파일>` 만 허용.
> 완료 후 부모에 `proposed_commit_message` 반환 — 실제 commit은 부모 담당.

---

## 태스크 상세 (tasks.md 발췌 — T1~T5 전체)

### Task 1: Scaffold + argparse (AC-5)

`scripts/tests/test-cvt.sh` 신규 생성 (전체 파일):

```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CVT="$PLUGIN/scripts/cvt.py"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

TMP=$(mktemp -d /tmp/cvt-test-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

echo '{"name":"Alice","age":30}' > "$TMP/valid.json"
printf 'name: Alice\nage: 30\n'  > "$TMP/valid.yaml"
echo 'not { valid json'          > "$TMP/bad.json"

# T1.a: --to 누락 → exit 2 (AC-5)
python3 "$CVT" "$TMP/valid.json" > /dev/null 2>&1; CODE=$?
[ "$CODE" -eq 2 ] && ok "T1.a --to 누락 exit 2" || fail "T1.a (expected 2, got $CODE)"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

`scripts/cvt.py` 신규 생성 (전체 파일):

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

커밋 메시지: `feat(cvt T1): scaffold + argparse, AC-5 --to 누락 exit 2`

### Task 2: JSON → YAML 변환 (AC-1, AC-3, AC-8)

`test-cvt.sh`의 T1.a 블록 아래, `echo "--- SUMMARY ---"` 위에 추가:

```bash
# T2.a: 파일 인자 JSON → YAML exit 0 (AC-1)
OUT=$(python3 "$CVT" --to yaml "$TMP/valid.json" 2>/dev/null); CODE=$?
[ "$CODE" -eq 0 ] && ok "T2.a exit 0" || fail "T2.a (expected 0, got $CODE)"

# T2.b: stdout 이 유효한 YAML (AC-1)
echo "$OUT" | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin)" 2>/dev/null \
  && ok "T2.b stdout valid YAML" || fail "T2.b stdout not valid YAML"

# T2.c: stdin 파이프 JSON → YAML (AC-3)
OUT_PIPE=$(python3 "$CVT" --to yaml < "$TMP/valid.json" 2>/dev/null); CODE=$?
[ "$CODE" -eq 0 ] && ok "T2.c stdin pipe exit 0" || fail "T2.c stdin (expected 0, got $CODE)"

# T2.d: 정상 변환 시 stderr 없음 (AC-8)
ERR=$(python3 "$CVT" --to yaml "$TMP/valid.json" 2>&1 1>/dev/null)
[ -z "$ERR" ] && ok "T2.d stderr empty" || fail "T2.d stderr not empty: $ERR"
```

`cvt.py`의 `args = parser.parse_args()` 줄 아래에 추가:

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

    # 빈 입력 → ParseError (JSON·YAML 양방향 공통)
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

커밋 메시지: `feat(cvt T2): JSON→YAML 변환 + stdin 파이프, AC-1·AC-3·AC-8`

### Task 3: YAML → JSON 검증 (AC-2)

`test-cvt.sh`의 T2.d 블록 아래 추가:

```bash
# T3.a: 파일 인자 YAML → JSON exit 0 (AC-2)
OUT=$(python3 "$CVT" --to json "$TMP/valid.yaml" 2>/dev/null); CODE=$?
[ "$CODE" -eq 0 ] && ok "T3.a YAML→JSON exit 0" || fail "T3.a (expected 0, got $CODE)"

# T3.b: stdout 이 유효한 JSON (AC-2)
echo "$OUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null \
  && ok "T3.b stdout valid JSON" || fail "T3.b stdout not valid JSON"
```

커밋 메시지: `feat(cvt T3): YAML→JSON 변환 검증, AC-2`

### Task 4: ParseError 처리 (AC-4, AC-6, AC-9)

`test-cvt.sh`의 T3.b 블록 아래 추가:

```bash
# T4.a: 깨진 JSON → exit 1 (AC-4)
python3 "$CVT" --to yaml "$TMP/bad.json" > /dev/null 2>&1; CODE=$?
[ "$CODE" -eq 1 ] && ok "T4.a bad JSON exit 1" || fail "T4.a (expected 1, got $CODE)"

# T4.b: 깨진 JSON → stderr ParseError: (AC-4)
ERR=$(python3 "$CVT" --to yaml "$TMP/bad.json" 2>&1 1>/dev/null)
echo "$ERR" | grep -q "^ParseError:" && ok "T4.b stderr ParseError:" || fail "T4.b: $ERR"

# T4.c: 빈 JSON 입력 → exit 1 (AC-6)
echo -n "" | python3 "$CVT" --to yaml > /dev/null 2>&1; CODE=$?
[ "$CODE" -eq 1 ] && ok "T4.c empty JSON→YAML exit 1" || fail "T4.c (expected 1, got $CODE)"

# T4.d: 빈 JSON 입력 → stderr ParseError: (AC-6)
ERR=$(echo -n "" | python3 "$CVT" --to yaml 2>&1 1>/dev/null)
echo "$ERR" | grep -q "^ParseError:" && ok "T4.d stderr ParseError:" || fail "T4.d: $ERR"

# T4.e: 빈 YAML 입력 → JSON → exit 1 (AC-9)
echo -n "" | python3 "$CVT" --to json > /dev/null 2>&1; CODE=$?
[ "$CODE" -eq 1 ] && ok "T4.e empty YAML→JSON exit 1" || fail "T4.e (expected 1, got $CODE)"

# T4.f: 빈 YAML 입력 → JSON → stderr ParseError: (AC-9)
ERR=$(echo -n "" | python3 "$CVT" --to json 2>&1 1>/dev/null)
echo "$ERR" | grep -q "^ParseError:" && ok "T4.f stderr ParseError:" || fail "T4.f: $ERR"
```

커밋 메시지: `feat(cvt T4): ParseError 처리 검증, AC-4·AC-6·AC-9`

### Task 5: --indent + DependencyError (AC-7, AC-10)

`test-cvt.sh`의 T4.f 블록 아래 추가:

```bash
# T5.a: --indent 4 적용 확인 (AC-7, should)
OUT=$(python3 "$CVT" --to json --indent 4 "$TMP/valid.yaml" 2>/dev/null)
SECOND=$(printf '%s\n' "$OUT" | sed -n '2p')
case "$SECOND" in
    "    "*) ok "T5.a --indent 4 applied" ;;
    *) fail "T5.a indent not 4: '$SECOND'" ;;
esac

# T5.b: --indent 4 출력이 유효한 JSON
echo "$OUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null \
  && ok "T5.b --indent 4 valid JSON" || fail "T5.b not valid JSON"
```

커밋 메시지: `feat(cvt T5): --indent + DependencyError 완료, AC-7·AC-10`

---

## leaf 의무 (5원칙 주입)

| 원칙 | leaf 적용 |
|---|---|
| 1 투명성 | 5 컨텍스트 누락 시 즉시 NEEDS_CONTEXT 반환, 추측 금지 |
| 2 문지기 | whitelist 외 파일 수정 시도 시 즉시 중단 + NEEDS_CONTEXT |
| 3 깊이 | 테스트 명령 실제 실행 후에만 PASS 주장 |
| 4 주권 | git commit 권한 박탈 — 부모만 commit (R8 보강) |
| 5 한계 고백 | 자체검토 보고를 최종 결과로 주장 금지, 부모 검증 의무 |
