<!-- FID: 20260426-cvt-cli -->
<!-- OWNER_COMMAND: /clarify -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260426-cvt-cli

**status**: RESOLVED
**timestamp**: 2026-04-26T00:00:00+09:00

---

## Q1 · 빈 YAML → JSON 방향 동작 · BLOCKING

**질문**: `yaml.safe_load("")`는 예외 없이 `None`을 반환한다. 빈 YAML 입력을 `null` JSON으로 출력할 것인가, ParseError로 처리할 것인가?

**답변**: ParseError + exit 1 (빈 입력은 방향 불문 에러로 통일)

**영향**: AC-9 신규 추가 — 빈 YAML→JSON 방향도 ParseError + exit 1

---

## Q2 · PyYAML 미설치 에러 메시지 · DESIRABLE

**질문**: PyYAML 미설치 시 Python ImportError를 그대로 노출할 것인가, 사용자 친화적 메시지로 래핑할 것인가?

**답변**: `DependencyError: pyyaml 미설치. pip install pyyaml` + exit 1

**영향**: AC-10 신규 추가 (nice-to-have)

---

## Q3 · YAML 다중 문서(`---` 복수) 동작 · DESIRABLE

**질문**: YAML 다중 문서 입력 시 전체 처리, 첫 문서만, 또는 에러?

**답변**: 첫 번째 문서만 변환, 나머지 무시, stderr 경고 없음

**영향**: AC 신규 없음. 구현 가이드: `yaml.safe_load()` (= 첫 문서만) 사용, `yaml.safe_load_all()` 사용 금지

---

*작성: kohaedong · 2026-04-26 · FID: 20260426-cvt-cli · 생성 커맨드: /clarify*
