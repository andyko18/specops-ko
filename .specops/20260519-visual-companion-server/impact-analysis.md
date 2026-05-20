<!-- FID: 20260519-visual-companion-server -->
<!-- OWNER_COMMAND: /maintain -->
<!-- layer: Lifecycle-Artifact -->

# 영향 분석 (Impact Analysis) — 20260519-visual-companion-server

## §1. 외부 영향

- `skills/specifying-ko/SKILL.md` §Visual Companion (lines 309-326) 수정 → specifying-ko chain 영향 없음 (독립 가이드 섹션, HARD GATE·로직 섹션 아님)
- 신규 `skills/brainstorming-ko/scripts/` 5개 파일 → validate-structure.sh `skills/*/SKILL.md` glob 카운트 무영향
- API/DB 변경: 해당 없음

## §2. 마이그레이션·롤백

- 롤백 가능: `git revert` — 신규 파일 삭제 + specifying-ko 원복
- 마이그레이션 불필요: 기존 사용자 데이터 없음
- Node.js 런타임 의존 신규 추가 (server.cjs `ws` 패키지) — 선택적 기능이라 미설치 시 텍스트 전용 모드 유지 가능

## §3. 관련 PR·이슈 히스토리

> 데이터 출처: gh CLI (available)

```
gh pr list --search "visual companion" --state merged --limit 5:
No Pull Requests

gh pr list --search "brainstorm" --state merged --limit 5:
```

관련 커밋 히스토리 (`git log --grep`):
- `aab409b` feat(brainstorming): gstack office-hours 한국어 재창작 — /brainstorming 슬래시 추가
- `fffad82` feat(specifying-ko): brainstorming-*.md PRD-first 합성 패턴 추가 (v2.2)
- `e4a0946` fix(specifying-ko): brainstorming-ko 스키마 불일치 교정

Visual Companion 포팅 자체는 별도 PR 없음 — 본 FID가 최초 구현.

---

*작성: analyzing-ko · 2026-05-19 · FID: 20260519-visual-companion-server*
