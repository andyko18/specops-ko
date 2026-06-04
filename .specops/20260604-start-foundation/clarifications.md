<!-- FID: 20260604-start-foundation -->
<!-- OWNER_COMMAND: /clarify -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260604-start-foundation

**status**: RESOLVED
**timestamp**: 2026-06-04T07:54:07Z

## Q1 · foundation-manifest 미존재 graceful skip · DESIRABLE

**질문**: `foundation-manifest.md` 가 없는 프로젝트(foundation 미실행)에서 기능 task decomposing 시 HARD GATE 가 발동하는가?

**답변**: spec FR-5 / AC-5 의 조건이 이미 "foundation-manifest.md 가 존재하면" 으로 한정돼 있으므로 미존재 시 HARD GATE 는 발동하지 않는다. 별도 AC 추가 불필요 — spec 표현으로 자명하게 해소.

**영향**: 신규 AC 없음. AC-5 Given 조건 표현이 충분히 명시적임을 확인.
