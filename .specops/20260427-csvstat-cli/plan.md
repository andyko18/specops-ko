# csvstat CLI + Python 지원 인프라 구현 플랜

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장). 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: Python 프로젝트 dogfood 인프라(test-conventions-python.md + decomposing-ko 업데이트)를 갖추고, csvstat.py CSV 통계 CLI로 실검증한다.

**아키텍처**: 3개 태스크, outputs disjoint → 전체 병렬 가능 (DAG-AWARE PARALLEL). T1=테스트 컨벤션 문서, T2=decomposing-ko HARD-GATE 업데이트, T3=csvstat TDD.

**기술 스택**: Python 3.6+, pytest, stdlib csv·sys·os·io 모듈

---

## 파일 구조

| 파일 | 변경 | 담당 AC |
|---|---|---|
| `templates/test-conventions-python.md` | CREATE | AC-6 |
| `skills/decomposing-ko/SKILL.md` | MODIFY (HARD-GATE + 체크리스트 L7 + 테스트 컨벤션 섹션) | AC-7 |
| `examples/scripts/csvstat.py` | CREATE (+exec-bit) | AC-1~4, AC-8 |
| `examples/tests/test_csvstat.py` | CREATE (no exec-bit) | AC-5, AC-9 |

---

### Task 1: test-conventions-python.md 생성

**AC 매핑**: AC-6
**파일**:
- 생성: `templates/test-conventions-python.md`

*(문서 태스크 — TDD RED/GREEN 대신 검증 명령으로 대체)*

- [ ] **Step 1: RED — 검증 명령 실행 (파일 없음 확인)**

```bash
ls templates/test-conventions-python.md
```
예상: `No such file or directory` (exit 1)

- [ ] **Step 2: GREEN — 파일 생성**

`templates/test-conventions-python.md` 전문:

```markdown
# Python 테스트 컨벤션 — specops-auto-ko

## 4항목 규약

| 항목 | 규칙 | 강도 |
|---|---|---|
| 위치 | `examples/tests/` (예시용) 또는 downstream 프로젝트 기존 test 디렉토리 우선 | 내부 예시 |
| 명명 | `test_<subject>.py` — underscore (Python 표준, hyphen 아님) | Universal 강제 |
| exec-bit | 불필요 — pytest가 직접 실행하므로 `chmod +x` 금지 아님이지만 불필요 | Universal 규약 |
| 헤더 | shebang 불필요 (pytest 직접 실행). `#!/usr/bin/env python3` 추가해도 무방 | Universal 규약 |

## 강도 해석

- **Universal 강제** — 위반 시 `<HARD-GATE>` 발동. `test_*.py` 명명 위반(예: `test-*.py`) 시 차단
- **Universal 규약** — exec-bit·shebang은 Python 테스트에서 불필요 (bash와 다름)
- **내부 예시** — downstream 프로젝트 기존 패턴이 있으면 그것 우선

## 테스트 실행 명령

```bash
pytest examples/tests/test_<subject>.py -v
```

## bash 컨벤션과의 차이점

| 항목 | bash (`test-*.sh`) | Python (`test_*.py`) |
|---|---|---|
| 명명 | hyphen (`test-name.sh`) | underscore (`test_name.py`) |
| exec-bit | **필수** (chmod +x) | **불필요** |
| shebang | **필수** (`#!/usr/bin/env bash`) | **불필요** |
| 실행 | `bash test-name.sh` | `pytest test_name.py` |

## 참조

- bash 컨벤션: `templates/test-conventions-bash.md`
- downstream 프로젝트에서 pytest 설정이 있으면 (`pyproject.toml`, `setup.cfg`) 그 설정 우선

*v0.1.0 · 2026-04-27 · specops-auto-ko*
```

- [ ] **Step 3: PASS 검증**

```bash
cat templates/test-conventions-python.md | grep -c "Universal 강제"
```
예상: `2` (명명 항목 + 강도 해석 항목)

```bash
grep -c "test_\*\.py" templates/test-conventions-python.md
```
예상: `1` 이상

- [ ] **Step 4: COMMIT**

```bash
git add templates/test-conventions-python.md
git commit -m "feat(python-support): test-conventions-python.md 추가 (AC-6)"
```

---

### Task 2: decomposing-ko HARD-GATE Python 분기 추가

**AC 매핑**: AC-7
**파일**:
- 수정: `skills/decomposing-ko/SKILL.md` (HARD-GATE 섹션, 체크리스트 item 7, 테스트 컨벤션 섹션)

*(문서 태스크 — TDD RED/GREEN 대신 검증 명령으로 대체)*

- [ ] **Step 1: RED — Python 관련 내용 없음 확인**

```bash
grep -c "test_\*\.py\|Python 테스트" skills/decomposing-ko/SKILL.md
```
예상: `0`

- [ ] **Step 2: GREEN — 3곳 수정**

**수정 1: HARD-GATE 섹션** — `templates/test-conventions-bash.md`.` 줄 바로 뒤에 추가:

