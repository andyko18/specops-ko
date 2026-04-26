# Dispatch Context: T4 (FID 20260427-screen-design)

## 1. 담당 AC

- AC-4 (must): `grep -c "screens/" skills/specifying-ko/SKILL.md` → 2회 이상 등장.

## 2. 관련 spec.md 섹션

- `.specops/20260427-screen-design/spec.md` §4 FR-4 (skills/specifying-ko/SKILL.md 체크리스트 §1 수정)
- `.specops/20260427-screen-design/acceptance-criteria.md` AC-4

## 3. 테스트 명령

```bash
grep -c "screens/" skills/specifying-ko/SKILL.md
# 기대: 2 이상
```

기대: 2 이상

## 4. 수정 허용 파일 (whitelist)

- `skills/specifying-ko/SKILL.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `/Users/mac/code/specops-auto-ko/.worktrees/20260427-screen-design-T4/`

---

## 구현 지시

`skills/specifying-ko/SKILL.md` 를 두 군데 수정하라. **Edit 도구 사용**:

### 수정 1: 체크리스트 §1 — DESIGN.md 감지 블록 바로 아래에 screens/ 감지 블록 추가

찾아야 할 기존 텍스트 (정확히 일치):
```
     → **없으면**: UI 컴포넌트 포함 기능이면 (HTML/CSS/React/Vue 등 시각 렌더링 포함) `/start-design` 실행 안내 (`DESIGN.md` 생성 후 재진입)
2. **Visual Companion 제안**
```

대체할 텍스트:
```
     → **없으면**: UI 컴포넌트 포함 기능이면 (HTML/CSS/React/Vue 등 시각 렌더링 포함) `/start-design` 실행 안내 (`DESIGN.md` 생성 후 재진입)
   - 프로젝트 루트 `screens/` 존재 확인 (`ls screens/ 2>/dev/null`)
     → **있으면**: 기존 화면 목록 표시 — "현재 N개 화면: {name1}, {name2} ..."
       UI 기능이면: 관련 화면을 `spec.md` §참조에 포함 + HTML artifact 생성 제안
     → **없으면**: UI 기능이면 `screens/` 생성 및 `/design-screen` 활용 안내
2. **Visual Companion 제안**
```

### 수정 2: 프로세스 흐름 다이어그램 — DESIGN.md 블록 아래에 screens/ 블록 추가

찾아야 할 기존 텍스트 (정확히 일치):
```
    └── no (UI 기능이면 /start-design 안내)
    ↓
시각 질문 예상?
```

대체할 텍스트:
```
    └── no (UI 기능이면 /start-design 안내)
    ↓
screens/ 존재? ── yes ──▶ 기존 화면 목록 표시 + UI 기능이면 HTML artifact 안내
    │
    └── no (UI 기능이면 screens/ 생성 안내)
    ↓
시각 질문 예상?
```

완료 후:
1. `grep -c "screens/" skills/specifying-ko/SKILL.md` 실행 → 2 이상 확인
2. `git add skills/specifying-ko/SKILL.md && git commit -m "feat(screen-design): specifying-ko §1 체크리스트에 screens/ 감지 스텝 추가"` 실행
