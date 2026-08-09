# 음성 — 생성과 어서션이 같은 줄

### Task 1: 한 줄

- [ ] **Step 1: 실패 테스트 작성**

```bash
echo 'QQZ-ONELINE-TOKEN-991' >> "$OUT" && grep -q 'QQZ-ONELINE-TOKEN-991' "$OUT"
```

- [ ] **Step 2: 실패 확인 실행**

실행: `bash t.sh`
예상: FAIL
