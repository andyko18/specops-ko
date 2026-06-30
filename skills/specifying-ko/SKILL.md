---
name: specifying-ko
description: 모든 창작 작업 전에 반드시 사용 — 기능 신설·컴포넌트 구축·동작 수정 전 사용자 의도·요구사항·설계를 탐색. 설계 승인 전 어떤 구현 스킬도 호출하지 않는다.
layer: 2
reference_upstream: obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md
  - obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md (전반 "의도 탐색" + spec 산출 분리)
  - specops-ko skills/engine/brainstorming-ko.md
specops_version: 1.29.0
used_by: using-specops-auto-ko-ko, /start, /start-auto, /start-foundation, /start-all, /start-all-auto
---

# Engine 스킬 — 아이디어를 설계로 (specifying)

아이디어를 자연스러운 대화로 완성된 설계·스펙으로 탈바꿈시킨다. 현재 프로젝트 맥락을 먼저 이해한 뒤, 아이디어를 정교화하는 질문을 **한 번에 하나씩** 던진다. 무엇을 만들지 이해되면 설계를 제시하고 사용자 승인을 받는다.

<HARD-GATE>
설계를 제시하고 **사용자가 승인하기 전까지** 어떤 구현 스킬도 호출하지 않는다. 코드 작성 금지, 프로젝트 스캐폴딩 금지, 어떠한 구현 행위도 금지. 이는 **모든** 프로젝트에 적용된다 — 인지된 단순성과 무관하게.
</HARD-GATE>

## 안티패턴: "너무 간단해서 설계 불필요"

할 일 목록, 단일 함수 유틸, 설정 변경 — 전부 이 프로세스를 거친다. "간단한" 프로젝트가 **점검되지 않은 가정**으로 가장 많은 낭비를 만든다. 설계는 짧아도 된다(정말 단순하면 몇 문장). 하지만 **반드시 제시하고 승인**받는다.

## 체크리스트

다음 각 항목을 순서대로 태스크로 만들어 완료한다:

0. **[신규 분기] FID 생성 + 브랜치 생성** — args에서 슬러그를 추출해 FID를 결정하고, 디렉토리와 feat 브랜치를 함께 생성한다.

   ```bash
   # FID 결정 (날짜 + 기능 설명 슬러그)
   # 슬러그 규칙: 소문자 kebab-case, 영숫자+하이픈만, 최대 40자(초과 시 의미 단위로 절단),
   #   추출 불가(빈값·특수문자만·이모지) 시 fallback `feature-<HHMM>` 사용 — trailing dash 금지
   FID="YYYYMMDD-<slug>"
   mkdir -p .specops/$FID
   bash scripts/git-branch-create.sh $FID
   ```

   기존 `.specops/<FID>/` 디렉토리가 있으면 (유지보수 분기 재진입) 스킵.
   [유지보수 분기]는 analyzing-ko Step 0이 브랜치 생성을 담당하므로 본 스텝 적용 제외.

   **[batch 분기]**: args 첫 줄이 `<!-- entry: batch -->` 이면 → `bash scripts/git-branch-create.sh` **호출 금지** (브랜치는 `/start-all` 오케스트레이터가 이미 생성). 둘째 줄 `<!-- batch-id: <id> -->` 에서 batch-id를 추출해 Step 6에서 `**§batch**: <id>` 라벨 기재에 사용.

