# Clarifications — 20260427-design-md

**status**: RESOLVED
**timestamp**: 2026-04-26T23:00+09:00

---

## Q1 · dogfood-brand · DESIRABLE

**질문**: specops-auto-ko 프로젝트 루트에 생성할 실제 DESIGN.md의 브랜드 스타일을 어떤 것으로 할까요?

**답변**: Claude 브랜드 (AI 친화·보라 계열·미니멀). specops-auto-ko가 Claude 기반 도구이므로 추천을 채택.

**영향**: AC-6 dogfood 생성 시 Claude 브랜드 스타일 적용. AC 수정 없음 (구조 조건 동일).

---

## Q2 · ui-detection · RESOLVED (by spec assumption)

**질문**: specifying-ko에서 UI 컴포넌트 포함 여부를 어떻게 판단할까?

**답변**: spec.md §7 가정에 이미 명시 — "DESIGN.md 존재 여부 확인(파일 체크)만 수행". UI 컴포넌트 자동 감지 불필요. DESIGN.md가 있으면 무조건 참조 포함.

**영향**: AC 추가 없음.

---

## 판정 요약

```json
{
  "fid": "20260427-design-md",
  "status": "RESOLVED",
  "blocking_count": 0,
  "desirable_count": 1,
  "resolved_count": 2,
  "new_ac_appended": 0
}
```
