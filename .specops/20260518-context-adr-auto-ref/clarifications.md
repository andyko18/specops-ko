<!-- FID: 20260518-context-adr-auto-ref -->
<!-- OWNER_COMMAND: /clarify -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260518-context-adr-auto-ref

**status**: RESOLVED
**timestamp**: 2026-05-18T00:00:00+09:00

## Q1 · ADR 인용 방식 · DESIRABLE

**질문**: spec FR-2의 "ADR 파일 목록 인용" 방식 — 파일 개수만 표시할지, 파일명을 나열할지?

**가정**: (a) 개수만 표시 — `"아키텍처 결정 기록 — docs/adr/ (N건)"`. 파일명 나열은 ADR이 많을 때 spec.md §참조가 길어져 가독성 저하. 개수 표시가 "이 디렉토리에 ADR 있음"을 충분히 전달. 파일명 상세가 필요하면 사용자가 직접 열람.

**답변**: 가정 (a) 채택 — 개수만 표시. YAGNI.

**영향**: AC 신규 추가 없음 — spec §4 FR-2에 `(N건)` 포맷으로 이미 명시됨.

---

*작성: clarifying-ko · 2026-05-18 · FID: 20260518-context-adr-auto-ref · 생성 커맨드: /clarify*
