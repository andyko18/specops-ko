# tasks.md — 헤더 **앞**에도 tasks: 펜스가 있다 (AC-2 잠금 · 변이 M6 격추용)

> 1단(`## 의존 그래프` awk)이 살아 있으면 헤더 섹션 블록(`id: HEADER`)이 채택된다.
> 1단을 무력화하면 2단이 문서 **첫** `tasks:` 펜스(`id: EARLY`)를 집는다 —
> 그 순간 AC-2(헤더 우선)가 깨진다. 아래 두 블록의 순서를 바꾸지 말 것.

## 참고 — 헤더 앞 예시 블록

```yaml
tasks:
  - id: EARLY
    depends_on: []
```

## 의존 그래프

```yaml
tasks:
  - id: HEADER
    depends_on: []
    outputs: [src/header.sh]
    ac: [AC-2]
```
