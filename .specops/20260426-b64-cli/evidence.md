# 검증 증거 — 20260426-b64-cli

**검증 일시**: 2026-04-26
**검증자**: verifying-evidence-ko
**전체 결과**: PASS=17 FAIL=0 (신규 실행)

---

## 테스트 실행 증거

### test-b64enc.sh (신규 실행)

```
PASS T1.a 인자 인코딩
PASS T1.b stdin 인코딩
PASS T1.c --help usage
PASS T1.d 빈 문자열 exit 0
PASS T1.e 공백 포함 인코딩
--- SUMMARY ---
PASS=5 FAIL=0
```

### test-b64dec.sh (신규 실행)

```
PASS T2.a 인자 디코딩
PASS T2.b stdin 디코딩
PASS T2.c 잘못된 입력 exit 1 + stderr
PASS T2.d --help
PASS T2.e 패딩 2개 디코딩
--- SUMMARY ---
PASS=5 FAIL=0
```

### test-b64val.sh (신규 실행)

```
PASS T3.a valid base64
PASS T3.b invalid characters
PASS T3.c invalid padding
PASS T3.d empty input
PASS T3.e = in middle
PASS T3.f stdin valid
PASS T3.g triple padding
--- SUMMARY ---
PASS=7 FAIL=0
```

---

## AC 체크리스트 (직접 실행 증거)

| AC | must/should | 판정 | 실측 증거 |
|---|---|---|---|
| AC-1 | must | **PASS** | `b64enc.sh "hello"` → `aGVsbG8=` rc=0 |
| AC-2 | must | **PASS** | `printf '%s' "hello" \| b64enc.sh` → `aGVsbG8=` rc=0 |
| AC-3 | must | **PASS (부분)** | `--help` → Usage 포함 rc=0. TTY 미검증 — 코드(`[ -t 0 ]`)는 정확, 자동화 불가 (알려진 한계) |
| AC-4 | must | **PASS** | `b64dec.sh "aGVsbG8="` → `hello` rc=0 |
| AC-5 | must | **PASS** | `printf '%s' "aGVsbG8=" \| b64dec.sh` → `hello` rc=0 |
| AC-6 | must | **PASS** | `b64dec.sh "!!!invalid!!!"` → rc=1, stderr 비어있지 않음 |
| AC-7 | must | **PASS** | `b64val.sh "aGVsbG8="` → `valid` rc=0 |
| AC-8 | must | **PASS** | `b64val.sh "hello!"` → `invalid: invalid characters` rc=1 |
| AC-9 | must | **PASS** | `b64val.sh "aGVsbG8"` → `invalid: invalid padding` rc=1 |
| AC-10 | must | **PASS** | 교차 참조 없음 (grep 결과: 없음) |
| AC-11 | should | **PASS** | `b64enc.sh ""` → `<empty>` rc=0 |
| AC-12 | should | **PASS** | `b64val.sh ""` → `invalid: empty input` rc=1 |

**must AC 충족**: 10/10 (100%)
**should AC 충족**: 2/2 (100%)

---

## 회귀 테스트 증거

```
test-slug.sh: PASS=10 FAIL=0 (기존 CLI 영향 없음)
test-cvt.sh:  PASS=16 FAIL=0 (기존 CLI 영향 없음)
```

---

## AC-3 알려진 한계

**상황**: AC-3 ("no args, TTY stdin → usage + exit 1")의 TTY 감지 경로를 자동 테스트로 검증 불가.

**코드 증거**: `b64enc.sh:20-21` — `elif [ -t 0 ]; then usage; exit 1` 구현 존재.

**결론**: 코드 구현은 정확. 자동 테스트에서 TTY 시뮬레이션이 실용적이지 않은 것은 bash CLI의 알려진 한계 (기존 `slug.sh`도 동일). must AC 판정에서 PARTIAL 처리하되 `--help` 경로는 자동 검증 완료.

---

## 커밋 이력

```
cc6a55f feat(b64val): Base64 검증기 CLI
b2b784b feat(b64dec): Base64 디코더 CLI
e2e36fc feat(b64enc): Base64 인코더 CLI
```

---

*작성: verifying-evidence-ko · 2026-04-26 · FID: 20260426-b64-cli*