1. **프로젝트 맥락 탐색** — 파일·문서·최근 커밋 확인
   - 프로젝트 루트 `DESIGN.md` 존재 확인 (`ls DESIGN.md`)
     → **있으면**: 생성하는 `spec.md` §참조에 "`DESIGN.md` 디자인 시스템 준수" 포함
     → **없으면**: UI 컴포넌트 포함 기능이면 (HTML/CSS/React/Vue 등 시각 렌더링 포함) `/init-project` 실행 안내 (Phase 6 에서 DESIGN.md 생성 — `/start-design` 은 deprecated, `/init-project` 로 통합)
   - 프로젝트 루트 `screens/` 존재 확인 (`ls screens/ 2>/dev/null`)
     → **있으면 + UI 기능**: 기존 화면 목록 표시 — "현재 N개 화면: {name1}, {name2} ..." (Step 5.5에서 신규 화면 설계 예정)
     → **있으면 + 비UI 기능**: 무시 (screens/ 존재만 확인)
     → **없으면 + UI 기능**: `screens/` 자동 생성 예정 (Step 5.5 인라인 화면 설계에서 처리)
   - **`.specops/memory/*` 부트스트랩 산출물 자동 감지** (v2.0 신규 — `/init-project` 산출):
     - `.specops/memory/` 부재 → **graceful skip** (기존 dogfood 회귀 보호 — 부트스트랩되지 않은 프로젝트도 specifying-ko 정상 동작)
     - 존재 시: `ls .specops/memory/*.md 2>/dev/null` 결과를 spec.md `§참조` 에 자동 인용 (Step 6 작성 시):

       | 감지 파일 | spec.md §참조 인용 (bullet) |
       |---|---|
       | `constitution.md` | 헌법 준수 — `.specops/memory/constitution.md` |
       | `requirements.md` | FR/NFR 마스터 — `.specops/memory/requirements.md` |
       | `architecture.md` | 시스템 컴포넌트 — `.specops/memory/architecture.md` |
       | `frontend-architecture.md` | 프론트 아키텍처 — `.specops/memory/frontend-architecture.md` |
       | `backend-architecture.md` | 백엔드 아키텍처 — `.specops/memory/backend-architecture.md` |
       | `api-spec.md` | IF 설계서 — `.specops/memory/api-spec.md` |
       | `data-model.md` | 테이블 설계서 — `.specops/memory/data-model.md` |
       | `screens-overview.md` | 화면 목록 마스터 — `.specops/memory/screens-overview.md` |
       | `test-strategy.md` | 테스트 전략 — `.specops/memory/test-strategy.md` |

     - **`.specops/memory/brainstorming-*.md` PRD-first 합성** (v2.2 신규):
       - `ls .specops/memory/brainstorming-*.md 2>/dev/null` — 부재 시 graceful skip (AC-1)
       - 존재 시: 최신 파일(`ls -t | head -1` 수정 시간 기준) 읽기 → 핵심 인사이트(문제·대상·방향) 추출 → spec.md **§1 개요** 하단에 아래 블록 주입 (AC-2):
         ```markdown
         > **브레인스토밍 컨텍스트** (`<실제 파일명>`):
         > - 문제: <Startup: ## 현재 상태 요약 / Builder: ## 핵심 감탄 포인트 요약>
         > - 대상: <Startup: ## 고객 증거 §Q3 인물 / Builder: ## 핵심 감탄 포인트에서 추론 — 없으면 "미명시">
         > - 방향: <Startup: ## 최소 버전 Spec / Builder: ### 선택된 방향>
         ```
       - §참조에도 동일 파일 citation bullet 추가 (기존 패턴 유지, AC-3)
     - 위 표에 없는 `.specops/memory/*.md` 추가 산출물도 동일 패턴 (`brainstorming-*.md` 제외 — 위 PRD-first 합성 처리). (AC-5)
     - **회귀 보호 계약**: 본 분기는 spec.md §참조에 **인용만 추가**한다. 다른 섹션·내용을 변경하지 않는다 (T24 회귀 검증 대상). 단, `brainstorming-*.md` 감지 시 §1 개요 합성은 예외 (PRD-first 패턴, AC-4).
   - **`CONTEXT.md` 프로젝트 컨텍스트 자동 감지** (v2.1 신규):
     - `ls CONTEXT.md 2>/dev/null` — 부재 시 graceful skip
     - 존재 시: spec.md `§참조`에 `"프로젝트 컨텍스트 — \`CONTEXT.md\`"` 인용
   - **`docs/adr/*.md` Architecture Decision Records 자동 감지** (v2.1 신규):
     - `ls docs/adr/*.md 2>/dev/null | wc -l` — 0이면 graceful skip
     - N > 0이면: spec.md `§참조`에 `"아키텍처 결정 기록 — \`docs/adr/\` (N건)"` 인용
   - **gbrain 과거 인사이트 환류** (v2.3 신규 — learning-loop):
     - `bash scripts/gbrain-recall.sh "<args 원문 — entry HTML 주석 줄 제외>"` 실행
     - learnings.jsonl 부재 또는 매칭 0건 → graceful skip (환류 블록 미출력)
     - 결과 있으면 (≤3건): spec.md `§참조` 에 각 건을 `- 과거 인사이트 (gbrain, <fid>): <insight>` bullet 로 인용
     - **회귀 보호 계약**: §참조에 인용만 추가 — 다른 섹션·내용 무변경 (memory 감지 표와 동일)
   - **유지보수·foundation·batch 분기 진입 신호 검사** (Phase A):
     - args 첫 줄이 `<!-- entry: maintain -->` HTML 주석이면 [유지보수 분기] 진입
     - args 첫 줄이 `<!-- entry: foundation -->` HTML 주석이면 **[foundation 분기]** 진입 — Step 5.5 화면 루프 **skip**. 공통부 컴포넌트(라우팅·레이아웃·인증·공통 UI·DB 스키마)를 spec.md §2 포함 항목으로 DAG 의도 추출(독립/의존 표기). spec.md §참조에 `.specops/memory/frontend-architecture.md`·`backend-architecture.md`·`data-model.md`·`api-spec.md` 자동 인용(기존 memory 감지 표 재사용)
     - args 첫 줄이 `<!-- entry: batch -->` HTML 주석이면 **[batch 분기]** 진입 — Step 0 git-branch-create skip. Step 6에서 spec.md §1에 `**§batch**: <batch-id>` 라벨 기재(둘째 줄 `<!-- batch-id: ... -->` 에서 추출). **추가로 셋째 줄이 `<!-- auto: true -->` 이면 spec.md §1에 `**§auto**: true` 도 동시 기재** (무인 batch — `/start-all-auto` 진입. 다운스트림 §auto 자동통과 전파).
     - args 첫 줄이 `<!-- entry: auto -->` HTML 주석이면 **[auto 분기]** 진입 — git-branch-create.sh **호출 유지** (§auto는 단독 기능, 자체 브랜치 필요). Step 6에서 spec.md §1에 `**§auto**: true` 라벨 기재. 이후 `[신규 분기]` 동작 계속 (DESIGN.md·screens/ 점검 동일)
     - 그렇지 않으면 [신규 분기] (현재 동작 — DESIGN.md / screens/ 점검)

   **[유지보수 분기]** (Phase C 적용 — 본문 축약, analyzing-ko 결과 참조):
     - `analyzing-ko` 가 이미 호출되어 `.specops/<FID>/current-state.md` + `.specops/<FID>/impact-analysis.md` 가 산출되어 있어야 함
     - 본 skill 은 두 산출물을 **참조만** — 재분석 안 함
     - spec.md `§참조` 에 `current-state.md` + `impact-analysis.md` 경로 자동 포함
     - Step 3 명확화 질문으로 진행

     **Phase A 단독 시점 fallback** (analyzing-ko 부재 시 — Phase A 만 적용된 환경):
     - 본 skill 이 5 항목 mini-checklist 직접 실행:
       1. 변경 대상 파일·진입점 식별 (`grep -rn`, `Read`)
       2. 호출자/의존 매핑
       3. 기존 테스트 커버리지 확인
       4. 관찰 가능 동작 1~3 건 캡처
       5. 회귀 위험 1 줄 메모
     - 산출물: `.specops/<FID>/current-state.md` (templates/current-state.md 기반)
     - ★ HARD GATE: "분석 결과 검토. 진행? [y/n]"
