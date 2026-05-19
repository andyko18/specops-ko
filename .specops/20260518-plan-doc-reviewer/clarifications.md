<!-- FID: 20260518-plan-doc-reviewer -->
<!-- OWNER_COMMAND: /clarify -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260518-plan-doc-reviewer

**status**: RESOLVED
**timestamp**: 2026-05-18T00:00:00+09:00

## Q1 · ISSUES FOUND 처리 심각도 기준 · DESIRABLE

**질문**: 서브에이전트가 `ISSUES FOUND`를 반환할 때 심각한 갭(플랜이 스펙과 근본적으로 불일치)이면 BLOCK하고 사용자에게 알릴지, 아니면 항상 이슈를 반영 후 자동 진행할지?

**답변**: obra 패턴 준용 — "Approve unless serious gaps". 심각하지 않으면 planning-ko가 이슈를 plan.md에 반영 후 자동 진행. 심각한 갭(스펙 커버리지 누락·전면 재설계 필요)이면 SKILL.md 지시로 "사용자 알림 후 수정 확인" 처리.

**영향**: AC 신규 추가 불필요 — spec FR-4에 "이슈 반영 후 진행"이 이미 반영됨. SKILL.md 구현 시 심각도 분기 텍스트를 인라인 명시.

---

*작성: andyko · 2026-05-18 · FID: 20260518-plan-doc-reviewer · 생성 커맨드: /clarify*