현재 (line 21):
```
**bash 테스트 파일 규약**: 생성되는 `test-*.sh` 에 shebang (`#!/usr/bin/env bash`) 또는 실행권한 (exec-bit, `chmod +x`) 이 누락된 채로 `specops-auto-ko:implementing-ko` 호출 금지. 단, 파일 첫 두 줄 내에 `# library-only` 주석 마커가 존재하면 library-only 전용 (sourced only) 으로 간주하여 exec-bit 검증 skip. shebang 은 library-only 포함 모든 bash 테스트 파일에 필수. 상세: `templates/test-conventions-bash.md`.
```

추가 (위 줄 바로 뒤):
```
**Python 테스트 파일 규약**: 생성되는 `test_*.py` 에 exec-bit 및 shebang 불필요. pytest가 직접 실행. 파일명은 `test_<subject>.py` (underscore, hyphen 아님). 상세: `templates/test-conventions-python.md`.
```

**수정 2: 체크리스트 item 7** (line 44) 교체:

현재:
```
7. **테스트 컨벤션 점검 (bash)** — bash 테스트 생성 태스크가 있으면 `templates/test-conventions-bash.md` 4 항목 규약 준수 확인. exec-bit·shebang 누락 시 `<HARD-GATE>` 발동
```

교체 후:
```
7. **테스트 컨벤션 점검** — 테스트 생성 태스크가 있으면 언어별 컨벤션 준수 확인:
   - bash (`test-*.sh`): `templates/test-conventions-bash.md` 준수. exec-bit·shebang 누락 시 `<HARD-GATE>` 발동
   - Python (`test_*.py`): `templates/test-conventions-python.md` 준수. exec-bit·shebang 불필요. `test_<subject>.py` 명명 위반 시 `<HARD-GATE>` 발동
```

**수정 3: "테스트 컨벤션 (bash)" 섹션 제목 + Python 항목 추가** (line 73 부근):

현재 섹션 제목:
```
## 테스트 컨벤션 (bash)
```

교체 후 제목:
```
## 테스트 컨벤션
```

line 90 (`상세 규약·예시 코드블록·회귀 금지 체크리스트: `templates/test-conventions-bash.md`.`) 바로 뒤에 추가:

```
### Python 테스트 파일 (`test_*.py`)

plan.md 가 Python 테스트 파일 생성 태스크를 포함하는 경우, 다음 규약을 준수하도록 태스크를 설계한다. 상세는 `templates/test-conventions-python.md` 참조.

| 항목 | 규칙 | 강도 |
|---|---|---|
| 위치 | `examples/tests/` 또는 downstream 프로젝트 패턴 | 내부 예시 |
| 명명 | `test_<subject>.py` — underscore | Universal 강제 |
| exec-bit | 불필요 | Universal 규약 |
| 헤더 | shebang 불필요 | Universal 규약 |

**강도 해석**:
- **Universal 강제** — `test_*.py` 명명 위반 시 `<HARD-GATE>` 발동
- **Universal 규약** — exec-bit·shebang은 불필요 (bash와 다름)
- **내부 예시** — downstream 프로젝트 기존 패턴이 있으면 그것 우선

상세: `templates/test-conventions-python.md`.
```

- [ ] **Step 3: PASS 검증**

```bash
grep -c "test_\*\.py\|Python 테스트" skills/decomposing-ko/SKILL.md
```
예상: `3` 이상

```bash
grep -c "test-\*\.sh" skills/decomposing-ko/SKILL.md
```
예상: 기존 bash 규약 유지 (`1` 이상)

- [ ] **Step 4: COMMIT**

```bash
git add skills/decomposing-ko/SKILL.md
git commit -m "feat(python-support): decomposing-ko HARD-GATE Python 분기 추가 (AC-7)"
```

---

### Task 3: csvstat.py + test_csvstat.py (TDD)

**AC 매핑**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-9 (must), AC-8 (should)
**파일**:
- 생성: `examples/tests/test_csvstat.py` (먼저, no exec-bit)
- 생성: `examples/scripts/csvstat.py` (나중, exec-bit + shebang)

- [ ] **Step 1: RED — 실패 테스트 작성**

`examples/tests/test_csvstat.py` 전문 (exec-bit 없음, shebang 없음):

```python
import subprocess
import sys
import os
import tempfile

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "scripts", "csvstat.py")


def run(args=None, stdin=None):
    cmd = [sys.executable, SCRIPT]
    if args:
        cmd.extend(args)
    return subprocess.run(cmd, input=stdin, capture_output=True, text=True)


def make_csv(content):
    f = tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False)
    f.write(content)
    f.close()
    return f.name


def test_file_arg():
    """AC-1: file arg → rows/columns/unique counts"""
    path = make_csv("name,age\nAlice,30\nBob,30\n")
    try:
        p = run([path])
        assert p.returncode == 0
        assert "rows: 2" in p.stdout
        assert "columns: 2" in p.stdout
        assert "name: 2 unique" in p.stdout
        assert "age: 1 unique" in p.stdout
    finally:
        os.unlink(path)