2. **Visual Companion 제안** (시각 질문이 예상되면) — 자체 메시지로만. 명확화 질문과 섞지 말 것. 아래 Visual Companion 섹션 참조
3. **명확화 질문** — 한 번에 하나, 목적·제약·성공 기준 이해
4. **2~3 접근 제안** — 트레이드오프와 권고 제시
5. **설계 제시** — 섹션을 복잡도에 맞춰 스케일, 각 섹션 후 사용자 승인 확인
5.5. **[UI 기능인 경우] 인라인 화면 설계** — 설계 승인 직후 실행:

   > lifecycle 밖에서 개별/일괄 화면을 따로 손보려면 `/design-screen`(단수)·`/design-screens`(복수). 본 Step 5.5 는 lifecycle 내 자동 처리다.

   **[§auto 모드]** (`grep -qE '^\*\*§auto\*\*:[[:space:]]*true' .specops/<FID>/spec.md`):
   - 화면 목록을 자동 판단하여 **즉시 생성·수락** (수정 루프 없음):
     1. `templates/screen.html` + 현재 spec 맥락 기반으로 HTML artifact 즉시 생성
     2. **자동 수락** — 사용자 응답 대기 없이 `screens/{name}.md` + `screens/{name}.html` 저장
     3. spec.md §1에 "**자동 결정 화면**: {name1}, {name2}, ..." 한 줄 기록 (투명성·PR 게이트 가정 다이제스트 용)
   - 모든 화면 저장 완료 후 Step 6 진행

   **[§auto 이외 모드]** (기존 동작):
   - 이 기능에 필요한 화면 목록을 자동 판단하여 명시:
     > "이 기능에 필요한 화면은 N개입니다: {name1}({설명}), {name2}({설명}) ..."
   - **[ui-ux-pro-max design system 자문 (자동)]**: ui-ux-pro-max 는 plugin.json hard dependency(보장 동반 설치)다. 화면 설계 시작 전 1회만 `ui-ux-pro-max:ui-ux-pro-max` Skill 자동 호출 → design system 산출 → HTML artifact 스타일에 반영. **graceful 안전망**: marketplace 미등록 등으로 available-skills 미감지 시 DESIGN.md 토큰 fallback(의존성 미해결 경고 — `claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` 안내). **우선순위**: ui-ux-pro-max 결과 우선, DESIGN.md 후순위.
   - 각 화면을 순서대로 설계:
     1. `templates/screen.html` + 현재 spec 맥락 기반으로 HTML artifact 즉시 생성 (별도 질문 없이)
     2. 사용자에게 보여주고 수정 요청 수렴 → 수정 요청 시 재생성 루프
     3. 승인 → `screens/{name}.md` + `screens/{name}.html` 저장 (`mkdir -p screens` 선행)
   - 모든 화면 완료 후 Step 5.6 진행
