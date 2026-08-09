# 양성 — 선-green 단정에 실측 근거 없음

### Task 1: 배선

- [ ] **Step 1: 실패 테스트 작성**

```bash
grep -q 'wiring-token' "$D" && ok "배선" || nope "부재"
```

- [ ] **Step 2: 실패 확인 실행**

실행: `bash scripts/tests/test-x.sh`
예상: `FAIL T13` — 배선 부재. T14·T15 는 기존 본문에 이미 그 문자열들이 있으므로 **PASS 로 시작한다**.

- [ ] **Step 3: 최소 구현 작성**

```bash
echo 'wiring-token' >> "$D"
```
