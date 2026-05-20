# Clarifications — 20260426-epoch-iso-cli

**status**: RESOLVED
**timestamp**: 2026-04-26T00:00:00Z

## Q1 · Linux date Z suffix 동작 · DESIRABLE

**질문**: Linux에서 `date -d "2026-04-26T00:00:00Z" +%s` 가 올바르게 동작하는지 확인 필요

**답변**: GNU date(Linux) 는 ISO 8601 `Z` suffix를 UTC로 파싱하는 것이 문서화된 동작. macOS 환경 외 실측 불가이므로 §가정으로 기록하고 진행.

**영향**: 없음 (spec §7 가정 항목으로 이미 기록됨)

---

## Q2 · 빈 입력 exit code · BLOCKING → RESOLVED

**질문**: 빈 입력 처리 — 빈 문자열 출력 후 exit 0 vs exit 1

**답변**: spec FR-8 "인식 불가 입력 시 stderr에 에러 메시지를 출력하고 exit 1한다"에 의해 자기 해소. 빈 문자열은 인식 불가 입력이므로 exit 1.

**영향**: AC-6 커버 (기존 AC 수정 없음)

---

## Q3 · +00:00 offset 입력 지원 · DESIRABLE (신규 발굴)

**질문**: FR-3이 "Z 또는 +00:00 suffix"를 명시하나 AC에 `+00:00` 입력 케이스가 없음

**답변**: AC-8 신규 추가로 커버

**영향**: AC-8 append

---

*작성: clarifying-ko · 2026-04-26 · FID: 20260426-epoch-iso-cli*
