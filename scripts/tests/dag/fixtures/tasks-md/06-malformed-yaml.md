# Tasks — fixture 06: malformed YAML (파서 fallback 검증)

## 의존 그래프

```mermaid
graph TD
  T1[T1: feature]
```

```yaml
tasks:
  - id: T1
    depends_on: []
    inputs: [
    outputs: [src/feature.sh
    ac: [AC-1]
```

기대: YAML 파싱 실패 → fallback (순차 + WARN). `find_independent_batch` → `[]` + stderr WARN 메시지.
