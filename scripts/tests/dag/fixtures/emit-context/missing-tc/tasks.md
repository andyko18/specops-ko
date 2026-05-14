# Tasks — fixture missing-tc (emit-context.sh fail-fast 케이스)

T1 의 test_command 필드 누락. T2, T3 정상.

## 의존 그래프

```mermaid
graph TD
  T1[T1: bad]
  T2[T2: ok]
  T3[T3: ok]
```

```yaml
tasks:
  - id: T1
    depends_on: []
    inputs: [src/foo.sh]
    outputs: [src/foo.sh, scripts/tests/test-foo.sh]
    ac: [AC-1]
  - id: T2
    depends_on: []
    inputs: [src/bar.sh]
    outputs: [src/bar.sh, scripts/tests/test-bar.sh]
    ac: [AC-2]
    test_command: "bash scripts/tests/test-bar.sh"
  - id: T3
    depends_on: []
    inputs: [src/baz.sh]
    outputs: [src/baz.sh, scripts/tests/test-baz.sh]
    ac: [AC-3]
    test_command: "bash scripts/tests/test-baz.sh"
```
