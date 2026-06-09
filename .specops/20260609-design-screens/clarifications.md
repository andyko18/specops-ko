<!-- FID: 20260609-design-screens -->
<!-- OWNER_COMMAND: /clarify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260609-design-screens

**status**: RESOLVED
**timestamp**: 2026-06-09T06:28:48Z

---

## Q1 · commit-mode · DESIRABLE

**질문**: 화면별 commit 기본값 외에, 전체 batch 완료 후 단일 commit 으로 묶는 옵션이 필요한가요?

**답변**: 화면별 commit만 (기본)

**영향**: AC 추가 없음. spec §4 FR-5·AC-4 의 화면별 commit 기본값 유지.

---

## Q2 · fallback-screen-list · DESIRABLE

**질문**: 기능 설명이 너무 짧거나 화면 판단이 어려울 때 fallback 방식을 어떻게 할까요?

**답변**: 최소 예시 목록 제안 후 편집

**영향**: AC-8 신규 append — 기능 설명 부족 시 최소 예시 목록(목록·상세·입력폼 등 일반 화면)을 먼저 제안하고 편집 게이트로 진행한다.
