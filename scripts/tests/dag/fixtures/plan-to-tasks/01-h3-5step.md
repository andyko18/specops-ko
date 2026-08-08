# 표준형 plan

## 2. 파일 구조

### Task 1: 첫 컴포넌트

**파일**:
- 생성: `src/a.sh`
- 테스트: `tests/test-a.sh`

- [ ] **Step 1: 실패 테스트 작성**

```bash
echo "assert a" >&2
```

- [ ] **Step 2: 실패 확인 실행**

실행: `bash tests/test-a.sh`
예상: FAIL

- [ ] **Step 3: 최소 구현 작성**

```bash
a() { echo ok; }
```

- [ ] **Step 4: 통과 확인 실행**

실행: `bash tests/test-a.sh`
예상: PASS

- [ ] **Step 5: 커밋**

```bash
git commit -m "feat: a"
```

## 6. 위험과 완화

- 여기는 Task 블록 밖이다 — 골격에 들어가면 안 된다.
