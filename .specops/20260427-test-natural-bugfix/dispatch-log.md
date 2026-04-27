<!-- FID: 20260427-test-natural-bugfix -->
<!-- OWNER_COMMAND: /implement (dogfood) -->

# Dispatch Log — 20260427-test-natural-bugfix (A4 dogfood)

## 자연어 maintenance 진입 시뮬 (Phase A 단독)

**입력**: `"auth.js 토큰 만료 버그 고쳐줘"` (자연어 — Phase D 미적용 시점)

**메타 skill 분류 결과** (Phase D 적용 후 메타 skill `using-specops-auto-ko-ko` 가 자동 수행. Phase A 단독 시점에는 수동 시뮬):

```
maintenance flag = true
args 합성: "<!-- entry: maintain -->\nauth.js 토큰 만료 버그 고쳐줘"
```

**announce 메시지** (5 원칙 1 투명성):

```
Using specifying-ko (maintenance) to analyze auth.js token expiry bug
```

**args first line trail** (AC-13 transcript-based 검증):

```
<!-- entry: maintain -->
```

**specifying-ko Step 1 분기 결과**:
- args 첫 줄 = `<!-- entry: maintain -->` 매칭 → [유지보수 분기] 진입
- 5 항목 mini-checklist 실행 → current-state.md 산출
- §1 라인 범위 = 8 (> 5) → §유형 = `유지보수` 자동 부여
- ★ HARD GATE 통과 후 spec.md / acceptance-criteria.md 작성 (회귀 AC 강제)

---

*A4 dogfood · 2026-04-27 · FID: 20260427-test-natural-bugfix*