5.6. **[API/스키마 기능인 경우] 인라인 인터페이스 설계** — 설계 승인 직후 실행 (화면 Step 5.5 와 **대칭** — 인터페이스도 design-first):

   > **적용 조건**: 이번 기능이 **API 엔드포인트**(제공) 또는 **DB 스키마**(테이블·필드)를 신설·변경한다. 해당 없으면(순수 UI·CLI 로직 등) 본 스텝 skip.
   > **대상 산출물**: `.specops/memory/api-spec.md`(IF 설계서) · `.specops/memory/data-model.md`(테이블 설계서) — 영향받는 것만. 화면이 `screens/`(화면별 파일)을 생성하듯, 인터페이스는 이 **마스터 문서의 해당 섹션을 갱신**한다.
   > **원칙**: 구현이 이 설계를 따른다(design-first). 구현 중 불가피하게 벗어나면 `verifying-evidence-ko` 의 "memory 설계 동기화 점검"(역방향 안전망)이 사후 감지한다.

   **[§auto 모드]** (`grep -qE '^\*\*§auto\*\*:[[:space:]]*true' .specops/<FID>/spec.md`):
   - 이번 기능이 추가·변경하는 엔드포인트/테이블을 자동 판단해 해당 memory 문서에 **즉시 반영·수락**:
     1. `api-spec.md` §1(엔드포인트 표) 또는 채택된 정의방식 섹션에 신규 행 반영
     2. `data-model.md` §3(핵심 엔티티)·§2(ERD)에 신규 테이블/필드 반영
     3. spec.md §1 에 "**자동 결정 인터페이스**: {엔드포인트/테이블 요약}" 한 줄 기록 (투명성·PR 게이트 가정 다이제스트 용)
   - 반영 완료 후 Step 6 진행

   **[§auto 이외 모드]**:
   - 이번 기능이 건드리는 인터페이스/스키마를 명시:
     > "이 기능은 다음 인터페이스를 추가/변경합니다: {POST /orders — 주문 생성}, {orders 테이블 — id·user_id·status ...}"
   - 사용자 확인 후 해당 memory 문서 섹션을 **구현 전에 먼저 갱신**:
     - `api-spec.md`: 엔드포인트 표·요청/응답 스키마·인증 반영
     - `data-model.md`: 엔티티 표·ERD·인덱스 반영
   - memory 문서가 **부재**하면(예: UI-only 로 init 되어 api-spec 미생성) → 생성 여부를 사용자에게 확인 (제공 API 인지 외부 소비 인지 구분 — 제공이면 `templates/api-spec.md` 기반 생성)
   - 반영 완료 후 Step 6 진행
