<!-- FID: 20260604-v1-5-0 -->
<!-- OWNER_COMMAND: /specify -->
<!-- layer: Lifecycle-Artifact -->

# Acceptance Criteria — 20260604-v1-5-0

## must AC

### AC-1: plugin.json 버전 1.5.0

- **Given**: `.claude-plugin/plugin.json` 존재
- **When**: `python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])"`
- **Then**: `1.5.0` 출력

### AC-2: marketplace.json 버전 1.5.0

- **Given**: `.claude-plugin/marketplace.json` 존재
- **When**: `python3 -c "import json; print(json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version'])"`
- **Then**: `1.5.0` 출력

### AC-3: CHANGELOG.md에 [1.5.0] 섹션 존재

- **Given**: `CHANGELOG.md` 존재
- **When**: `grep -F "## [1.5.0]" CHANGELOG.md`
- **Then**: 해당 라인 매칭 (exit 0)

### AC-4: validate-structure manifest 통과

- **Given**: plugin.json + marketplace.json 모두 1.5.0
- **When**: `bash scripts/_internal/validate-structure.sh 2>&1 | grep manifest`
- **Then**: `manifest OK (both=1.5.0)` 출력

### AC-5: governance 회귀 없음

- **Given**: 코드 변경 없음 (버전 bump만)
- **When**: `bash scripts/tests/governance/test-rules.sh 2>&1 | tail -1`
- **Then**: `==== Results: PASS=70 FAIL=0 ====`

---

## 회귀 방지 AC

해당 없음 — 신규 분기 (§유형: 신규). 버전 bump는 기존 로직 미변경.

---

*작성: specops-auto-ko · 2026-06-04 · FID: 20260604-v1-5-0*
