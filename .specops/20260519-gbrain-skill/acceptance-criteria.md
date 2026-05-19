<!-- FID: 20260519-gbrain-skill -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260519-gbrain-skill

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: gbrain-append.sh 존재 + 실행 가능

**Given** 레포지토리 루트

**When** `bash scripts/gbrain-append.sh` 실행 (인자 없음)

**Then** "Usage: gbrain-append.sh <insight>" 형태의 usage 출력 (exit 1)

**검증 방법**: `bash scripts/tests/test-gbrain.sh` T1.a
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: JSONL 레코드 추가

**Given** `.specops/memory/learnings.jsonl` 존재 여부 무관

**When** `bash scripts/gbrain-append.sh "테스트 인사이트"` 실행

**Then** `.specops/memory/learnings.jsonl`의 마지막 줄에 `ts`·`fid`·`insight`·`tags` 키를 포함한 유효한 JSON 1줄 추가

**검증 방법**: `bash scripts/tests/test-gbrain.sh` T2.a
**관련 FR**: FR-1, FR-2
**우선순위**: must

---

### AC-3: learnings.jsonl 미존재 시 자동 생성

**Given** `.specops/memory/learnings.jsonl` 미존재

**When** `bash scripts/gbrain-append.sh "첫 인사이트"` 실행

**Then** `.specops/memory/learnings.jsonl` 생성 + 레코드 1줄 추가

**검증 방법**: `bash scripts/tests/test-gbrain.sh` T3.a
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: SKILL.md 존재 + frontmatter 6필드 완전

**Given** 레포지토리 루트

**When** `cat skills/gbrain-ko/SKILL.md` 확인

**Then** frontmatter에 name·description·layer·reference_upstream·specops_version·used_by 6필드 전부 존재

**검증 방법**: `bash scripts/tests/test-gbrain.sh` T4.a
**관련 FR**: FR-4
**우선순위**: must

---

### AC-5: SKILL.md 조회 프로세스 명시

**Given** `skills/gbrain-ko/SKILL.md`

**When** 내용 확인

**Then** learnings.jsonl 읽기·최신 N건 출력·전체 개수 요약 프로세스가 명시됨

**검증 방법**: `bash scripts/tests/test-gbrain.sh` T5.a
**관련 FR**: FR-4
**우선순위**: must

---

### AC-6: commands/gbrain.md 존재 + gbrain-ko 언급

**Given** 레포지토리 루트

**When** `cat commands/gbrain.md` 확인

**Then** `/gbrain` trigger + `gbrain-ko` skill 언급 포함

**검증 방법**: `bash scripts/tests/test-gbrain.sh` T6.a
**관련 FR**: FR-5
**우선순위**: must

---

### AC-7: --fid 필터링

**Given** learnings.jsonl에 fid가 다른 레코드 2건 이상

**When** `bash scripts/gbrain-append.sh "내용" --fid test-fid` 실행 후 `/gbrain --fid test-fid` 조회

**Then** test-fid 레코드만 출력

**검증 방법**: `bash scripts/tests/test-gbrain.sh` T7.a
**관련 FR**: FR-7
**우선순위**: should

---

### AC-R-1: validate-structure.sh 전 항목 ✅

**Given** 새 파일 3개 추가 + baseline 수정 완료

**When** `bash scripts/_internal/validate-structure.sh` 실행

**Then** 전 항목 ✅ (file_counts, frontmatter, ref_upstream_fmt 포함)

**검증 방법**: `bash scripts/_internal/validate-structure.sh`
**관련 FR**: FR-6
**우선순위**: must

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록

## 참조

- `skills/sprint-contracts-ko/SKILL.md`
- `templates/acceptance-criteria.md`

---

*작성: specifying-ko · 2026-05-19 · FID: 20260519-gbrain-skill · 생성 커맨드: /maintain*
