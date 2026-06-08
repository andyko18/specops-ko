<!-- FID: 20260609-release-manifest-r6-doc-fix -->
<!-- OWNER_COMMAND: /maintain -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260609-release-manifest-r6-doc-fix

> 스프린트 계약서. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 읽기 전용.

## 계약 항목

---

### AC-1: release.sh가 plugin.json 버전을 bump한다

**Given** `scripts/release.sh`가 FR-7 섹션을 포함한 상태에서

**When** `bash scripts/release.sh 1.11.0 --dry-run`을 실행하면

**Then** `.claude-plugin/plugin.json`의 `"version"` 값이 `"1.11.0"`이다

**검증 방법**: `bash scripts/release.sh 1.11.0 --dry-run && grep '"version"' .claude-plugin/plugin.json | grep '1.11.0'`
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: release.sh가 marketplace.json 버전을 bump한다

**Given** `scripts/release.sh`가 FR-7 섹션을 포함한 상태에서

**When** `bash scripts/release.sh 1.11.0 --dry-run`을 실행하면

**Then** `.claude-plugin/marketplace.json`의 `"version"` 값이 `"1.11.0"`이다

**검증 방법**: `bash scripts/release.sh 1.11.0 --dry-run && grep '"version"' .claude-plugin/marketplace.json | grep '1.11.0'`
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: 현재 manifest desync 즉시 수정

**Given** 수정 완료 상태에서

**When** `grep '"version"' .claude-plugin/plugin.json .claude-plugin/marketplace.json`을 실행하면

**Then** 두 파일 모두 `"version": "1.10.0"`을 반환한다

**검증 방법**: `grep '"version"' .claude-plugin/plugin.json .claude-plugin/marketplace.json`
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: CHANGELOG v1.10.0 섹션 백필

**Given** `CHANGELOG.md`가 수정된 상태에서

**When** `[1.10.0]` 섹션을 확인하면

**Then** `show-fid-status`와 `release-ko`(또는 `release.sh`) 키워드가 Added 또는 Changed 항목에 포함된다

**검증 방법**: `grep -E "show-fid|release-ko|release\.sh" CHANGELOG.md`
**관련 FR**: FR-4
**우선순위**: must

---

### AC-5: R-6 비활성화

**Given** `hooks/rules.jsonl`이 수정된 상태에서

**When** `cat hooks/rules.jsonl | grep R-6`을 실행하면

**Then** R-6 행의 `"enabled"` 값이 `false`다

**검증 방법**: `python3 -c "import sys,json; [print(r.get('enabled')) for r in [json.loads(l) for l in open('hooks/rules.jsonl')] if r.get('id')=='R-6']"`
**관련 FR**: FR-5
**우선순위**: must

---

### AC-6: test-rules.sh T5.c stop=2 PASS

**Given** `test-rules.sh`가 `stop=2` 어서션으로 갱신된 상태에서

**When** `bash scripts/tests/governance/test-rules.sh`를 실행하면

**Then** `PASS T5.c matcher 분류 posttool=3 stop=2` 메시지가 출력되고 FAIL 0건이다

**검증 방법**: `bash scripts/tests/governance/test-rules.sh 2>&1 | grep -E "T5.c|FAIL"`
**관련 FR**: FR-6
**우선순위**: must

---

### AC-7: README commands 12건

**Given** `README.md`가 수정된 상태에서

**When** `grep 'commands' README.md`를 실행하면

**Then** "12건" 표기와 `release`·`start-auto`·`start-batch`가 commands 목록에 포함된다

**검증 방법**: `grep -E "12건|release\.md|start-auto|start-batch" README.md`
**관련 FR**: FR-7
**우선순위**: must

---

### AC-8: README footer v1.10.0

**Given** `README.md`가 수정된 상태에서

**When** `tail -3 README.md`를 확인하면

**Then** `최신: v1.10.0` 문자열이 포함된다

**검증 방법**: `grep '최신:' README.md | grep 'v1.10.0'`
**관련 FR**: FR-8
**우선순위**: must

---

### AC-9: maintain.md chain 완전 표기

**Given** `commands/maintain.md`가 수정된 상태에서

**When** chain 행(line 24 근처)을 확인하면

**Then** `integration-test-ko`·`performance-test-ko`·`PR` 키워드가 포함된다

**검증 방법**: `grep -E "integration-test|performance-test" commands/maintain.md`
**관련 FR**: FR-9
**우선순위**: must

---

### AC-10: 메타 skill chain 다이어그램 완전 표기

**Given** `skills/using-specops-auto-ko-ko/SKILL.md`가 수정된 상태에서

**When** chain 다이어그램 행(L70 근처)을 확인하면

**Then** `integration-test-ko`·`performance-test-ko`·`PR` 키워드가 포함된다

**검증 방법**: `grep -E "integration-test|performance-test" skills/using-specops-auto-ko-ko/SKILL.md`
**관련 FR**: FR-10
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수)

---

### AC-R-1: test-release.sh 전체 PASS

**Given** `scripts/release.sh`가 수정된 상태에서

**When** `bash scripts/tests/test-release.sh`를 실행하면

**Then** T1~T9 전체 PASS, FAIL 0건이다

**검증 방법**: `bash scripts/tests/test-release.sh 2>&1 | tail -5`
**관련 FR**: NFR-2
**우선순위**: must

---

### AC-R-2: validate-structure.sh 전체 PASS

**Given** 모든 변경이 완료된 상태에서

**When** `bash scripts/_internal/validate-structure.sh`를 실행하면

**Then** 전체 항목 ✅ PASS, SKIP/FAIL 없음 (manifest: OK (both=1.10.0))

**검증 방법**: `bash scripts/_internal/validate-structure.sh`
**관련 FR**: NFR-4
**우선순위**: must

---

*작성: specifying-ko (유지보수 분기) · 2026-06-09 · FID: 20260609-release-manifest-r6-doc-fix*
