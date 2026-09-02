# tasks.md — no tasks key

> 헤더 부재 + `tasks:` 키가 **없는** yaml 펜스만 — 오탐 차단 대상 (AC-3).
> `meta.tasks` 는 **들여쓴** 줄이라 `^tasks:` 행두 앵커에 걸리지 않는다.
> 앵커를 느슨하게(`/tasks:/`) 바꾸면 이 블록이 후보가 되어 T1.d 가 깨진다 — 앵커 잠금.

## 설정 예시

```yaml
review_mode: end-loaded
notes:
  - id: N1
meta:
  tasks:
    - 참고용 중첩 키 (DAG 아님)
```
