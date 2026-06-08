<!-- FID: 20260609-release-manifest-r6-doc-fix -->
<!-- OWNER_COMMAND: /clarify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260609-release-manifest-r6-doc-fix

**status**: RESOLVED
**timestamp**: 2026-06-08T23:33:55Z

## BLOCKING 탐지 결과

BLOCKING 없음. spec 전 항목 명확.
- `_sed_i` 패턴 시뮬레이션 PASS (`"version": "[0-9][^"]*"` → v1.10.0 정확 치환)
- T1/T2/T4 변경 대상·범위·방법 전부 결정됨

---

## Q1 · CHANGELOG 상세 수준 · DESIRABLE

**질문**: v1.10.0 섹션을 PR 제목 요약만 할지, v1.9.0 스타일(기능별 bullet 상세 나열)로 작성할지.

**답변**: 기본값 — 기존 스타일 준수 (상세 나열). v1.9.0 entry처럼 Added/Changed 섹션으로 구분하고 기능별 bold bullet 기재.

**영향**: CHANGELOG 백필 구현 시 v1.9.0 포맷 그대로 복제.

---

## Q2 · R-6 description 갱신 · DESIRABLE

**질문**: `rules.jsonl` R-6 `"description"` 필드를 "비활성화 — gbrain-ko manual-only 설계 우선" 등으로 갱신할지.

**답변**: 기본값 — 갱신 안 함. `"enabled": false` 변경만. `governance-lib.sh` 함수 주석(L318~325)이 의도를 이미 설명. description 텍스트 수정 추가 불필요.

**영향**: 없음. AC 변경 없음.
