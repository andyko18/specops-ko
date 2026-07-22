<!-- specops-ko Wave 2 U2 — fixture for B4 (extract-test-commands.sh) -->
<!-- 케이스: YAML test_command 우선 — Step 4 라인이 있어도 YAML 이 우선 -->

# Tasks — yaml-primary fixture

## Task T1: 샘플 task

- [ ] **Step 4: PASS 검증**

실행: `bash scripts/tests/test-shouldnot.sh`

(이 Step 4 inline 명령은 YAML test_command 가 존재할 때 무시되어야 한다.)

---

## 의존 그래프

```yaml
tasks:
  - id: T1
    test_command: "bash scripts/tests/test-fromyaml.sh"
    ac: [AC-1]
    depends_on: []
    inputs: []
    outputs: []
```
