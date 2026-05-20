
## run-verification.sh (2026-05-19 10:04:16)

### `bash scripts/tests/test-visual-companion.sh`
```
T1.a PASS: server.cjs 존재
T1.b PASS: package.json ws 의존성
T2.a PASS: start-server.sh exec-bit
T3.a PASS: stop-server.sh exec-bit
T4.a PASS: frame-template.html WebSocket+content
T5.a PASS: helper.js sendToVisualCompanion + 오류 처리
T6.a PASS: specifying-ko 포팅 주석 없음 + 사용 가이드 존재

PASS=7 FAIL=0
```
exit: 0

## 회귀 검증 (2026-05-19 10:04:30)

### `bash scripts/tests/test-skill-conventions.sh`
```
PASS T1.a SKILL.md 개수 ≥ 23 (실측: 25)
PASS T2.a 모든 SKILL.md frontmatter 6 필드 전부 비어있지 않게 존재
PASS T3.a layer 값 유효 (1|2|3만 허용)
PASS T4.a layer=2 chain skill 전부 ## 5원칙 주입 보유
PASS T5.a layer=2 ## 다음 skill 보유 수 ≥ 10 (실측: 15)

--- SUMMARY ---
PASS=5 FAIL=0
```

### `bash scripts/_internal/validate-structure.sh`
```
✅ directories: OK
✅ file_counts: OK
✅ meta_injection: OK
✅ frontmatter: OK
✅ no_superpowers: OK
✅ manifest: OK (both=1.2.0)
ℹ️  ref_upstream_fmt: struct=31/31
✅ skill_conventions: OK
```
