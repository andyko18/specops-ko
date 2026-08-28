<!-- FID: <FID> -->
<!-- OWNER_COMMAND: /clarify -->
<!-- reference_upstream: specops-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# 명확화 기록 — <FID>

## Q1-BLOCKING: 인자가 여러 개일 때 동작

**질문**: greet-cli.sh에 인자를 여러 개 전달하면 어떻게 처리하는가?

**답변**: 첫 번째 인자만 사용한다. 나머지 인자는 무시.

**상태**: RESOLVED (AC 변경 없음)

---

## Q1-DESIRABLE: 빈 문자열 인자 처리

**질문**: `greet-cli.sh ""` 처럼 빈 문자열을 전달하면 어떻게 처리하는가?

**답변**: 오류로 처리한다. "이름을 입력해 주세요." 메시지 + exit 1.

**상태**: RESOLVED (AC-3 신설)

---

*작성: e2e-test-ko · <날짜> · FID: <FID> · 생성 커맨드: /e2e-test*