6. **설계 문서 작성** — `.specops/<FID>/spec.md` + `acceptance-criteria.md`로 저장하고 커밋
   - UI 기능이면 §참조에 `screens/{name}.md` 목록 자동 포함
   - API/스키마 기능이면 §참조에 `.specops/memory/api-spec.md`·`data-model.md` 자동 포함 (Step 5.6 갱신분)
   - **§유형 라벨 자동 기재** (Phase A — 신규 추가): spec.md §1 개요 의 `**§유형**` 라벨을 다음 규칙으로 자동 부여 — 진입 신호 + current-state.md §1 라인 범위 메타 합산 기반:

     | 진입 신호 | current-state.md §1 라인 범위 합산 | 라벨 |
     |---|---|---|
     | 신규 분기 | N/A | `**§유형**: 신규` |
     | foundation 분기 | N/A | `**§유형**: foundation` |
     | 유지보수 분기 | ≤ 5 | `**§유형**: trivial` (사용자가 자기선언으로 거부 가능) |
     | 유지보수 분기 | > 5 또는 미산출 | `**§유형**: 유지보수` |
     | batch 분기 | N/A | `**§유형**: 신규` + `**§batch**: <batch-id>` (§batch 라벨이 decomposing-ko 정지점 신호로 사용됨) |

     **근거**: clarify Q-B 결정 — trivial 자동 판정 시점은 analyzing-ko current-state.md §1 메타 사전 추정. Phase A 단독 시점에는 specifying-ko Step 1 mini-checklist §1 라인 범위 메타로 대체. 라벨은 clarifying-ko 단계에서 갱신 가능.

     라벨이 `유지보수` 면 acceptance-criteria.md 의 "## 회귀 방지 AC (유지보수 FID 필수)" 섹션이 자동 활성 — sprint-contracts-ko evaluator 가 `AC-R-*` ≥ 1 강제.

   - **성공지표 작성 유도 (권장 — should)**: §유형이 `trivial`이 아니면 spec.md §1 개요 하위 `### 성공지표` 서브섹션에 measurable target을 작성한다(정량 우선, 불가 시 정성+검증방법). **권장 — 미작성이 evaluator FAIL은 아니나**, 기능 가치 입증·learning-loop 추적을 위해 작성 강력 권고. trivial FID는 면제.
7. **스펙 자체 검토** — 플레이스홀더·모순·모호성·범위 인라인 점검 (아래 참조)
8. **사용자 스펙 검토** — 파일 검토를 사용자에게 요청, 승인 대기
9. **session-progress append** — `bash scripts/session-progress-append.sh <FID> /specify 완료 "spec.md, AC.md" "<기능명>"` (첫 진입이라 신규 FID 섹션 생성)
10. **구현으로 전환** — `specops-auto-ko:clarifying-ko` 스킬 호출

## 프로세스 흐름

```
프로젝트 맥락 탐색
    ↓
args 첫 줄 = "<!-- entry: maintain -->"? ── yes ──▶ [유지보수 분기] 5 항목 mini-checklist + current-state.md ★ HARD GATE → spec.md §유형 자동 라벨 (유지보수 / trivial — 라인 ≤ 5) → Step 3
    │
    └── no ──▶ args 첫 줄 = "<!-- entry: foundation -->"? ── yes ──▶ **[foundation 분기]** Step 5.5 skip → 공통부 spec 작성 (§유형=foundation) → Step 3
                    │
                    └── no ──▶ args 첫 줄 = "<!-- entry: batch -->"? ── yes ──▶ **[batch 분기]** git-branch-create skip → spec.md §batch 라벨 기재 (+ 셋째 줄 auto:true 시 §auto 라벨 병기) → [신규 분기] 동작 계속
                                    │
                                    └── no ──▶ [신규 분기] (현재 동작) ↓
    ↓
DESIGN.md 존재? ── yes ──▶ spec.md §참조에 "DESIGN.md 디자인 시스템 준수" 포함
    │                              ↓
    └── no (UI 기능이면 /init-project 안내 — Phase 6 에서 DESIGN.md 생성)
    ↓
screens/ 존재? ── yes ──▶ 기존 화면 목록 표시 (참고용)
    │
    └── no
    ↓
시각 질문 예상? ── yes ──▶ Visual Companion 제안 (단독 메시지)
    │                              ↓
    └── no ──▶ 명확화 질문 (한 번에 하나) ◀───┘
                  ↓
              2~3 접근 제안 + 추천
                  ↓
              설계 섹션 제시 ── 사용자 승인?
                  ↑                │
                  └── no, 수정     │ yes
                                   ↓
                         UI 기능? ── yes ──▶ 필요 화면 목록 자동 판단
                              │                      ↓
                              │              HTML artifact 생성 ── 수정 요청?
                              │                      ↑                  │ no
                              │                      └──────────────────┘
                              │                           승인
                              │                      ↓
                              │              screens/{name}.md + .html 저장
                              │                      ↓
                              │              화면 더 있음? ── yes ──▶ 다음 화면
                              │                      │ no
                              └── no ────────────────┘
                                   ↓
                              설계 문서 작성 (spec.md — §참조에 screens/ 포함)
                                   ↓
                              스펙 자체 검토 (인라인 수정)
                                   ↓
                              사용자 스펙 검토 ── 변경 요청?
                                   │              ↑
                                   │ 승인         │
                                   ↓              │
                              specops-auto-ko:clarifying-ko 호출
```

