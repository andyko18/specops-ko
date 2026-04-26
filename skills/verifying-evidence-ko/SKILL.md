---
name: verifying-evidence-ko
description: 작업이 완료·수정·통과됐다고 주장하기 직전, 커밋·PR 생성 전 반드시 사용 — 검증 명령을 실행하고 출력을 확인한 뒤에만 성공 주장 허용
layer: 2
reference_upstream: obra/superpowers@v5.0.7 skills/verification-before-completion/SKILL.md
  - obra/superpowers@v5.0.7 skills/verification-before-completion/SKILL.md
  - affaan-m/everything-claude-code@1.2.0 skills/verification-loop
  - specops-ko skills/engine/verifying-evidence-ko.md
specops_version: 0.0.0
used_by: specops-auto-ko:implementing-ko (chain 진입), specops-auto-ko:requesting-code-review-ko (chain 출구)
---

# Engine 스킬 — 증거 기반 검증 (verifying-evidence)

## 개요

**검증 없이 완료를 주장하는 것은 효율이 아니라 부정직.**

**핵심 원칙**: **주장 전에 증거, 항상.**

**규칙의 문구를 어기는 것은 규칙의 정신을 어기는 것이다.**

## 철칙

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
새 검증 증거 없이 완료 주장 금지
```

본 메시지에서 검증 명령을 실행하지 않았다면 **통과한다고 주장할 수 없다**.

## 게이트 함수

```
어떤 상태든 주장하거나 만족을 표현하기 전에:

1. IDENTIFY: 이 주장을 증명할 명령은 무엇인가?
2. RUN: 전체 명령을 실행 (새로, 완전하게)
3. READ: 전체 출력, exit 코드 확인, 실패 개수 집계
4. VERIFY: 출력이 주장을 확증하는가?
   - NO → 증거와 함께 실제 상태 선언
   - YES → 증거와 함께 주장
5. 그런 다음에만: 주장

