# tasks.md — no-header fixture

> `## 의존 그래프` 헤더가 **없는** 하류 형태 (Argus 20260826-argus-chart 실물 모양).

## T1 작업

- [x] TDD 5 steps

## 진행: 1/1

```yaml
review_mode: end-loaded
tasks:
  - id: T1
    test_command: "bash scripts/tests/test-noheader.sh"
    depends_on: []
    ac: [AC-1]
```
