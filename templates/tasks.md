<!-- FID: <YYYYMMDD-kebab-slug> -->
<!-- OWNER_COMMAND: /tasks -->
<!-- MUTABLE_BY: /implement (상태 마킹만) -->
<!-- reference_upstream: github/spec-kit tasks-template.md + obra/superpowers writing-plans -->
<!-- layer: Lifecycle-Artifact -->

# <기능명> 태스크 목록 — <FID>

> 각 태스크는 TDD 5 스텝(RED → 검증 → GREEN → 검증 → COMMIT)을 따릅니다. `/implement`가 체크박스를 마킹합니다.

**관련 플랜**: `.specops/<FID>/plan.md`
**관련 AC**: AC-1, AC-2, ...

---

## 태스크 1: <컴포넌트 이름>

**파일**:
- Create: `src/<경로>.py`
- Test: `tests/test_<경로>.py`

**관련 AC**: AC-1

- [ ] **스텝 1: 실패하는 테스트 작성**

```python
def test_<행동>():
    result = <함수>(<입력>)
    assert result == <기대>
```

- [ ] **스텝 2: 테스트 실패 확인**

실행: `pytest tests/test_<경로>.py::test_<행동> -v`
기대: FAIL — `<함수>` 정의되지 않음

- [ ] **스텝 3: 최소 구현**

```python
def <함수>(<입력>):
    return <기대>
```

- [ ] **스텝 4: 테스트 통과 확인**

실행: `pytest tests/test_<경로>.py::test_<행동> -v`
기대: PASS

- [ ] **스텝 5: 커밋**

```bash
git add tests/test_<경로>.py src/<경로>.py
git commit -m "feat(<scope>): <무엇을>

<왜 — 2~3줄>

관련 AC: AC-1"
```

---

## 태스크 2: <컴포넌트 이름>

**파일**:
- Modify: `src/<경로>.py:<라인>`
- Test: `tests/test_<경로>.py`

**관련 AC**: AC-2

- [ ] **스텝 1: ...**
- [ ] **스텝 2: ...**
- [ ] **스텝 3: ...**
- [ ] **스텝 4: ...**
- [ ] **스텝 5: ...**

---

## 태스크 N: <파괴적 작업 — 문지기 체크>

⚠️ **사용자 승인 필요** — 이 태스크는 되돌리기 어려운 변경을 포함합니다.

**파일**:
- Delete: `기존/삭제대상.py`

**확인 사항**:
- [ ] 이 파일을 참조하는 다른 코드가 없는가?
- [ ] 삭제 전 git diff로 마지막 확인했는가?
- [ ] 사용자가 명시 승인했는가?

- [ ] **스텝 1: ...**

---

## 진행 상태

총 태스크 수: <N>
완료: 0 / <N>
차단: 0

## 참조

- `skills/tdd-ko/SKILL.md` — TDD 5 스텝
- `skills/writing-plans-ko/SKILL.md` — 바이트-사이즈 규칙
- `skills/sprint-contracts/SKILL.md` — AC 매핑

---

*작성: <작성자> · <날짜> · FID: <FID> · 생성 커맨드: /tasks*
