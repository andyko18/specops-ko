<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260610-design-screen-enrich · task: T2 -->

# Dispatch Context: T2 (FID 20260610-design-screen-enrich)

## 1. 담당 AC

- AC-1: rationale 추출 — 핵심 결정 요약
- AC-2: screen.md에 Design Rationale 섹션 저장
- AC-3: ui-ux-pro-max 없을 때 섹션 생략
- AC-4: anti-pattern 위반 없음 — 자동 통과
- AC-5: anti-pattern 위반 발견 — 사용자 확인
- AC-6: [m] 선택 → HTML 수정 루프 복귀
- AC-7: [s] 선택 → 위반 상태로 저장
- AC-9: /design-screens rationale 1회 공유
- AC-10: ui-ux-pro-max 없을 때 게이트 skip
- AC-11: [m/s] 기본값 = s (Q2 가정)

## 2. 관련 spec.md 섹션

- `.specops/20260610-design-screen-enrich/spec.md`
- (없음)

## 3. 테스트 명령

```bash
grep -n 'rationale|3-3\.5|Anti-pattern 게이트|Design Rationale' commands/design-screens.md
```

## 4. 수정 허용 파일 (whitelist)

- `commands/design-screens.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `/Users/andyko/Project/0.Claude/specops-auto-ko/.worktrees/20260610-design-screen-enrich-T2/`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
