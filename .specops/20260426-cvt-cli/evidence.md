<!-- FID: 20260426-cvt-cli -->
<!-- OWNER_COMMAND: /verify -->
<!-- layer: Lifecycle-Artifact -->

# 검증 증거 — 20260426-cvt-cli

**검증 일시**: 2026-04-26
**검증자**: verifying-evidence-ko
**대상 커밋**: `2bcfa79` feat(cvt T1-T5)

---

## 1. 테스트 전체 실행 (fresh)

**명령**: `bash scripts/tests/test-cvt.sh`

```
PASS T1.a --to 누락 exit 2
PASS T2.a exit 0
PASS T2.b stdout valid YAML
PASS T2.c stdin pipe exit 0
PASS T2.d stderr empty
PASS T3.a YAML→JSON exit 0
PASS T3.b stdout valid JSON
PASS T4.a bad JSON exit 1
PASS T4.b stderr ParseError:
PASS T4.c empty JSON→YAML exit 1
PASS T4.d stderr ParseError:
PASS T4.e empty YAML→JSON exit 1
PASS T4.f stderr ParseError:
PASS T5.a --indent 4 applied
PASS T5.b --indent 4 valid JSON
--- SUMMARY ---
PASS=15 FAIL=0
```

**결과**: ✅ PASS=15 FAIL=0

---

## 2. exec-bit (NFR-4) 확인

**명령**: `stat -f "%Sp" scripts/cvt.py && stat -f "%Sp" scripts/tests/test-cvt.sh`

```
-rwxr-xr-x
-rwxr-xr-x
```

**결과**: ✅ 두 파일 모두 exec-bit 755

---

## 3. 직접 실행 검증

### JSON → YAML

**명령**: `echo '{"hello":"world","num":42}' | python3 scripts/cvt.py --to yaml`

```
hello: world
num: 42
```

### YAML → JSON

**명령**: `printf 'hello: world\nnum: 42\n' | python3 scripts/cvt.py --to json`

```
{
  "hello": "world",
  "num": 42
}
```

### 빈 입력 ParseError

**명령**: `echo -n "" | python3 scripts/cvt.py --to yaml 2>&1; echo "exit:$?"`

```
ParseError: 빈 입력
exit:1
```

**결과**: ✅ 3가지 시나리오 독립 실행 확인

---

## 4. VCS diff 확인

**명령**: `git diff HEAD~2..HEAD --stat`

```
.specops/20260426-cvt-cli/dispatch-log.md          |  44 ++++
.specops/20260426-cvt-cli/dispatch/T1-T5-context.md | 263 +++++++++++++++++++
.specops/20260426-cvt-cli/tasks.md                  |  52 ++--
scripts/cvt.py                                      |  55 +++++
scripts/tests/test-cvt.sh                           |  83 +++++++
5 files changed, 471 insertions(+), 26 deletions(-)
```

**결과**: ✅ `scripts/cvt.py` (55 LOC) + `scripts/tests/test-cvt.sh` (83 LOC) 실제 생성 확인

---

## 5. AC 커버리지 체크리스트

| AC | 우선순위 | 커버 테스트 | 상태 |
|---|---|---|---|
| AC-1 JSON→YAML 파일 | must | T2.a(exit 0) + T2.b(valid YAML) | ✅ |
| AC-2 YAML→JSON 파일 | must | T3.a(exit 0) + T3.b(valid JSON) | ✅ |
| AC-3 stdin 파이프 | must | T2.c(stdin exit 0) | ✅ |
| AC-4 깨진 JSON ParseError | must | T4.a(exit 1) + T4.b(stderr) | ✅ |
| AC-5 --to 누락 exit 2 | must | T1.a(exit 2) | ✅ |
| AC-6 빈 JSON→YAML ParseError | must | T4.c(exit 1) + T4.d(stderr) | ✅ |
| AC-7 --indent 플래그 | should | T5.a(4칸) + T5.b(valid JSON) | ✅ |
| AC-8 정상 시 stderr 없음 | must | T2.d(stderr empty) | ✅ |
| AC-9 빈 YAML→JSON ParseError | must | T4.e(exit 1) + T4.f(stderr) | ✅ |
| AC-10 DependencyError | nice-to-have | 코드 구현됨, 테스트 없음 | 검증 불가 (가상환경 필요) |

**must AC**: 8/8 ✅ | **should AC**: 1/1 ✅ | **nice-to-have**: 검증 불가 (가상환경 없음)

---

## 6. Phase B·C 리뷰 요약

| Phase | 에이전트 | 판정 |
|---|---|---|
| B (스펙 준수) | spec-reviewer-ko | PASS — AC-1~AC-9 전체 MET |
| C (코드 품질) | code-reviewer-ko | READY_TO_MERGE — Critical 0, Important 3(비차단) |

---

## 종합 판정

**PASS** — 검증 근거 있음

- 테스트: PASS=15 FAIL=0 (fresh 실행)
- exec-bit: 755 (두 파일 모두)
- must AC: 8/8 충족
- should AC: 1/1 충족
- Phase B/C: PASS + READY_TO_MERGE

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-cvt-cli · 생성 커맨드: /verify*
