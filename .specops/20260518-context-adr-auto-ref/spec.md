<!-- FID: 20260518-context-adr-auto-ref -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# CONTEXT.md + ADR 자동 참조 레이어 명세 — 20260518-context-adr-auto-ref

**§유형**: 유지보수

## 1. 개요

**목적**: specifying-ko Step 1 §프로젝트 맥락 탐색에 프로젝트 루트 `CONTEXT.md`와 `docs/adr/*.md` (Architecture Decision Records) 자동 감지를 추가하여, 스펙 작성 시 이들을 spec.md §참조에 자동 인용한다.

**배경**: 현재 specifying-ko는 `.specops/memory/*.md` 9종을 자동 감지해 spec.md §참조에 인용하나, 프로젝트 루트 `CONTEXT.md`와 `docs/adr/` ADR 파일은 감지하지 못한다. obra/superpowers context-aware planning 패턴에서는 이 두 파일 유형이 플랜·스펙 작성 시 핵심 참조 자료로 사용된다.

**성공 판정**: specifying-ko Step 1 실행 시 `CONTEXT.md`와 `docs/adr/*.md`가 존재하면 spec.md §참조에 자동 인용되고, 부재 시 graceful skip으로 기존 동작과 동일하게 진행된다.

## 2. 범위

### 포함
- FR-1: `CONTEXT.md` 자동 감지 — 프로젝트 루트 존재 시 spec.md §참조에 인용 (독립 — 병렬 구현 가능)
- FR-2: `docs/adr/*.md` 자동 감지 — 존재 시 ADR 파일 목록을 spec.md §참조에 인용 (독립 — 병렬 구현 가능)
- FR-3: graceful skip — CONTEXT.md / docs/adr/ 부재 시 오류 없이 진행 (의존: FR-1, FR-2)
- FR-4: 회귀 보호 — 기존 `.specops/memory/` 9종 감지 무손상
- FR-5: test-memory-references.sh에 CONTEXT.md/ADR 감지 검증 케이스 추가 (의존: FR-1, FR-2)

### 제외 (YAGNI)
- `docs/decisions/`, `adr/`, `.adr/` 등 대안 ADR 경로 지원 — `docs/adr/`만 지원
- planning-ko §참조 수정 — specifying-ko spec.md §참조 기록으로 충분
- ADR 내용 파싱 (제목·날짜 추출) — 파일 경로 목록만 인용

## 3. 사용자 시나리오

**시나리오 A (CONTEXT.md 존재)**:
```
/start "사용자 인증 기능 추가"
→ specifying-ko Step 1 실행
→ ls CONTEXT.md → 존재 확인
→ spec.md §참조에 "프로젝트 컨텍스트 — CONTEXT.md" 자동 인용
```

**시나리오 B (docs/adr/ 존재)**:
```
/start "캐시 레이어 추가"
→ specifying-ko Step 1 실행
→ ls docs/adr/*.md → ADR-001.md, ADR-002.md 발견
→ spec.md §참조에 "아키텍처 결정 기록 — docs/adr/ (2건)" 자동 인용
```

**시나리오 C (둘 다 없음)**:
```
/start "간단한 유틸 추가"
→ specifying-ko Step 1 실행
→ CONTEXT.md, docs/adr/ 모두 부재 → graceful skip → 기존 동작 그대로
```

## 4. 기능 요구사항

### FR-1: CONTEXT.md 자동 감지
- specifying-ko Step 1 §1에 `ls CONTEXT.md 2>/dev/null` 체크 추가
- 존재 시: spec.md §참조에 bullet `"프로젝트 컨텍스트 — \`CONTEXT.md\`"` 추가
- 부재 시: graceful skip (오류·경고 없음)
- 위치: `.specops/memory/` 감지 블록 **직후**, DESIGN.md 감지 블록 **직전**

### FR-2: docs/adr/*.md 자동 감지
- specifying-ko Step 1 §1에 `ls docs/adr/*.md 2>/dev/null` 체크 추가
- 존재 시: 파일 수 N과 함께 spec.md §참조에 bullet `"아키텍처 결정 기록 — \`docs/adr/\` (N건)"` 추가
- 부재 시: graceful skip
- 위치: CONTEXT.md 감지 블록 직후

### FR-3: graceful skip
- 두 체크 모두 `2>/dev/null` 리다이렉션으로 오류 억제
- 기존 `.specops/memory/` graceful skip 패턴과 동일하게 구현

### FR-4: 기존 9종 감지 무손상
- `.specops/memory/*.md` 감지 표(9종) 및 graceful skip 로직 변경 없음
- `회귀 보호 계약` 문구 보존

### FR-5: 테스트 케이스
- `scripts/tests/test-memory-references.sh`에 T5.a (CONTEXT.md 정적 검증) + T6.a (ADR 정적 검증) 추가
- 정적 검증 방식: `grep -q "CONTEXT\.md" "$SKILL"` + `grep -q "docs/adr" "$SKILL"`

## 5. 비기능 요구사항

- **NFR-1**: `ls` 명령 실행 오버헤드 2회 추가 — 무시 가능 (shell builtin)
- **NFR-2**: 기존 test-memory-references.sh PASS=4 회귀 없음

## 6. 참조

- `.specops/20260518-context-adr-auto-ref/current-state.md` — baseline 분석
- `.specops/20260518-context-adr-auto-ref/impact-analysis.md` — 영향 분석
- `skills/specifying-ko/SKILL.md:48-65` — 기존 .specops/memory/ 감지 구현
- `scripts/tests/test-memory-references.sh` — 회귀 테스트
- obra/superpowers context-aware planning 패턴 (이식 대상)

---

*작성: specifying-ko [유지보수 분기] · 2026-05-18 · FID: 20260518-context-adr-auto-ref*
