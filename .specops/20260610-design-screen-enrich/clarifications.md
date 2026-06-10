# Clarifications — 20260610-design-screen-enrich

**status**: RESOLVED
**timestamp**: 2026-06-09T23:33:34Z

## Q1 · templates/screen.md 섹션 처리 방식 · BLOCKING

**질문**: `templates/screen.md`에 `## Design Rationale` placeholder를 추가하면 `design-screen.sh`가 cp로 스캐폴딩 시 항상 포함됩니다. 그러나 FR-3/AC-3은 ui-ux-pro-max 없으면 섹션 **생략**을 요구해 충돌합니다. 어느 방식으로 구현할까요?

**선택지**:
1. 템플릿 없음 + 커맨드 Step 4에서 rationale 있으면 screen.md 끝에 동적 append
2. 템플릿에 placeholder 포함 + 미사용 시 섹션 내용을 "N/A"로 채움

**답변**: 1번 — 템플릿 없음 + 커맨드에서 동적 append

**영향**:
- `templates/screen.md` 변경 없음 (FR-6 무효화)
- AC-8 무효화 → `acceptance-criteria.md`에 AC-8-override append
- `commands/design-screen.md` Step 4: rationale 있으면 screen.md 끝에 섹션 append
- `commands/design-screens.md` Step 3-4: 동일 동적 append

**status**: RESOLVED

---

## Q2 · [m/s] 프롬프트 기본값 · DESIRABLE · ASSUMED

**질문**: anti-pattern 게이트에서 사용자가 Enter만 눌렀을 때 기본 동작은?

**답변 (자동)**: `s` (그냥 저장) — 위반을 인지한 상태에서 Enter를 누른다면 진행 의사로 해석.

**가정 근거**: [m] 재생성 루프는 명시적 선택이 더 자연스럽고, Enter 기본값을 `s`로 두면 실수 차단보다 사용자 주권 우선 (FR-8 §should, 원칙 4).

**영향**: 프롬프트 표기에 `[m/s, 기본=s]` 반영

**status**: ASSUMED