**종착점은 `specops-auto-ko:clarifying-ko` 호출이다.** 본 스킬은 프론트엔드 설계 스킬이나 MCP 빌더 등 어떤 구현 스킬도 호출하지 않는다. specifying 이후 유일한 스킬은 **clarifying-ko**이다.

## 프로세스 세부

### 아이디어 이해

- **현재 프로젝트 상태 먼저** — 파일·문서·최근 커밋
- 세부 질문 전에 **규모 점검**: 요청이 여러 독립 서브시스템(예: "채팅+파일스토리지+결제+분석")을 담으면 **즉시 표시**. 분해 필요한 프로젝트에 세부 질문하지 말 것
- 프로젝트가 단일 스펙으로 너무 크면, 서브 프로젝트로 분해 돕기: 독립 조각은 무엇인가, 어떻게 연결되는가, 어떤 순서로 만들 것인가. 그 뒤 첫 서브 프로젝트를 정상 설계 흐름으로. 각 서브 프로젝트는 자체 spec → plan → implementation 사이클
- 적절한 규모면 질문을 하나씩 refine
- **객관식이 가능하면 객관식**. 열린 질문도 OK
- **한 메시지당 한 질문** — 한 주제에 탐색이 더 필요하면 여러 질문으로 쪼갠다
- 목적·제약·성공 기준에 집중
- **질문 상한**: 명확화 질문은 **최대 4 회 (Q1~Q4)** 까지 수집한 뒤 설계 초안을 제시한다. Q5 이상 추가 명확화가 필요하다고 판단되면 **그 질문은 `specops-auto-ko:clarifying-ko` 로 위임** — 본 skill 의 책임은 "구현 가능한 최소 초안" 까지 (FRICTION-LOG F-15)

### 접근 탐색

- 2~3 접근을 **트레이드오프와 함께** 제시
- 대화체로, 추천 옵션을 **먼저** 제시하며 이유 설명
- 권고를 앞세우되 대안도 함께

### 설계 제시

- 이해했다고 판단되면 설계 제시
- 각 섹션을 복잡도에 맞게 스케일 (단순하면 몇 문장, 미묘하면 200~300 단어)
- **각 섹션 후** 맞는지 확인
- 아키텍처·컴포넌트·데이터 흐름·에러 처리·테스트를 다룸
- 말이 안 되면 되돌아가 명확화

### 격리와 명확성을 위한 설계

- 시스템을 더 작은 단위로 분해 — 하나의 명확한 목적, 잘 정의된 인터페이스, 독립 이해·테스트 가능
- 각 단위는 답할 수 있어야 함: 무엇을 하는가, 어떻게 쓰는가, 무엇에 의존하는가
- 내부를 읽지 않고 단위의 역할을 이해할 수 있는가? 내부 변경이 소비자를 깨지 않는가? 아니면 경계 재설계
- 작고 잘 구획된 단위는 당신(Claude)에게도 유리 — 한 번에 컨텍스트에 담을 수 있는 코드일수록 추론이 정확하고 편집이 안정적. 파일이 커지는 건 **너무 많은 일**을 하고 있다는 신호

### DAG 의도 추출 (v0.4b 신규)

