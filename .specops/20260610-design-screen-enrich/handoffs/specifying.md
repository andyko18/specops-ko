# Handoff — specifying → clarifying

## Decided
- design-rationale 섹션: 핵심 결정 요약 (style/color/font/anti-patterns 2-3개)
- anti-pattern 게이트: 위반 목록 + [m/s] 확인 (강제 차단 아님)
- ui-ux-pro-max 없으면 섹션 생략 + 게이트 skip (기존 경로 100% 보존)
- templates/screen.md에 Design Rationale placeholder 추가

## Rejected
- ui-ux-pro-max 산출 전체 섹션에 인용 (너무 길어짐)
- anti-pattern 자동 수정 후 재생성 (오버라이드 위험)
- 기존 screens/*.md 소급 갱신 (범위 외)

## Risks
- ui-ux-pro-max anti-patterns 필드 존재 가정 (SKILL.md description 기반 — 실제 필드명 동적)
- 없을 시 "항목 없음" 처리 분기 clarify에서 확인 필요

## Remaining
- 없음 — 열린 질문 해소 완료
