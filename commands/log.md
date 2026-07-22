---
name: log
description: 자유작업 인사이트 즉석 수동 기록 — gbrain-append 재사용
triggers:
  - "/log"
mode: auto
specops_version: 1.31.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-ko 독자 추가
---

# /log "<요약>"

사용자가 자연어로 처리한 작업을 즉시 learnings 에 기록한다.

실행:
```bash
bash "${CLAUDE_PLUGIN_ROOT}"/scripts/gbrain-append.sh "$ARGUMENTS" --tags freelog,manual
```
기록 후 "기록함: <요약>" 1줄 보고.

---

*specops-ko v1.31.0 · 2026-06-25 · /log command*
