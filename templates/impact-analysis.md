<!-- FID: <YYYYMMDD-kebab-slug> -->
<!-- OWNER_COMMAND: /maintain (analyzing-ko) -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 (본가 obra/superpowers@v5.0.7 미존재) -->
<!-- layer: Lifecycle-Artifact -->

# 영향 분석 (Impact Analysis) — <FID>

> 유지보수 진입 시 analyzing-ko (Phase C) 가 산출. 변경의 외부 파급·롤백·맥락을 캡처하여 spec.md §6 제약사항 / 회귀 AC 의 근거.

## 1. 외부 영향

- **API 호환성**: <외부 API 변경 여부 — deprecate / breaking / 무영향>
- **DB 스키마**: <스키마 변경 여부 + 마이그레이션 필요 여부>
- **공유 모듈 사용처**: <변경 모듈을 import 하는 다른 모듈 grep 결과 요약>

## 2. 마이그레이션·롤백 경로

- **마이그레이션**: <데이터·설정 이전 필요 여부 + 절차>
- **롤백**: <문제 발생 시 이전 상태 복원 가능한가? 단방향이면 한계 고백>
- **점진 배포 가능 여부**: <feature flag / canary / blue-green 적용성>

## 3. 관련 PR·이슈 히스토리 요약

- **데이터 출처**: gh CLI 또는 git log (gh CLI 미가용 시 한계 고백 — clarify Q-C 결정)
- **관련 PR**: <gh pr list 또는 git log --merges --grep='Merge pull' 결과 요약 (최근 5 건)>
- **관련 이슈**: <gh issue list 결과 요약 — gh 미가용 시 "git log 만 사용 — 이슈 추적 미수행" 명시>

---

*작성: analyzing-ko (Phase C) · <날짜> · FID: <FID>*