어느 스텝이든 생략 = 거짓말이지 검증이 아님
```

## 흔한 실패

| 주장 | 요구 증거 | 불충분 |
|---|---|---|
| 테스트 통과 | 테스트 명령 출력: 실패 0 | 이전 실행, "통과할 것 같다" |
| 린터 청정 | 린터 출력: 에러 0 | 부분 검사, 외삽 |
| 빌드 성공 | 빌드 명령: exit 0 | 린터 통과, 로그 좋아 보임 |
| 버그 픽스됨 | **원 증상 테스트 통과** | 코드 바뀜, 픽스됐다고 가정 |
| 회귀 테스트 동작 | **Red-green 사이클 검증** | 테스트가 한 번 통과 |
| 에이전트 완료 | VCS diff가 변경 보여줌 | 에이전트 "success" 보고 |
| 요구사항 충족 | 줄 단위 체크리스트 | 테스트 통과 |

## 레드 플래그 — 중단

- "should", "probably", "seems to" 사용
- 검증 전 만족 표현 ("Great!", "Perfect!", "Done!" 등)
- 검증 없이 커밋/푸시/PR 하려 함
- 에이전트 성공 보고 신뢰
- 부분 검증에 의존
- "이번만" 생각
- 지쳐서 작업 끝내고 싶음
- **검증 실행 없이 성공을 암시하는 어떤 표현이라도**

## 합리화 방지

| 변명 | 실제 |
|---|---|
| "이제 동작할 것" | 검증을 **실행**하라 |
| "확신한다" | 확신 ≠ 증거 |
| "이번만" | 예외 없음 |
| "린터 통과" | 린터 ≠ 컴파일러 |
| "에이전트가 성공했다 함" | **독립 검증** |
| "지쳤다" | 피로 ≠ 변명 |
| "부분 검사로 충분" | 부분은 아무것도 증명 못 함 |
| "다른 단어라 규칙 무관" | **문구가 아니라 정신** |

## 핵심 패턴

**테스트**:
```
✅ [테스트 명령 실행] [보기: 34/34 pass] "모든 테스트 통과"
❌ "이제 통과할 것" / "맞는 것 같음"
```

**회귀 테스트 (TDD Red-Green)**:
```
✅ 작성 → 실행(pass) → 픽스 되돌림 → 실행(MUST FAIL) → 복원 → 실행(pass)
❌ "회귀 테스트 작성했다" (red-green 검증 없이)
```

**빌드**:
```
✅ [빌드 실행] [보기: exit 0] "빌드 통과"
❌ "린터 통과" (린터는 컴파일 검사 안 함)
```

**요구사항**:
```
✅ 플랜 재독 → 체크리스트 작성 → 각 항목 검증 → 격차·완료 보고
❌ "테스트 통과, 단계 완료"
```

**에이전트 위임**:
```
✅ 에이전트가 성공 보고 → VCS diff 확인 → 변경 검증 → 실제 상태 보고
❌ 에이전트 보고 신뢰
```

## 중요한 이유

Superpowers 원본 24개 실패 기록에서:
- 사용자 파트너가 "I don't believe you" 선언 — 신뢰 파괴
- 미정의 함수 배포 — 크래시
- 누락 요구사항 배포 — 기능 불완전
- 거짓 완료로 시간 낭비 → 재작업
- 위반: "정직은 핵심 가치. 거짓말하면 교체된다."

## 적용 시점

**항상 다음 직전**:
- 성공/완료 주장의 **어떤 변형**이든
- 만족 표현의 **어떤 변형**이든
- 작업 상태에 대한 긍정 발언 어떤 것이든
- 커밋·PR 생성·태스크 완료
- 다음 태스크로 이동
- 에이전트 위임

**규칙은 다음에 적용**:
- 정확한 구문
- 패러프레이즈·유사어
- 성공의 암시
- 완료·정확성을 시사하는 **어떤** 커뮤니케이션이든

## 검증 체크리스트 (specops-auto-ko Lifecycle)

태스크 종료 전 다음 명령을 **실제 실행**하고 출력 첨부:

- [ ] `npm test` / `pytest` / 해당 프로젝트의 테스트 명령 — exit 0
- [ ] 린터 / 포매터 — exit 0
- [ ] 빌드 — exit 0
- [ ] 스펙 요구사항 체크리스트 — 각 항목 증거 있음
- [ ] 회귀 테스트 Red-Green 사이클 검증 (버그 픽스 태스크인 경우)
- [ ] 서브에이전트 위임 태스크면 `git diff` 확인 (변경이 실제로 일어남)
- [ ] `.specops/<FID>/evidence.md`에 출력 캡처

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 검증 명령과 출력을 **`evidence.md`에 전문 기록**. 요약 금지 |
| 2 **문지기** | 증거 없는 완료 주장은 **즉시 반려**. "거의" 불가 |
| 3 **깊이** | 부분 검증은 부분만 증명. 누락된 검증 항목을 **나열** |
| 4 **주권 존중** | 사용자가 "통과했다고 하자"는 주장에도 반드시 증거 요구 |
| 5 **한계 고백** | 검증할 수 없는 항목은 "검증 불가" 라벨 + 이유 |

## 결론

**검증에 지름길 없음.**

명령을 실행하라. 출력을 읽어라. **그런 다음** 결과를 주장하라.

협상 불가.

## 참조

- upstream 원본: `obra/superpowers@v5.0.7 skills/verification-before-completion/SKILL.md`
- ECC 보완: `affaan-m/everything-claude-code@1.2.0 skills/verification-loop/`
- specops-ko 한국어 선례: `skills/engine/verifying-evidence-ko.md`

## session-progress append (v0.4-pre P1 신설)

evidence.md 작성 + 모든 검증 PASS 직후, requesting-code-review-ko 호출 직전에:
```
bash scripts/session-progress-append.sh <FID> /verify PASS "evidence.md, AC N/N"
```

검증 실패 시 (BLOCK):
```
bash scripts/session-progress-append.sh <FID> /verify BLOCK "evidence.md (AC-X 미충족), systematic-debugging-ko 호출"
```

## 다음 skill

모든 검증 항목 증거 확보 + session-progress append 후 즉시 호출:

```
Skill: specops-auto-ko:requesting-code-review-ko
```

requesting-code-review-ko가 전체 변경사항에 대한 외부 리뷰를 요청한다. 본 verifying-evidence-ko는 **requesting-code-review-ko 이외의 다음 스킬을 호출하지 않는다**.

검증 실패 시에는 `specops-auto-ko:systematic-debugging-ko` 호출로 우회 (chain 복귀 조건).
