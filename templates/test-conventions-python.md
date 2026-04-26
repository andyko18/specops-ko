# Python 테스트 컨벤션 — specops-auto-ko

## 4항목 규약

| 항목 | 규칙 | 강도 |
|---|---|---|
| 위치 | `examples/tests/` (예시용) 또는 downstream 프로젝트 기존 test 디렉토리 우선 | 내부 예시 |
| 명명 | `test_<subject>.py` — underscore (Python 표준, hyphen 아님) | Universal 강제 |
| exec-bit | 불필요 — pytest가 직접 실행 | Universal 규약 |
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
