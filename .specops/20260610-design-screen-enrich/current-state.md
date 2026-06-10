# current-state.md — 20260610-design-screen-enrich

## §1 변경 대상 식별

| 파일 | 라인 수 | 변경 진입점 |
|---|---|---|
| `commands/design-screen.md` | 109 | Step 2.5 (L43-48), Step 4 (L61-67) |
| `commands/design-screens.md` | 94 | Step 2 (L35-39), Step 3-3·Step 3-4 (L64-71) |
| `templates/screen.md` | 37 | `## Interactions` 이하 (L35-) |

**라인 범위 합산: 240줄 → 유지보수**

---

## §2 호출자 / 의존 매핑

**호출자 (커맨드 파일을 참조하는 곳):**
- `commands/design-screens.md` → 내부적으로 `/design-screen` 루프 재사용 명시 (L12, L43)
- `scripts/_internal/design-screen.sh` → 스캐폴딩 백엔드, 커맨드 md를 직접 참조하지 않음 (독립 실행)
- `scripts/tests/test-design-screen.sh` → `design-screen.sh`만 테스트, 커맨드 md 참조 없음

**의존 (커맨드 파일이 호출·참조하는 것):**
- `scripts/_internal/design-screen.sh` — Step 1 / Step 3-1 스캐폴딩
- `templates/screen.md` — 화면 스펙 구조 (Step 4 저장 포맷)
- `templates/screen.html` — HTML 미리보기 템플릿
- `ui-ux-pro-max:ui-ux-pro-max` — Step 2.5 / Step 2 (available-skills 조건부)
- `.specops/memory/screens-overview.md` — overview 표

> 한계: `ui-ux-pro-max` 실제 산출 구조(반환 객체 필드명)는 동적 — 정적 분석 불가. 커맨드 md가 "style/colors/typography/effects + anti-patterns"로 명세하나 실제 필드 검증 불가.

---

## §3 기존 테스트 커버리지

```
scripts/tests/test-design-screen.sh  — PASS=12 FAIL=0
```

테스트 대상: `design-screen.sh` 스크립트 (스캐폴딩·color 추출·overview 갱신·guard 등)
**커맨드 md 자체(Claude 지시 흐름)는 테스트 파일 없음.** 회귀 AC 추가 권고.

---

## §4 관찰 가능 동작 (Baseline)

> ⚠️ 직접 실행 불가 — 커맨드 md는 Claude 인터프리터가 해석하는 지시 문서. 아래는 관련 테스트/문서 기반 baseline.

| 케이스 | 현재 동작 |
|---|---|
| `/design-screen foo` Step 2.5 ui-ux-pro-max 있음 | design system 자문 → HTML `<main>` 마크업에 반영. screen.md에는 반영 기록 없음 |
| `/design-screen foo` Step 2.5 ui-ux-pro-max 없음 | skip → DESIGN.md fallback |
| `/design-screen foo` Step 4 저장 | `screen.md` + `screen.html` 저장. anti-pattern 체크 없음 |
| `/design-screens "기능설명"` Step 2 | 첫 화면 전 1회 자문 → 전 화면 공유. screen.md에 반영 기록 없음 |
| `/design-screens "기능설명"` Step 3-4 저장 | 단수 Step 4와 동일. anti-pattern 체크 없음 |

---

## §5 회귀 위험 메모

- `design-screen.md` Step 4 수정 → `design-screens.md` Step 3-4 동일 흐름에 반드시 동기 적용 필요 (단수·복수 일관성)
- `templates/screen.md`에 `design-rationale` 섹션 추가 → `design-screen.sh`가 스캐폴딩 시 템플릿 복사하는지 확인 필요 (현재: `cp templates/screen.md screens/{name}.md`)
- anti-pattern 게이트 추가 시 "없으면 skip" 분기 명확히 해야 함 (ui-ux-pro-max 미호출 경로에서 게이트 막힘 방지)
