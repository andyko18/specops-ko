
## run-verification.sh (2026-05-18 13:49:53)

### `bash scripts/_internal/validate-structure.sh`
```
✅ directories: OK
✅ file_counts: OK
✅ meta_injection: OK
✅ frontmatter: OK
✅ no_superpowers: OK
✅ manifest: OK (both=1.2.0)
ℹ️  ref_upstream_fmt: struct=29/29
```
exit: 0

### `bash scripts/tests/test-memory-references.sh`
```
PASS T1.a SKILL.md 가 9종 .specops/memory/*.md 모두 명시 (감지 표)
PASS T2.a SKILL.md 본문 — spec.md §참조 인용 + graceful skip + 회귀 보호 명시
PASS T3.a .specops/memory/ 부재 → ls 빈 결과 (graceful skip 전제 보장 — 기존 dogfood 회귀 보호)
PASS T4.a 부분 존재 → ls 가 존재하는 3종만 반환 (constitution/requirements/test-strategy)
PASS T5.a SKILL.md — CONTEXT.md 자동 감지 명시
PASS T6.a SKILL.md — docs/adr/ 자동 감지 명시

--- SUMMARY ---
PASS=6 FAIL=0
```
exit: 0

