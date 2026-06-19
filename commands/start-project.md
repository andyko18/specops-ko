---
name: start-project
description: "[deprecated] /init-project 로 통합 — 구 이름 alias (1~2 릴리즈 후 제거)"
triggers:
  - "/start-project"
mode: ask
specops_version: 1.16.0
specops_layer: Lifecycle-Bootstrap
reference_upstream: specops-auto-ko 독자 추가
---

# /start-project (deprecated → /init-project)

> **이 슬래시는 `/init-project` 로 이름이 바뀌었습니다.** 동작은 동일하나 향후 제거됩니다 — `/init-project` 사용을 권장합니다.

## Process
`/init-project` 와 동일하게 `bash scripts/_internal/start-project.sh [--resume] "<프로젝트명>"` 을 호출해 한국 SI 표준 13종 산출물을 부트스트랩한다. 세부는 `commands/init-project.md` 참조.
