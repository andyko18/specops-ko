# Tasks — fixture 02: 두 leaf 인데 같은 src 파일 수정 (overlap)

## 의존 그래프

```mermaid
graph TD
  T1[T1: feature A]
  T2[T2: feature B]
```

```yaml
tasks:
  - id: T1
    depends_on: []
    inputs: []
    outputs: [src/shared.sh, scripts/tests/test-feature-a.sh]
    ac: [AC-1]
  - id: T2
    depends_on: []
    inputs: []
    outputs: [src/shared.sh, scripts/tests/test-feature-b.sh]
    ac: [AC-2]
```

기대: `find_independent_batch` → `[]` (T1·T2 outputs 공유 — `src/shared.sh`).
