<!-- specops-ko Wave 2 U2 — fixture for B4 (extract-test-commands.sh) -->
<!-- 케이스: YAML 안에 test_command 미기재 — Step 4 라인 fallback + stderr WARN -->

# Tasks — fallback-step4 fixture

## Task T1: 구 FID 호환 task (YAML test_command 미기재)

- [ ] **Step 4: PASS 검증**

실행: `bash scripts/tests/test-fromstep4.sh`

---

## 의존 그래프

```yaml
tasks:
  - id: T1
    ac: [AC-1]
    depends_on: []
    inputs: []
    outputs: []
```
