<!-- FID: 20260609-release-manifest-r6-doc-fix -->
<!-- OWNER_COMMAND: /maintain -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# release manifest bump + R-6 재정의 + 문서 동기화 — 20260609-release-manifest-r6-doc-fix

## 1. 개요

**§유형**: 유지보수

**목적**: release.sh 자동화 사각지대(manifest 버전 누락)·R-6 false-warn·문서 stale 3종을 일괄 수정한다.

**배경**: v1.10.0 릴리스 후 `plugin.json`/`marketplace.json`이 v1.9.0에 고착됨. R-6 거버넌스 규칙이 gbrain-ko "manual-only" 설계와 모순돼 정상 완주마다 false-warn 발생. README commands 건수·footer 버전, `maintain.md`·메타skill chain 다이어그램도 v1.8.0 이전 상태로 stale.

**성공 판정**: `bash scripts/release.sh X.Y.Z --dry-run` 후 plugin.json/marketplace.json 버전이 X.Y.Z로 갱신되고, Stop 훅이 정상 완주 시 R-6 경고를 발화하지 않으며, 문서 4건이 최신 chain을 반영하면 완성.

## 2. 범위

### 포함

- **T1-a** 즉시 desync 수정: `plugin.json`/`marketplace.json` v1.9.0 → v1.10.0 (독립 — 병렬 구현 가능)
- **T1-b** release.sh FR-7: manifest 버전 bump 로직 추가 (독립 — 병렬 구현 가능)
- **T1-c** CHANGELOG v1.10.0 백필: PR #50(show-fid-status), PR #51(release-ko) 내용 기재 (독립 — 병렬 구현 가능)
- **T2** R-6 disabled: `rules.jsonl` enabled=false + `test-rules.sh` T5.c stop 카운트 갱신 (독립 — 병렬 구현 가능)
- **T4** 문서 동기화 4건: README commands 건수/목록, footer, `maintain.md` chain, 메타skill chain (독립 — 병렬 구현 가능)

### 제외 (YAGNI)

- validate-structure.sh에 README↔manifest 교차검증 강화 (T3 별도 스프린트)
- R-6 `apply_gbrain_absence_rule` 함수 삭제 (enabled=false로 비활성화만, 재활성화 가능성 보존)
- gbrain-append producer chain 편입 (T2(a) 옵션 — 이번 스코프 아님)

## 3. 사용자 시나리오

### 주요 시나리오 — release.sh 실행

**사용자**: 플러그인 유지관리자
**상황**: 새 버전(예: v1.11.0) 릴리스 시점
**행동**: `bash scripts/release.sh 1.11.0` 실행
**기대 결과**: CHANGELOG·README·commands footer·plugin.json·marketplace.json 5자산이 모두 v1.11.0으로 동기화됨

### 보조 시나리오 — lifecycle 완주

**사용자**: 개발자
**상황**: specops lifecycle 정상 완주 (verify + evidence.md 산출)
**행동**: 세션 종료
**기대 결과**: Stop 훅 R-6 경고 미발화, friction-log에 R-6 항목 없음

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `release.sh <VERSION>`이 `plugin.json`의 `"version"` 필드를 VERSION으로 갱신한다 | must |
| FR-2 | `release.sh <VERSION>`이 `marketplace.json`의 `"version"` 필드를 VERSION으로 갱신한다 | must |
| FR-3 | `plugin.json`/`marketplace.json` 버전이 즉시 v1.10.0으로 수정된다 | must |
| FR-4 | `CHANGELOG.md` `[1.10.0]` 섹션에 PR #50(show-fid-status)·PR #51(release-ko) 내용이 기재된다 | must |
| FR-5 | `rules.jsonl` R-6 행의 `"enabled"` 값이 `false`로 설정된다 | must |
| FR-6 | `test-rules.sh` T5.c 어서션이 `stop=2`로 갱신되어 PASS한다 | must |
| FR-7 | README:92 commands 건수가 12건으로, 목록에 `release`·`start-auto`·`start-batch`가 포함된다 | must |
| FR-8 | README footer 버전이 "최신: v1.10.0 (2026-06-09)"로 갱신된다 | must |
| FR-9 | `maintain.md:24` chain이 `→ integration-test-ko → performance-test-ko → PR`까지 명시된다 | must |
| FR-10 | `using-specops-auto-ko-ko/SKILL.md:70` chain 다이어그램이 `→ integration-test-ko → performance-test-ko → PR`까지 포함된다 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | bash 호환성 | bash 3.2+ (release.sh 기존 NFR 준수 — `_sed_i` 래퍼 사용) |
| NFR-2 | 기존 테스트 회귀 | `bash scripts/tests/test-release.sh` T1~T9 전체 PASS |
| NFR-3 | 거버넌스 테스트 회귀 | `bash scripts/tests/governance/test-rules.sh` 전체 PASS |
| NFR-4 | 구조 검증 | `bash scripts/_internal/validate-structure.sh` 전체 ✅ PASS |

## 6. 제약사항

- `release.sh` 수정 시 `_sed_i` 크로스플랫폼 래퍼 (L40~50 정의) 사용 — `sed -i` 직접 호출 금지
- `apply_gbrain_absence_rule` 함수 본체 삭제 금지 (load_rules 레이어 비활성화만)
- `test-rules.sh` T-R6.1~T-R6.5 케이스는 함수 직접 호출이라 enabled=false 영향 없음 — 수정 불필요

## 7. 설계 메모

**release.sh FR-7 삽입 위치**: L111 (README 버전 갱신 블록) 직후. 패턴:
```bash
# FR-7: plugin.json/marketplace.json 버전 bump
for manifest in "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
                "$PLUGIN_ROOT/.claude-plugin/marketplace.json"; do
  [ -f "$manifest" ] || continue
  _sed_i "s/\"version\": \"[0-9][^\"]*\"/\"version\": \"${VERSION}\"/" "$manifest"
  CHANGED_FILES+=("$manifest")
done
```

**T1-a 즉시 수정**: jq 미의존, `sed` 직접 패치 또는 Python 3 `json` 모듈 1-liner. `_sed_i` 사용.

**T2 R-6 비활성화**: `"enabled": true` → `"enabled": false` 1자 변경. `load_rules` (governance-lib.sh:88)가 `enabled=true` 필터링하므로 stop-governance 경로에서 자동 제외.

## 참조

- `.specops/20260609-release-manifest-r6-doc-fix/current-state.md`
- `.specops/20260609-release-manifest-r6-doc-fix/impact-analysis.md`
- `scripts/release.sh` — 핵심 구현 (L40 `_sed_i`, L107~111 README bump 패턴)
- `hooks/governance-lib.sh:88` — `load_rules` enabled 필터
- `hooks/rules.jsonl` — R-6 행
- `scripts/tests/governance/test-rules.sh:30` — T5.c stop 카운트 어서션

---

*작성: specifying-ko (유지보수 분기) · 2026-06-09 · FID: 20260609-release-manifest-r6-doc-fix*
