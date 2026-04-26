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
    """AC-1: file arg -> rows/columns/unique counts"""
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
    """AC-2: stdin -> same output"""
    p = run(stdin="name,age\nAlice,30\nBob,30\n")
    assert p.returncode == 0
    assert "rows: 2" in p.stdout
    assert "columns: 2" in p.stdout
    assert "name: 2 unique" in p.stdout
    assert "age: 1 unique" in p.stdout


def test_missing_file():
    """AC-3: missing file -> stderr + exit 1"""
    p = run(["nonexistent_csvstat_file_xyz.csv"])
    assert p.returncode == 1
    assert p.stdout == ""
    assert p.stderr != ""


def test_no_args_no_stdin():
    """AC-4: no args, stdin=/dev/null -> usage + exit 1"""
    with open(os.devnull) as devnull:
        p = subprocess.run(
            [sys.executable, SCRIPT],
            stdin=devnull,
            capture_output=True,
            text=True,
        )
    assert p.returncode == 1
    assert p.stdout == ""
    assert p.stderr != ""


def test_empty_csv():
    """AC-9: header only, no data rows -> rows: 0"""
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
