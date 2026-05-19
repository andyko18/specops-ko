<!-- FID: 20260518-context-adr-auto-ref -->
<!-- OWNER_COMMAND: /maintain -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# 현재 시스템 분석 (Current State) — 20260518-context-adr-auto-ref

> analyzing-ko 산출. 변경 대상의 baseline 캡처.

## 1. 변경 대상 식별

- 파일: `skills/specifying-ko/SKILL.md` (Lines: 40–65 — Step 1 §프로젝트 맥락 탐색 + memory 자동 감지 섹션, 26줄)
- 파일: `skills/planning-ko/SKILL.md` (Lines: 180–186 — §참조 섹션, 7줄)
- 진입점 섹션: specifying-ko §1 "프로젝트 맥락 탐색" + planning-ko §참조
- 관련 테스트: `scripts/tests/test-memory-references.sh`

**라인 범위 합산: 33줄 → 유지보수**

## 2. 호출자/의존 매핑

**specifying-ko 호출자**:
- `commands/start.md` — `/start` 슬래시 → specifying-ko 직호출
- `commands/maintain.md` → analyzing-ko → specifying-ko chain
- `skills/using-specops-auto-ko-ko/SKILL.md` — 메타 skill 신호 감지 후 직호출
- `skills/clarifying-ko/SKILL.md` — chain 선행
- `skills/analyzing-ko/SKILL.md` — chain 후 호출

**planning-ko 호출자**:
- `skills/clarifying-ko/SKILL.md` — chain 후 호출
- `commands/start.md` chain 목록에 포함

**내부 의존** (specifying-ko Step 1):
- `.specops/memory/*.md` — 현재 9종 자동 감지 (constitution, requirements, architecture, frontend-architecture, backend-architecture, api-spec, data-model, screens-overview, test-strategy)
- `DESIGN.md` — UI 기능 시 참조
- `screens/` — UI 기능 시 존재 확인

> 한계: using-specops-auto-ko-ko 메타 skill은 동적 로드 (SessionStart 훅) — 정적 grep으로 완전 추적 불가

## 3. 기존 테스트 커버리지

- `scripts/tests/test-memory-references.sh` — specifying-ko Step 1 memory 자동 감지 4건 정적·fixture 검증 (T1.a/T2.a/T3.a/T4.a)
- `scripts/tests/test-validate-structure.sh` — 구조 무결성 (specifying-ko/planning-ko SKILL.md 파일 존재 포함)
- `scripts/tests/governance/test-rules.sh` — 거버넌스 규칙

**커버되지 않는 경로**:
- CONTEXT.md 자동 감지 로직 — 현재 미구현, 테스트 없음
- ADR 파일 자동 감지 로직 — 현재 미구현, 테스트 없음

## 4. 관찰 가능 동작 (Baseline)

> ⚠️ 직접 실행 불가 — SKILL.md는 Claude skill, bash 직접 실행 불가. 아래는 테스트 + 정적 분석 기반 baseline.

| # | 시나리오 | 현재 동작 | 비고 |
|---|---|---|---|
| 1 | specifying-ko Step 1 실행 시 `.specops/memory/` 존재 | 9종 파일 감지 후 spec.md §참조에 인용 | T1.a PASS |
| 2 | specifying-ko Step 1 실행 시 `.specops/memory/` 부재 | graceful skip — 오류 없이 진행 | T3.a PASS |
| 3 | specifying-ko Step 1 실행 시 `CONTEXT.md` 존재 | **감지 없음** — §참조 미인용 | 현재 미지원 |
| 4 | specifying-ko Step 1 실행 시 `docs/adr/` 존재 | **감지 없음** — §참조 미인용 | 현재 미지원 |
| 5 | planning-ko §참조 섹션 | 고정 텍스트만 (templates/plan.md, upstream) | ADR 참조 없음 |

관련 테스트 결과:
```
PASS T1.a SKILL.md 가 9종 .specops/memory/*.md 모두 명시 (감지 표)
PASS T2.a SKILL.md 본문 — spec.md §참조 인용 + graceful skip + 회귀 보호 명시
PASS T3.a .specops/memory/ 부재 → ls 빈 결과 (graceful skip 전제 보장)
PASS T4.a 부분 존재 → ls 가 존재하는 3종만 반환
PASS=4 FAIL=0
```

## 5. 회귀 위험 메모

- specifying-ko Step 1 §1 수정 → test-memory-references.sh 기존 4 케이스 회귀 위험 (CONTEXT.md/ADR 감지 추가 시 기존 9종 감지 테이블 보존 필수)
- planning-ko §참조 수정 → validate-structure.sh frontmatter 검증 영향 없음 (본문 변경만)
- 메타 skill(using-specops-auto-ko-ko)은 specifying-ko Step 1 본문에 의존 — 텍스트 변경 시 SessionStart 훅 주입 내용과 정합성 확인 필요

---

*작성: analyzing-ko · 2026-05-18 · FID: 20260518-context-adr-auto-ref*
