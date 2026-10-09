# Tasks — empty-ac

## 의존 그래프

```yaml
tasks:
  - id: T1
    test_command: "bash t1.sh"
    depends_on: []
    inputs: []
    outputs: [a.sh]
    ac: [AC-1]
  - id: T2
    test_command: "bash t2.sh"
    depends_on: []
    inputs: []
    outputs: [b.sh]
    ac: []
```
