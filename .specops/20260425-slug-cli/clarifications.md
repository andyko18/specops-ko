<!-- FID: 20260425-slug-cli -->
<!-- OWNER_COMMAND: /clarify -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260425-slug-cli

**status**: RESOLVED  
**timestamp**: 2026-04-25T00:00:00+09:00

---

## Q1 · 빈 입력 exit code · BLOCKING → RESOLVED

**질문**: 빈 입력(`""`, 공백만, 변환 결과 빈 문자열) 처리를 어떻게 할까요?

**답변**: 빈 문자열 출력 + exit 0 (오류 아님, 파이프라인 친화적)

**영향**: AC-8 신규 append

---

## D1 · 숫자만 있는 입력 · DESIRABLE → 가정 적용

**가정**: `"2024"` → `2024` 그대로 출력 + exit 0

**영향**: 별도 AC 추가 없음 (FR-3·FR-4 범위 내 자연스러운 동작)

---

## D2 · 인자·stdin 모두 없는 경우 · DESIRABLE → 가정 적용

**가정**: stdin blocking 대기 (UNIX 표준 — `cat`과 동일 동작)

**영향**: 별도 AC 추가 없음 (구현 상세)

---

## D3 · ㄹ 위치별 로마자 매핑 · DESIRABLE → 가정 적용

**가정**: 초성 `r`, 종성 `l` 구분 적용 (국립국어원 개정 로마자 표기법 표준)  
예: `달` → `dal`, `라면` → `ramyeon`

**영향**: 별도 AC 추가 없음 (구현 상세 — 매핑 테이블 내 결정)

---

*작성: clarifying-ko · 2026-04-25 · FID: 20260425-slug-cli*
