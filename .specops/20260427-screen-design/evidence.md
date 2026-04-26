# Evidence — 20260427-screen-design

**검증 일시**: 2026-04-27
**브랜치**: feat/20260427-screen-design
**검증자**: verifying-evidence-ko

---

## AC-1 (must): commands/design-screen.md 존재 + /design-screen 트리거

```
$ ls commands/design-screen.md
commands/design-screen.md  ← exit 0

$ grep "design-screen" commands/design-screen.md | head -3
name: design-screen
  - "/design-screen"
# /design-screen
... (5 matches total)
```

**판정**: PASS

---

## AC-2 (must): templates/screen.md — 4섹션 이상 + frontmatter

```
$ ls templates/screen.md
templates/screen.md  ← exit 0

$ grep -c "^## " templates/screen.md
5

$ grep "screen:" templates/screen.md
screen: {{name}}
```

섹션 목록: 목적(L16), Layout(L20), Components(L26), States(L32), Interactions(L39)

**판정**: PASS (섹션 5 ≥ 4, screen: frontmatter 존재)

---

## AC-3 (must): templates/screen.html — CSS 변수 var(--color 1개 이상

```
$ ls templates/screen.html
templates/screen.html  ← exit 0

$ grep -c "var(--color" templates/screen.html
16
```

포함 변수: --color-bg, --color-text, --color-primary, --color-surface, --color-border, --color-text-secondary, --color-error, --color-secondary

**판정**: PASS (16 ≥ 1)

---

## AC-4 (must): specifying-ko/SKILL.md — screens/ 2회 이상

```
$ grep -c "screens/" skills/specifying-ko/SKILL.md
5
```

등장 위치:
- L32: `screens/` 존재 확인 (`ls screens/ 2>/dev/null`)
- L35: 무시 (screens/ 존재만 확인)
- L36: `screens/` 생성 및 `/design-screen` 활용 안내
- L56: screens/ 존재? ── yes ──▶ ...
- L58: └── no (UI 기능이면 screens/ 생성 안내)

**판정**: PASS (5 ≥ 2)

---

## AC-5 (should): /design-screen 덮어쓰기 방지

```
$ grep -c "덮어" commands/design-screen.md
3
```

등장: "덮어쓸까요? [y/n]" (2회), "덮어쓰기" (1회)

**판정**: PASS (3 ≥ 1)

---

## AC-6 (should): screens/login.md + screens/login.html dogfood

```
$ ls screens/login.md && ls screens/login.html
screens/login.md
screens/login.html  ← 두 파일 모두 exit 0

$ grep -c "^## " screens/login.md
5

$ grep -c "var(--color" screens/login.html
14
```

**판정**: PASS (두 파일 존재, 섹션 5 ≥ 4, var(--color 14 ≥ 1)

---

## 종합

| AC | 강도 | 판정 |
|---|---|---|
| AC-1 | must | ✅ PASS |
| AC-2 | must | ✅ PASS |
| AC-3 | must | ✅ PASS |
| AC-4 | must | ✅ PASS |
| AC-5 | should | ✅ PASS |
| AC-6 | should | ✅ PASS |

**must AC**: 4/4 (100%) PASS
**should AC**: 2/2 (100%) PASS
**전체**: 6/6 PASS
