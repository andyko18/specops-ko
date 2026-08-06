# Tasks — must-uncovered (AC-R-1 이 어느 태스크에도 미매핑)

## 의존 그래프

```yaml
tasks:
  - id: T1
    test_command: "bash t1.sh"
    depends_on: []
    inputs: []
    outputs: [a.sh]
    ac: [AC-1]
```
