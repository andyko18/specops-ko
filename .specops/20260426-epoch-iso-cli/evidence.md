# 검증 증거 — 20260426-epoch-iso-cli

**검증 시각**: 2026-04-26
**검증자**: verifying-evidence-ko

## 1. 테스트 스위트 전체 실행

```
$ bash scripts/tests/test-epoch.sh

PASS T1.a epoch-sec-to-iso
PASS T1.b epoch-ms-to-iso
PASS T2.a iso-to-epoch-sec
PASS T2.b iso-ms-to-epoch-ms
PASS T3.a stdin
PASS T4.a invalid-input
PASS T4.b --help
PASS T4.c plus00-offset
--- SUMMARY ---
PASS=8 FAIL=0
```

exit 0 확인. FAIL=0.

## 2. AC 체크리스트 (직접 실행)

| AC | must/should | 기대값 | 실측 out | rc | 판정 |
|---|---|---|---|---|---|
| AC-1 | must | `2026-04-26T00:00:00Z` | `2026-04-26T00:00:00Z` | 0 | ✅ |
| AC-2 | must | `2026-04-26T00:00:00.123Z` | `2026-04-26T00:00:00.123Z` | 0 | ✅ |
| AC-3 | must | `1777161600` | `1777161600` | 0 | ✅ |
| AC-4 | must | `1777161600123` | `1777161600123` | 0 | ✅ |
| AC-5 | must | `2026-04-26T00:00:00Z` | `2026-04-26T00:00:00Z` | 0 | ✅ |
| AC-6 | must | stdout 비어있음, rc=1 | stdout=`''`, rc=1 | 1 | ✅ |
| AC-7 | should | "Usage" 포함, rc=0 | `Usage: epoch.sh [VALUE]...` 포함 | 0 | ✅ |
| AC-8 | should | `1777161600` | `1777161600` | 0 | ✅ |

**must AC 전체 PASS: 6/6**
**should AC 전체 PASS: 2/2**

## 3. 회귀 테스트 (slug.sh)

```
$ bash scripts/tests/test-slug.sh

...
PASS=10 FAIL=0
```

기존 slug.sh 테스트 영향 없음 확인.

## 4. 커밋 이력

```
1748403 fix(epoch-iso): M-1 epoch(ms) date 실패 시 빈 iso_sec 무검사 방어
5dbfafb test(epoch-iso): T4.a AC-6 stdout 비어있음 조건 명시 검증
e2e3d54 feat(epoch-iso): T4 ISO(ms)·+00:00·stdin·에러·help — AC-1~8 PASS
59a6294 feat(epoch-iso): T3 ISO(Z)→epoch 초 변환
27baad4 feat(epoch-iso): T2 epoch(밀리초)→ISO 변환
cec5801 feat(epoch-iso): T1 테스트 스켈레톤 + epoch(초)→ISO 변환
```

## 5. 검증 불가 항목

| 항목 | 이유 |
|---|---|
| Linux GNU date 동작 | macOS 환경 — GNU date 실측 불가. spec §7 가정으로 기록됨 |

## 최종 판정

**VERIFIED** — 모든 must AC 6/6 충족, should AC 2/2 충족, 회귀 없음.

---

*작성: verifying-evidence-ko · 2026-04-26 · FID: 20260426-epoch-iso-cli*