설계 제시 단계에서 **반드시** 컴포넌트 간 의존 구조를 판단하고 spec.md §2 포함 항목에 명시:

**PARALLEL 신호** — 독립 컴포넌트 2개 이상:
- "A, B, C 각각 독립된 도구/파일/모듈"
- "서로 의존성 없음", "각각 독립", "3개 독립"
- 여러 도구가 공유 상태 없이 동등한 위치
- → spec.md §2 포함에 `(독립 — 병렬 구현 가능)` 표기

**CHAIN 신호** — 단계적 의존:
- "양방향", "파이프라인", "A → B → C 순서"
- 후속 단계가 전 단계 산출물을 입력으로 사용
- → spec.md §2 포함에 `(의존: <선행 컴포넌트>)` 표기

**표기 예시**:
```markdown
## 2. 범위
### 포함
- b64enc: Base64 인코더 (독립 — 병렬 구현 가능)
- b64dec: Base64 디코더 (독립 — 병렬 구현 가능)
- b64val: Base64 검증기 (독립 — 병렬 구현 가능)
- 통합 검증 (의존: b64enc, b64dec, b64val)
```

이 표기는 decomposing-ko가 DAG leaf를 자동 인식하는 데 사용된다. **모호하면 PARALLEL보다 CHAIN을 택하고 clarifying-ko에서 확인.**

### 기존 코드베이스 작업

- 변경 제안 전 현재 구조 탐색. **기존 패턴 따름**
- 기존 코드에 작업과 관련된 문제가 있다면(너무 커진 파일, 불분명한 경계, 얽힌 책임) 설계의 일부로 **타겟팅된 개선** 포함 — 좋은 개발자가 작업 중인 코드를 개선하듯이
- 관련 없는 리팩터링은 금지. 현재 목표에 집중

### NFR 작성 규약

spec §NFR 의 호환성 항목 (`bash 4+`, `Python 3.10+`, `Node.js 18+` 등) 은 **실측 최저 버전 우선 기재**. 확신 없거나 검증 미완료 시 `<ver>+ (실측 미확인)` 형식으로 한계 고백 (원칙 5). 기존 아티팩트의 NFR 을 맹목 복제 금지.

예:
- ✅ `bash 3.2+ (macOS 실측 · Linux 미검증)`
- ❌ `bash 4+` (실제로 bash 3.2 에서 동작하는데 과도 기재)

**근거**: dogfood FID `20260422-csv-lines` 에서 spec NFR-2 가 `bash 4+` 로 기재됐으나 실측 bash 3.2.57 에서 9/9 PASS — 구현 자체가 bash 4+ 전용 문법 (연상배열 · `[[ ]]`) 미사용. specifying-ko 가 `wc-lines` NFR-2 를 맹목 복제한 흔적. sprint-contracts 상 spec 은 후속 단계 읽기 전용이라 재진입 전까지 수정 불가 — 작성 시점에 정확해야 함 (FRICTION-LOG F-13).

## 설계 이후 단계

### 문서화

- 검증된 설계(스펙)를 `.specops/<FID>/spec.md`로 작성
  - 사용자 선호가 있다면 그 경로 우선
- 커밋 (`git add` + 메시지 "spec: <topic>")

### 스펙 자체 검토

스펙 작성 후 새 눈으로 확인:

1. **플레이스홀더 스캔** — "TBD"·"TODO"·미완성 섹션·모호 요구. 수정
2. **내부 일관성** — 섹션 간 모순? 아키텍처가 기능과 일치?
3. **범위 점검** — 단일 구현 플랜으로 집중됐는가? 분해 필요?
4. **모호성 점검** — 두 가지로 해석될 요구? 하나 고르고 명시

인라인 수정. 재검토 불필요.

### 사용자 검토 게이트

**[§auto 모드]** (`grep -qE '^\*\*§auto\*\*:[[:space:]]*true' .specops/<FID>/spec.md`):

자체 검토 완료 즉시 **자동 통과** — 사용자 응답 대기 없이 clarifying-ko 직행. handoff/dispatch-log에 "spec auto-approved (§auto mode)" 기록.

**[§auto 이외 모드]** (기존 동작):

자체 검토 후 사용자에게:

