<!-- FID: 20260518-context-adr-auto-ref -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: github/spec-kit plan-template.md + obra/superpowers writing-plans -->
<!-- layer: Lifecycle-Artifact -->

# CONTEXT.md + ADR 자동 참조 레이어 구현 플랜 — 20260518-context-adr-auto-ref

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: `skills/specifying-ko/SKILL.md` Step 1 §1에 프로젝트 루트 `CONTEXT.md` + `docs/adr/*.md` 자동 감지 블록을 추가하고, `test-memory-references.sh`에 검증 케이스를 추가한다.

**아키텍처**: 기존 `.specops/memory/*.md` 9종 감지 패턴(graceful skip + §참조 인용)과 동일한 방식으로 CONTEXT.md와 docs/adr/ 감지를 추가한다. SKILL.md는 Claude 행동 지시이므로 텍스트 편집만, 테스트는 정적 grep 검증으로 구현한다.

**기술 스택**: Markdown (SKILL.md 텍스트 지시), Bash (테스트 스크립트)

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-R-1

---

## 1. 가정 (5원칙 5번)

- `CONTEXT.md` 위치는 프로젝트 루트 고정 (`ls CONTEXT.md 2>/dev/null`) — 재귀 탐색 불필요
- `docs/adr/` 경로만 지원 — `adr/`, `docs/decisions/` 등 대안 경로는 YAGNI
- 정적 검증(grep) 방식으로 테스트 — specifying-ko는 Claude skill이라 bash 직접 실행 불가 (기존 T1.a~T4.a 패턴 준수)
- ADR 파일 수 집계: `ls docs/adr/*.md 2>/dev/null | wc -l`

## 2. 파일 구조

### 생성
- 없음

### 수정
- `skills/specifying-ko/SKILL.md:65` — `.specops/memory/` 감지 블록 직후, DESIGN.md 감지 블록 직전에 CONTEXT.md + ADR 감지 2블록 추가 (약 12줄)
- `scripts/tests/test-memory-references.sh:60-63` — `echo ""` + summary 앞에 T5.a + T6.a 케이스 삽입 (약 14줄)

### 삭제
- 없음

## 3. 데이터 모델

해당 없음.

## 4. 계약

**SKILL.md 추가 내용 (CONTEXT.md 감지, FR-1)**:
```markdown
   - **`CONTEXT.md` 프로젝트 컨텍스트 자동 감지** (v2.1 신규):
     - `ls CONTEXT.md 2>/dev/null` — 부재 시 graceful skip
     - 존재 시: spec.md `§참조`에 `"프로젝트 컨텍스트 — \`CONTEXT.md\`"` 인용
```

**SKILL.md 추가 내용 (ADR 감지, FR-2)**:
```markdown
   - **`docs/adr/*.md` Architecture Decision Records 자동 감지** (v2.1 신규):
     - `ls docs/adr/*.md 2>/dev/null | wc -l` — 0이면 graceful skip
     - N > 0이면: spec.md `§참조`에 `"아키텍처 결정 기록 — \`docs/adr/\` (N건)"` 인용
```

**테스트 추가 내용**:
```bash
# ── T5.a 정적: SKILL.md 가 CONTEXT.md 감지 명시 ──
if grep -q "CONTEXT\.md" "$SKILL"; then
  ok "T5.a SKILL.md — CONTEXT.md 자동 감지 명시"
else
  nope "T5.a CONTEXT.md 감지" "SKILL.md에 CONTEXT.md 언급 없음"
fi

# ── T6.a 정적: SKILL.md 가 docs/adr/ 감지 명시 ──
if grep -q "docs/adr" "$SKILL"; then
  ok "T6.a SKILL.md — docs/adr/ 자동 감지 명시"
else
  nope "T6.a ADR 감지" "SKILL.md에 docs/adr 언급 없음"
fi
```

## 5. 태스크 개요

두 태스크는 수정 파일이 disjoint (SKILL.md vs test-script) → 독립, 병렬 구현 가능.

1. **T1** — `skills/specifying-ko/SKILL.md` 수정 — CONTEXT.md + ADR 감지 블록 추가 (AC-1, AC-2, AC-3)
2. **T2** — `scripts/tests/test-memory-references.sh` 수정 — T5.a + T6.a 케이스 추가 (AC-4)
3. **T3** — AC 전체 검증 + validate-structure.sh (AC-5, AC-R-1)

T1 ∥ T2 → T3 순차.

## 6. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| SKILL.md 편집 시 기존 `.specops/memory/` 감지 블록 훼손 | H | T3에서 T1.a~T4.a 회귀 테스트 실행 + AC-R-1 grep 검증 |
| ADR 블록 삽입 위치 오류 (DESIGN.md 감지보다 뒤) | M | T1 Step 3에서 L65 직후 삽입 위치 확인 |
| test-memory-references.sh exit 코드 회귀 | L | T2 Step 4에서 PASS=6 FAIL=0 확인 |

## 7. 자체 검토 (5원칙 체크리스트)

- [x] **투명성**: T1(왜: graceful skip 패턴 확장), T2(왜: 정적 검증 패턴 준수), T3(왜: AC 계약 검증) 각각 근거 명시
- [x] **문지기**: 파괴적 작업 없음 (텍스트 편집만)
- [x] **주권 존중**: 사용자 승인 필요 지점 없음 (유지보수 범위)
- [x] **한계 고백**: §1 가정 4건 명시 (CONTEXT.md 위치 고정, docs/adr/ 경로만 지원, 정적 검증 방식, wc -l 집계)

## 8. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음. 기존 .specops/memory/ graceful skip 패턴 준용 + 독립 파일 쌍이므로 설계 결정 명확.

## 9. 다음 단계

`/tasks 20260518-context-adr-auto-ref` — 본 플랜을 바이트-사이즈 TDD 태스크로 분해.

---

*작성: andyko · 2026-05-18 · FID: 20260518-context-adr-auto-ref · 생성 커맨드: /plan*
