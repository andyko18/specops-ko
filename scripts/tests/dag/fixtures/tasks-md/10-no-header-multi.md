# tasks.md — multi candidate

> 헤더 부재 + `tasks:` 키 펜스 2개 — 첫 번째 채택 + stderr WARN (AC-4).

## 첫 블록

```yaml
tasks:
  - id: FIRST
    depends_on: []
```

## 둘째 블록

```yaml
tasks:
  - id: SECOND
    depends_on: []
```
