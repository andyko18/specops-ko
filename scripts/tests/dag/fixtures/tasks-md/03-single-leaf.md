# Tasks — fixture 03: leaf 1개만 (병렬 후보 0)

## 의존 그래프

```mermaid
graph TD
  T1[T1: only task]
```

```yaml
tasks:
  - id: T1
    depends_on: []
    inputs: []
    outputs: [src/only.sh]
    ac: [AC-1]
```

기대: `find_independent_batch` → `[]` (leaf 1개 — 병렬 후보 2개+ 미충족).
