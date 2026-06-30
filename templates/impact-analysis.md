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
- **롤백 (코드)**: <`git revert` 로 코드 원복 가능한가?>
- **롤백 (데이터)**: <코드 롤백 ≠ 데이터 롤백. 스키마 변경 시 `git revert` 로 데이터 복원 **불가** — reverse 마이그레이션(data-down) 필요 여부 + 가역성. `ALTER DROP` 류는 down 으로도 복구 불가임을 명시>
- **데이터 보존 전략**: <파괴적 변경 시 backup / shadow 컬럼 / soft-delete 등 보존 방법>
- **expand-contract 적용**: <파괴적 스키마 변경이면 ① 신컬럼 추가+backfill → ② 코드 전환 → ③ 구컬럼 제거를 별도 릴리즈로 분리(즉시 drop 금지). 적용 단계 기술>
- **점진 배포 가능 여부**: <feature flag / canary / blue-green 적용성>

## 3. 관련 PR·이슈 히스토리 요약

- **데이터 출처**: gh CLI 또는 git log (gh CLI 미가용 시 한계 고백 — clarify Q-C 결정)
- **관련 PR**: <gh pr list 또는 git log --merges --grep='Merge pull' 결과 요약 (최근 5 건)>
- **관련 이슈**: <gh issue list 결과 요약 — gh 미가용 시 "git log 만 사용 — 이슈 추적 미수행" 명시>

---

*작성: analyzing-ko (Phase C) · <날짜> · FID: <FID>*
