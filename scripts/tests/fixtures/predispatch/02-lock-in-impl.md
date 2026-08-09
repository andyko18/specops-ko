# 음성 — 이 plan 이 만드는 문자열

### Task 1: 신규

- [ ] **Step 1: 실패 테스트 작성**

```bash
grep -q 'brand-new-thing.sh' "$D" && ok "배선" || nope "부재"
```

- [ ] **Step 2: 실패 확인 실행**

```
FAIL — 배선 부재
```

- [ ] **Step 3: 최소 구현 작성**

```bash
bash scripts/brand-new-thing.sh <FID>
```
