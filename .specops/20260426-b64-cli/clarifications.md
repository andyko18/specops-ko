# Clarifications — 20260426-b64-cli

**status**: RESOLVED
**timestamp**: 2026-04-26T00:00:00+09:00

## Q1 · 빈 문자열 입력 처리 · DESIRABLE

**질문**: `b64enc.sh ""`와 `b64val.sh ""`에 빈 문자열이 들어올 때 어떻게 처리할까요?
옵션 a) 인코더: 빈 결과 출력 + exit 0 / 검증기: `invalid: empty input` + exit 1
옵션 b) 인코더: 빈 결과 출력 + exit 0 / 검증기: `valid` + exit 0
옵션 c) 인코더·검증기 모두: `invalid: empty input` + exit 1

**답변**: a — 인코더는 빈 인코딩 허용, 검증기는 빈 입력 거부

**영향**: AC-11 (b64enc.sh 빈 문자열), AC-12 (b64val.sh 빈 문자열) 신규 추가

---

## Q2 · 검증기 줄바꿈 문자 처리 · DESIRABLE

**질문**: `b64val.sh`에 `\n` 포함 입력이 들어올 때 처리 방식

**답변**: 자동 해소 — `\n`은 허용 문자셋 `[A-Za-z0-9+/=]` 밖이므로 `invalid: invalid characters`로 자동 처리됨. 별도 분기 불필요.

**영향**: 없음 (기존 AC-8 커버)

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-b64-cli · 생성 커맨드: /clarify*