def test_stdin():
    """AC-2: stdin → same output"""
    p = run(stdin="name,age\nAlice,30\nBob,30\n")
    assert p.returncode == 0
    assert "rows: 2" in p.stdout
    assert "columns: 2" in p.stdout
    assert "name: 2 unique" in p.stdout
    assert "age: 1 unique" in p.stdout


def test_missing_file():
    """AC-3: missing file → stderr + exit 1"""
    p = run(["nonexistent_csvstat_file_xyz.csv"])
    assert p.returncode == 1
    assert p.stdout == ""
    assert p.stderr != ""


def test_no_args_no_stdin():
    """AC-4: no args, stdin=/dev/null → usage + exit 1"""
    p = subprocess.run(
        [sys.executable, SCRIPT],
        stdin=open(os.devnull),
        capture_output=True,
        text=True,
    )
    assert p.returncode == 1
    assert p.stdout == ""
    assert p.stderr != ""


def test_empty_csv():
    """AC-9: header only, no data rows → rows: 0"""
    path = make_csv("name,age\n")
    try:
        p = run([path])
        assert p.returncode == 0
        assert "rows: 0" in p.stdout
        assert "columns: 2" in p.stdout
        assert "name: 0 unique" in p.stdout
        assert "age: 0 unique" in p.stdout
    finally:
        os.unlink(path)
```

- [ ] **Step 2: FAIL 검증**

```bash
pytest examples/tests/test_csvstat.py -v 2>&1 | tail -5
```
예상: `ModuleNotFoundError` 또는 `FileNotFoundError` (csvstat.py 없음)

- [ ] **Step 3: GREEN — csvstat.py 구현**

`examples/scripts/csvstat.py` 전문:

```python
#!/usr/bin/env python3
import csv
import io
import os
import sys


def usage():
    sys.stderr.write("Usage: csvstat.py [FILE]\n       cat FILE | csvstat.py\n")


def analyze(text_io):
    reader = csv.DictReader(text_io)
    headers = list(reader.fieldnames) if reader.fieldnames else []
    counts = {h: set() for h in headers}
    rows = 0
    for row in reader:
        for h in headers:
            counts[h].add(row.get(h, ""))
        rows += 1
    return rows, headers, counts


def print_stats(rows, headers, counts):
    print(f"rows: {rows}")
    print(f"columns: {len(headers)}")
    for h in headers:
        print(f"{h}: {len(counts[h])} unique")


def main():
    if len(sys.argv) > 1:
        path = sys.argv[1]
        if not os.path.exists(path):
            sys.stderr.write(f"Error: file not found: {path}\n")
            sys.exit(1)
        with open(path, newline="") as f:
            rows, headers, counts = analyze(f)
    elif not sys.stdin.isatty():
        content = sys.stdin.read()
        if not content.strip():
            usage()
            sys.exit(1)
        rows, headers, counts = analyze(io.StringIO(content))
    else:
        usage()
        sys.exit(1)
    print_stats(rows, headers, counts)


if __name__ == "__main__":
    main()
```

exec-bit 부여:
```bash
chmod +x examples/scripts/csvstat.py
```

- [ ] **Step 4: PASS 검증**

```bash
pytest examples/tests/test_csvstat.py -v
```
예상:
```
test_csvstat.py::test_file_arg PASSED
test_csvstat.py::test_stdin PASSED
test_csvstat.py::test_missing_file PASSED
test_csvstat.py::test_no_args_no_stdin PASSED
test_csvstat.py::test_empty_csv PASSED
5 passed
```

AC-8 추가 확인:
```bash
ls -la examples/scripts/csvstat.py && head -1 examples/scripts/csvstat.py
```
예상: `-rwxr-xr-x` + `#!/usr/bin/env python3`

- [ ] **Step 5: COMMIT**

```bash
git add examples/scripts/csvstat.py examples/tests/test_csvstat.py
git commit -m "feat(csvstat): CSV 통계 CLI + pytest 테스트 (7th dogfood)"
```

---

## AC → Task 매핑

| AC | must/should | Task(s) |
|---|---|---|
| AC-1 파일 인자 통계 출력 | must | Task 3 |
| AC-2 stdin 입력 지원 | must | Task 3 |
| AC-3 존재하지 않는 파일 | must | Task 3 |
| AC-4 인자·stdin 없음 → usage | must | Task 3 |
| AC-5 pytest PASS | must | Task 3 |
| AC-6 test-conventions-python.md | must | Task 1 |
| AC-7 decomposing-ko HARD-GATE Python 분기 | must | Task 2 |
| AC-8 exec-bit + shebang (csvstat.py) | should | Task 3 |
| AC-9 빈 CSV → rows: 0 | must | Task 3 |

**must AC 커버리지**: 8/8 (100%)
