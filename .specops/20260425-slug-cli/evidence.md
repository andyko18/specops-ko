# 검증 증거 — 20260425-slug-cli

**검증 일시**: 2026-04-25
**검증자**: verifying-evidence-ko
**FID**: 20260425-slug-cli

---

## 1. 테스트 스위트 실행 (fresh)

**명령**: `bash scripts/tests/test-slug.sh`

**출력**:
```
PASS T1.a --help
PASS T2.a uppercase
PASS T2.b spaces
PASS T2.c special-chars
PASS T3.a 한글-only
PASS T3.b 혼합
PASS T3.c 영문+한글
PASS T4.a 빈-입력
PASS T4.b stdin-pipe
--- SUMMARY ---
PASS=9 FAIL=0
EXIT:0
```

**결과**: PASS (9/9, exit 0)

---

## 2. VCS diff 확인 (변경이 실제로 일어남)

**명령**: `git diff 4ca28fa~1..1f8d53f --stat`

**출력**:
```
scripts/slug.sh            | 97 ++++...
scripts/tests/test-slug.sh | 81 ++++...
2 files changed, 178 insertions(+)
```

**결과**: 2개 파일 생성 확인

---

## 3. exec-bit 확인

**명령**: `stat -f "%Sp %N" scripts/slug.sh scripts/tests/test-slug.sh`

**출력**:
```
-rwxr-xr-x scripts/slug.sh
-rwxr-xr-x scripts/tests/test-slug.sh
```

**결과**: 두 파일 모두 755 실행 권한 확인

---

## 4. AC별 검증 방법 직접 실행

| AC | 검증 명령 | 실측 출력 | 판정 |
|---|---|---|---|
| AC-1 | `slug.sh "안녕"` | `annyeong` | ✅ PASS |
| AC-2 | `slug.sh "Hello World"` | `hello-world` | ✅ PASS |
| AC-3 | `slug.sh "안녕 World 2024"` | `annyeong-world-2024` | ✅ PASS |
| AC-4 | `slug.sh "  hello   world  "` | `hello-world` | ✅ PASS |
| AC-5 | `printf 'Hello 세계' \| slug.sh` | `hello-segye` | ✅ PASS |
| AC-6 | `slug.sh --help` | Usage 포함, exit 0 | ✅ PASS |
| AC-7 | `slug.sh "hello!@#world"` | `hello-world` | ✅ PASS |
| AC-8 | `slug.sh ""` | `''`, exit 0 | ✅ PASS |

**must AC 전원 충족**: 7/7 (AC-6 should 포함 8/8)

---

## 5. 종합 판정

- 테스트 스위트: PASS=9 FAIL=0 (exit 0) ✅
- VCS diff: 2개 파일 178행 생성 확인 ✅
- exec-bit: 두 파일 755 ✅
- AC 직접 검증: 8/8 전원 충족 ✅

**완료 선언 조건 충족** — 증거 기반 검증 통과.

---

*작성: verifying-evidence-ko · 2026-04-25 · FID: 20260425-slug-cli*
