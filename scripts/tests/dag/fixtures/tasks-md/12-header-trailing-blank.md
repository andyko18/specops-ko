# tasks.md — 펜스 끝 빈 줄 보존 (AC-2 바이트 동일 · 변이 M7 격추용)

> yaml 펜스 **안** 마지막에 빈 줄 2개가 있다. 1단 awk 는 이를 그대로 출력하고,
> `X` sentinel 이 `$()` 의 trailing newline 삭제를 막아 바이트가 보존된다.
> tasks.md Step 3 처방 코드(`out=$(awk …); printf '%s\n' "$out"`)로 되돌리면
> 개행 3개가 1개로 줄어 골든 파일과 바이트가 달라진다.
> **펜스 안 마지막 빈 줄 2개를 지우지 말 것** — 이 fixture 의 전부다.

## 의존 그래프

```yaml
tasks:
  - id: T1
    depends_on: []


```
