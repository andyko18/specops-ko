<!-- reference: https://github.com/VoltAgent/awesome-design-md -->
<!-- layer: Project-Document -->

# DESIGN.md — [Project Name]

> AI 에이전트용 디자인 시스템 문서. UI 컴포넌트 생성 시 이 파일을 읽고 일관된 스타일을 유지한다.
> (awesome-design-md 포맷 기반 — https://getdesign.md/)

## 1. Color System

| Role | Value | Usage |
|---|---|---|
| Primary | `#______` | 주요 버튼, 링크, 강조 |
| Secondary | `#______` | 보조 액션, 배지 |
| Background | `#______` | 페이지 배경 |
| Surface | `#______` | 카드, 모달, 패널 |
| Text Primary | `#______` | 본문 텍스트 |
| Text Secondary | `#______` | 보조 텍스트, 레이블 |
| Border | `#______` | 그리드 라인, 카드 테두리 |
| Error | `#______` | 에러 상태 |
| Success | (자산 미제공 — shadcn 규약엔 success 토큰 없음) | 성공 상태 |
| Accent | `#______` | 강조 액션, 배지 |
| Muted | `#______` | 비활성 배경 |
| Ring | `#______` | 포커스 링 |
| On Primary | `#______` | Primary 위 텍스트 |
| On Secondary | `#______` | Secondary 위 텍스트 |
| On Accent | `#______` | Accent 위 텍스트 |
| Card Foreground | `#______` | 카드 내 텍스트 |
| On Destructive | `#______` | Error 위 텍스트 |

**Gradient**: (자산 미제공 — 색상 데이터셋에 gradient 컬럼 없음. Phase 11 enrich 또는 수기)

**Dark Mode**: [다크 모드 색상 변형 또는 "Not applicable"]

## 2. Typography

| Role | Font | Size | Weight | Usage |
|---|---|---|---|---|
| Heading 1 | [font], system-ui | 2rem | 700 | 페이지 제목 |
| Heading 2 | [font], system-ui | 1.5rem | 600 | 섹션 제목 |
| Body | [font], system-ui | 1rem | 400 | 본문 |
| Caption | [font], system-ui | 0.875rem | 400 | 보조 텍스트 |
| Code | [monospace] | 0.875rem | 400 | 코드 블록 |

**Font Stack**: `[primary], -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`

## 3. Spacing & Layout

- **Base Unit**: `[N]px` (예: 4px 또는 8px)
- **Spacing Scale**: `4, 8, 12, 16, 24, 32, 48, 64px`
- **Max Content Width**: `[N]px`
- **Grid**: `12-column, [N]px gutter`
- **Border Radius**: `[N]px` (default), `[N]px` (large), `9999px` (pill)

## 4. Components

> DESIGN.md 생성 시: 아래 코드 블록의 `[placeholder]` 값을 §1·§2·§3 실제 값으로 치환한다.

### Button

```
Primary:   bg=[primary], text=white, radius=[N]px, padding=[N]px [N]px
Secondary: bg=transparent, border=1px solid [primary], text=[primary]
Disabled:  opacity=0.5, cursor=not-allowed
```

### Input

```
Border:     1px solid [border-color]
Focus:      border=[primary], ring=[primary]/20
Error:      border=[error]
Radius:     [N]px
Background: [surface]
```

### Card

```
Background: [surface]
Border:     1px solid [border-color]
Radius:     [N]px
Shadow:     [shadow-definition]
Padding:    [N]px
```

## 5. Motion

| 상황 | 지속 | 이징 | 비고 |
|---|---|---|---|
| Hover Micro-interaction | [ms] | [easing] | [설명] |
| Scroll Reveal | [ms] | [easing] | [설명] |
| Stagger List | [ms] | [easing] | [설명] |

> 값 채움은 **후속 FID** 로 이관 — 자산(motion.csv) 연결은 본 어댑터 범위 밖이다.

## 6. 레이아웃 패턴

- **권장 패턴**: [Recommended_Pattern]
- **스타일 우선순위**: [Style_Priority]
- **핵심 효과**: [Key_Effects]

## 7. 상태 표현

| 상태 | 표현 | 비고 |
|---|---|---|
| 로딩 | [스켈레톤/스피너/프로그레스] | |
| 빈 상태 | [일러스트/문구/CTA] | |
| 에러 | [인라인/토스트/전체] | |

> 값 채움은 **후속 FID** 로 이관 — Phase 11 enrich 또는 수기.

## 8. Design Principles

1. **[원칙 1]**: [설명]
2. **[원칙 2]**: [설명]
3. **[원칙 3]**: [설명]

**Anti-patterns** (피해야 할 것):
- [금지 패턴 1]
- [금지 패턴 2]

## 9. AI Usage Guidelines

> 이 섹션을 AI 에이전트가 직접 읽어 일관된 UI를 생성한다.

**컬러 사용**:
- Primary 색상은 CTA(Call-to-Action) 요소에만 사용. 배경 전체에 남용 금지.
- [추가 컬러 지침]

**타이포그래피**:
- Heading은 최대 2단계(H1, H2)만 사용.
- [추가 타이포 지침]

**컴포넌트 생성 시**:
- 항상 §4 Components 스펙 참조. 커스텀 스타일 추가 전 기존 variant 확인.
- [프레임워크별 지침 — 예: "Tailwind 사용 시 CSS 변수 우선"]