> "스펙을 `.specops/<FID>/spec.md`에 작성했습니다. 검토 후 변경 사항을 말씀해 주세요. 진행해도 되면 `specops-auto-ko:clarifying-ko` 스킬을 호출해 다음 단계(명확화)로 진행하겠습니다."

**응답 대기**. 변경 요청 시 수정하고 자체 검토 루프 재실행. 승인 후에만 진행.

## 5원칙 주입 (specops-auto-ko 고유)

질문·제안·설계 제시·문서화 중 다음 원칙을 항상 적용:

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 추천의 **근거**를 템플릿으로 제시. 감정 표현 금지 |
| 2 **문지기** | 모호하거나 위험한 제안(DB 삭제·배포 자동화)은 **명시 확인**. 아니면 진행 거절 |
| 3 **깊이** | 빠른 답보다 정확. "잘 모르겠으면 확인 후 답변드리겠습니다" |
| 4 **주권 존중** | 결정은 사용자가 함. 에이전트는 **옵션 제시** |
| 5 **한계 고백** | 불확실하면 "이 부분은 가정입니다" 명시 |

## 핵심 원칙

- **한 번에 한 질문** — 동시에 여러 질문으로 압박 금지
- **객관식 선호** — 열린 질문보다 답하기 쉬움
- **YAGNI 철저** — 모든 설계에서 불필요 기능 제거
- **대안 탐색** — 결정 전 항상 2~3 접근 제시
- **점진 검증** — 설계 제시, 승인 후 다음으로
- **유연성** — 말이 안 되면 되돌아가 명확화

## Visual Companion

브레인스토밍 중 목업·다이어그램·시각 옵션을 보여주는 브라우저 기반 동반 도구. **도구이지 모드가 아님**. 동반 도구를 수용한다는 것은 시각 처리가 유리한 질문에 사용 가능하다는 뜻 — 모든 질문이 브라우저를 거친다는 뜻이 **아님**.

**제안 방법**: 향후 질문이 시각 콘텐츠(목업·레이아웃·다이어그램)를 포함할 것으로 예상되면, 한 번만 동의를 구함:

> "지금 하는 작업 중 일부는 제가 웹 브라우저로 보여드리는 편이 설명이 쉬울 수 있습니다. 진행하면서 목업·다이어그램·비교 등 시각 자료를 준비할 수 있고요. 이 기능은 새 기능이라 토큰 소모가 많을 수 있습니다. 써보시겠어요? (로컬 URL 열기 필요)"

**이 제안은 반드시 자체 메시지**. 명확화 질문·맥락 요약·다른 콘텐츠와 섞지 말 것. 사용자 응답 대기. 거절 시 텍스트 전용 브레인스토밍 진행.

**질문별 결정**: 동의 후에도 **각 질문마다** 브라우저/터미널 결정. 기준: **사용자가 글로 읽는 것보다 보는 편이 이해가 쉬운가?**

- **브라우저** — 시각 콘텐츠 자체 (목업·와이어프레임·레이아웃 비교·아키텍처 다이어그램·사이드바이 디자인)
- **터미널** — 텍스트 (요구 질문·개념 선택·트레이드오프 목록·A/B/C/D 옵션·범위 결정)

UI 주제 질문이 자동으로 시각 질문인 건 아님. "이 맥락에서 personality란?"은 개념 질문 — 터미널. "어떤 위저드 레이아웃이 나은가?"는 시각 질문 — 브라우저.

사용법: `bash skills/brainstorming-ko/scripts/start-server.sh` → 브라우저 오픈 → `helper.js`의 `sendToVisualCompanion(html)` 호출.

## 참조

- `skills/structured-artifacts-ko/SKILL.md` — 스펙 파일 경로 규약
- `templates/spec.md` · `templates/acceptance-criteria.md` — 작성 포맷
- upstream 원본: `obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md`

## Handoff 기록 (다음 skill 진입 직전 필수)

`clarifying-ko` 호출 직전 `.specops/<FID>/handoffs/specifying.md` 작성 (structured-artifacts-ko 규약 4필드: Decided/Rejected/Risks/Remaining).

## 다음 skill

설계 승인 + 사용자 스펙 검토 통과 + handoff.md 기록 후 즉시 호출:

```
Skill: specops-auto-ko:clarifying-ko
```

본 specifying-ko는 **clarifying-ko 이외의 어떤 스킬도 호출하지 않는다**. 다른 경로는 금지.
