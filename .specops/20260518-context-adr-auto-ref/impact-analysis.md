<!-- FID: 20260518-context-adr-auto-ref -->
<!-- OWNER_COMMAND: /maintain -->
<!-- layer: Lifecycle-Artifact -->

# 영향 분석 (Impact Analysis) — 20260518-context-adr-auto-ref

## 1. 외부 영향

**공유 모듈 사용처**:
- specifying-ko Step 1 수정 → `/start` + `/maintain` 진입 모든 FID에 영향 (스킬 본문 변경이므로 즉시 적용)
- planning-ko §참조 수정 → `/plan` 단계 모든 FID에 영향

**API/DB 변경**: 해당 없음 — 순수 SKILL.md 텍스트 지시 변경

**외부 연동**: 해당 없음

## 2. 마이그레이션·롤백

- 롤백: `git revert <commit-sha>` 으로 즉시 원복 가능
- 마이그레이션 불필요: SKILL.md 변경은 새 FID부터 즉시 적용, 기존 진행 중 FID는 이미 spec/plan 완료 상태이므로 영향 없음
- 하위 호환: CONTEXT.md/ADR 부재 시 graceful skip 패턴 적용 → 기존 프로젝트 회귀 없음

## 3. 관련 PR·이슈 히스토리

```
관련 PR (gh CLI):
```
<br>

```bash
gh pr list --search "memory specifying" --state merged --limit 5
```

결과:
- #7 feat(specifying-ko): v2.0 .specops/memory/* 9종 자동 감지 추가 (merged)
- #5 feat(start-project): /start-project 부트스트랩 + .specops/memory 산출 (merged)

관련 git log:
```
git log --oneline --grep="memory\|specifying" -n 5
```
(gh CLI 가용 환경)

---

*작성: analyzing-ko · 2026-05-18 · FID: 20260518-context-adr-auto-ref*
