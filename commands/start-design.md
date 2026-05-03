---
name: start-design
description: 프로젝트 루트에 DESIGN.md(awesome-design-md 포맷) 생성 — 프로젝트 최초 1회 실행
triggers:
  - "/start-design"
mode: ask
specops_version: 0.0.0
specops_layer: Lifecycle-Tool
reference_upstream: VoltAgent/awesome-design-md@main DESIGN.md
---

# /start-design

## 목적

프로젝트 루트에 `DESIGN.md`를 생성한다. awesome-design-md 포맷 기반. **프로젝트당 1회**. 이후 specifying-ko가 DESIGN.md를 자동 감지해 spec.md §참조에 포함한다.

## Process

### Step 1: 기존 DESIGN.md 확인

프로젝트 루트에 `DESIGN.md`가 존재하는지 확인:

```bash
ls DESIGN.md
```

- **존재하면**: 사용자에게 확인 요청:
  > "이미 `DESIGN.md`가 존재합니다. 덮어쓸까요? [y/n]"
  - `n` → 중단. "기존 DESIGN.md를 유지합니다."
  - `y` → Step 2 진행

- **없으면**: Step 2 바로 진행

### Step 2: 브랜드 선택

다음 질문을 제시:

> "어떤 디자인 시스템을 참고할까요?
>
> **(1) Stripe** — 단순·보라 그라디언트·개발자 친화 ← 추천
> **(2) Notion** — 미니멀·중립·화이트 베이스
> **(3) Linear** — 기술적·다크모드·선명한 인디고
> **(4) Claude** — AI 친화·보라 계열·다크 퍼스트
> **(5) 직접 입력** — 브랜드명 또는 색상/폰트 직접 명시"

### Step 3: DESIGN.md 생성

선택된 브랜드 스타일을 `templates/DESIGN.md` 기반으로 채워 프로젝트 루트 `DESIGN.md`를 생성한다.

**브랜드별 핵심 스타일 레퍼런스**:

| 브랜드 | Primary | Font | 무드 |
|---|---|---|---|
| Stripe | `#635BFF` | Sohne (fallback: system-ui) | 보라 그라디언트, weight-300 우아함 |
| Notion | `#000000` | Inter | 미니멀, 화이트 기반 |
| Linear | `#5E6AD2` | Inter | 다크, 선명한 인디고 |
| Claude | `#7C3AED` | Inter | 다크 퍼스트, AI-native |

**(5) 직접 입력 시**: 사용자에게 Primary 색상(`#RRGGBB`), 폰트명, 전반적 무드(라이트/다크/중립)를 추가 확인 후 템플릿 채움.

### Step 4: git commit

```bash
git add DESIGN.md
git commit -m "feat(design): DESIGN.md 초기 생성 ([브랜드] 스타일)"
```

## 사용 예

**기본 흐름**:
```
/start-design
→ "어떤 디자인 시스템을 참고할까요?"
→ 사용자: "1"  (Stripe)
→ Stripe 스타일 DESIGN.md 생성
→ git commit
→ 완료
```

**UI 기능 specifying 중 DESIGN.md 없음 → 재진입**:
```
/start 대시보드 UI 만들어줘
→ specifying-ko: "DESIGN.md 없음 — UI 컴포넌트 포함 기능이므로 /start-design 먼저 실행하세요."
/start-design
→ DESIGN.md 생성 완료 (git commit)
/start 대시보드 UI 만들어줘  ← specifying-ko 재진입, DESIGN.md 자동 감지
```

## 참조

- `templates/DESIGN.md` — 생성 기반 템플릿
- `skills/specifying-ko/SKILL.md` — DESIGN.md 자동 감지
- https://github.com/VoltAgent/awesome-design-md — 브랜드 레퍼런스 원본

---

*specops-auto-ko · 2026-04-26 · FID: 20260427-design-md*
