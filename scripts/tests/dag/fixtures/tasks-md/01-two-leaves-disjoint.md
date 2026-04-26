# Tasks — fixture 01: 두 독립 leaf, outputs disjoint

## 의존 그래프

```mermaid
graph TD
  T1[T1: parser]
  T2[T2: writer]
```

```yaml
tasks:
  - id: T1
    depends_on: []
    inputs: []
    outputs: [src/parser.sh, scripts/tests/test-parser.sh]
    ac: [AC-1]
  - id: T2
    depends_on: []
    inputs: []
    outputs: [src/writer.sh, scripts/tests/test-writer.sh]
    ac: [AC-2]
```

기대: `find_independent_batch` → `[T1, T2]` (둘 다 leaf, outputs disjoint).
