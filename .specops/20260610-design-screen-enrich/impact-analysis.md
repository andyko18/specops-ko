# impact-analysis.md — 20260610-design-screen-enrich

## §1 외부 영향

| 영향 범위 | 세부 |
|---|---|
| `commands/design-screens.md` | 단수 `design-screen.md` 변경 내용을 복수에 동기 반영 필요 (Step 3-3·Step 3-4) |
| `templates/screen.md` | `design-rationale` 섹션 추가 → 신규 화면 스캐폴딩 시 자동 포함됨 (design-screen.sh L51이 cp 사용) |
| 기존 `screens/*.md` 파일 | 기존 파일은 영향 없음 — 템플릿 변경은 신규 스캐폴딩에만 적용 |
| API / DB | 해당 없음 — 문서 파일만 변경 |
| ui-ux-pro-max 반환값 | anti-pattern 필드(`anti_patterns` 등) 존재 여부는 동적 — SKILL.md description에 "anti-patterns" 명시되어 있어 필드 존재 가정 가능하나, 없을 시 "항목 없음" 처리 분기 필요 |

---

## §2 마이그레이션 / 롤백

- 변경 대상: 문서 파일 (커맨드 md, 템플릿 md) — 코드 마이그레이션 없음
- 롤백: `git revert <commit-SHA>` 로 즉시 원복 가능
- 기존 `screens/*.md` 파일의 `design-rationale` 섹션 소급 적용은 **선택적** (기존 파일 미변경 정책 권고)

---

## §3 관련 PR·이슈 히스토리

> 데이터 출처: git log (gh CLI — 가용하나 로컬 레포 이슈 없어 생략)

```
404f080 feat: /design-screens 복수 커맨드 신설 + cross-ref 추가 (T1·T4)
38aea40 fix(design-screens): Step 3-1 충돌확인 순서 명확화 + Step 3-3 html 생성 표현 수정
8435db7 verify: evidence.md AC 9/9 PASS (FID 20260609-design-screens)
```

- 복수 커맨드(`design-screens.md`)는 2026-06-09 신설, PR #53 머지 완료
- 단수(`design-screen.md`)는 더 오래된 히스토리 (2026-05-20 출처 명시)
- 두 파일 모두 최근 활발히 수정 중 — 충돌 리스크 낮음 (본 FID가 main 기준 클린 브랜치)
