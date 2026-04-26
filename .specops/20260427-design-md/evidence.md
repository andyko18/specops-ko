# Evidence — FID: 20260427-design-md

**검증 일시**: 2026-04-26
**검증자**: verifying-evidence-ko (본 세션)

---

## AC-1 (must): commands/start-design.md 존재 + Stripe 브랜드 + git commit

```
명령: ls commands/start-design.md && grep -c "Stripe" commands/start-design.md
출력: commands/start-design.md (exit 0), Stripe=4
```

**결과: PASS** (파일 존재, Stripe 4회 등장)

---

## AC-2 (must): templates/DESIGN.md 존재 + ^## 섹션 6개 이상

```
명령: ls templates/DESIGN.md && grep -c "^## " templates/DESIGN.md
출력: templates/DESIGN.md (exit 0), ^## 카운트=6
```

**결과: PASS** (파일 존재, 섹션 정확히 6개)

---

## AC-3 (must): specifying-ko SKILL.md에 DESIGN.md 3회 이상 등장

```
명령: grep -c "DESIGN.md" skills/specifying-ko/SKILL.md
출력: 3 (line 29, 30, 31)
```

**결과: PASS** (3회 등장 — 최솟값 충족)

---

## AC-4 (must): spec.md §참조에 DESIGN.md 포함 지시문 존재

```
명령: grep "디자인 시스템 준수" skills/specifying-ko/SKILL.md
출력: → **있으면**: 생성하는 `spec.md` §참조에 "`DESIGN.md` 디자인 시스템 준수" 포함
```

**결과: PASS** (지시문 line 30에 존재)

---

## AC-5 (should): 덮어쓰기 방지 확인 질문 로직

```
명령: grep -c "덮어" commands/start-design.md
출력: 1
```

**결과: PASS** ("덮어쓸까요? [y/n]" 확인 로직 존재)

---

## AC-6 (should): specops-auto-ko 루트 DESIGN.md (Claude 브랜드) 생성

```
명령: ls DESIGN.md && grep -c "^## " DESIGN.md
출력: DESIGN.md (exit 0), ^## 카운트=6

명령: grep "specops-auto-ko" DESIGN.md (7회) + grep "7C3AED" DESIGN.md (7회)
출력: 각각 1 이상
```

**결과: PASS** (파일 존재, 6섹션, Claude 브랜드 색상 포함)

---

## git 커밋 증거

```
b0861b2 feat(design-md): specops-auto-ko DESIGN.md dogfood 생성 (Claude 브랜드, AC-6)
76ba4cf feat(design-md): specifying-ko DESIGN.md 자동 감지+참조 주입 추가 (AC-3,AC-4)
114657a feat(design-md): /start-design 커맨드 추가 (브랜드 선택+덮어쓰기 방지, AC-1,AC-5)
7ce9b17 feat(design-md): DESIGN.md 템플릿 추가 (awesome-design-md 포맷, AC-2)
```

---

## 종합

| AC | must/should | 결과 |
|---|---|---|
| AC-1 | must | PASS |
| AC-2 | must | PASS |
| AC-3 | must | PASS |
| AC-4 | must | PASS |
| AC-5 | should | PASS |
| AC-6 | should | PASS |

**must AC: 4/4 PASS (100%)**
**should AC: 2/2 PASS (100%)**
