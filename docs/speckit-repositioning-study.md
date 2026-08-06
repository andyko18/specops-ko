# Spec-Kit 재포지셔닝 검토 (20260807)

> 직전 턴 권고 "specops-ko 를 Spec-Kit 위의 뒷단+강제 레이어로 재포지셔닝"의 타당성 실측 검토.
> 대상: `github/spec-kit` @ `81d5cdbbf2c96f7ce1a2801c6185f2951f1f61be` (2026-08-07) · specops-ko v1.62.0
> §1 의 코드 인용은 이 커밋 기준이다 — `events.py` 는 상류에서 이동한다.

---

## 결론

| 질문 | 답 |
|---|---|
| 기술적으로 가능한가 | **가능하다** — 훅 층까지 이식 가능. 직전 턴의 "훅은 못 옮긴다" 전제는 **틀렸다** |
| 지금 해야 하는가 | **아니다** — 근거였던 유지비 절감이 실측으로 무너졌고, 순서가 틀렸다 |
| 재포지셔닝의 진짜 근거 | 비용절감(✗) → **멀티 에이전트 이식성(○)** 으로 바뀐다. 실사용 0인 지금은 가치가 낮다 |

---

## 1. 전제 검증 — 훅은 이식 가능하다 (직전 턴 정정)

직전 턴에 "Spec-Kit extension 이 Claude Code 훅까지 번들할 수 있는지 실측 필요, 안 되면 이 안은 성립하지 않는다"고 단서를 달았다. **실측 결과 된다.**

### 근거 (소스 실측)

`src/specify_cli/events.py` — 2,345줄의 네이티브 이벤트 설치 계층이 존재한다.

`src/specify_cli/integrations/claude/__init__.py:44-65`
```python
CANONICAL_TO_NATIVE = {
    "session_start": "SessionStart",
    "pre_tool_use":  "PreToolUse",
    "post_tool_use": "PostToolUse",
    "session_end":   "SessionEnd",
    "user_prompt_submit": "UserPromptSubmit",
    "stop": "Stop",
}
events_config_file = ".claude/settings.json"
events_format = "json-nested"
```

specops-ko 가 `hooks/hooks.json` 에 등록한 이벤트는 5종이다 — **4종은 매핑되고, 1종은 없다**:

| specops 등록 | 핸들러 | Spec-Kit 매핑 |
|---|---|---|
| `PreToolUse` (matcher `Bash`) | pretool-governance | ✅ `pre_tool_use` |
| `PostToolUse` (`*`) | posttool-governance | ✅ `post_tool_use` |
| `SessionStart` | session-start | ✅ `session_start` |
| `Stop` ×3 | ensure-session-progress · stop-governance · freecomment-capture | ✅ `stop` |
| `Notification` ×2 | notify | ❌ **`CANONICAL_TO_NATIVE` 에 없음** |

`Notification` 은 보조 알림이라 강제력과 무관하지만, 이식 시 **기능 손실 1건**으로 계상해야 한다.

### 확장이 네이티브 이벤트를 등록할 수 있는가 — 그렇다

`events.py:944 collect_extension_events()` 가 설치된 확장의 `extension.yml` 에서 **`events:` 키**를 스캔해 `.claude/settings.json` 에 병합한다. 핸들러는 `matcher`·`timeout` 을 받는다(= Bash 로만 좁힐 수 있다).

### 차단(deny)이 전달되는가 — 그렇다

- `_run_inline()` 이 `result.returncode` 를 반환하고 `main()` 이 `sys.exit(...)` 로 그대로 종료 → **exit 2 전파**
- Claude 의 컨텍스트 envelope 기본값은 `plain` = **stdout 무가공 통과** → `permissionDecision: deny` JSON 그대로 전달

### 용어 주의 — `hooks:` 와 `events:` 는 다른 것

| extension.yml 키 | 정체 | 차단 가능? |
|---|---|---|
| `hooks:` | Spec-Kit **파이프라인** 훅 (`after_specify`, `before_implement` …) — 슬래시 커맨드 호출 | ✗ |
| `events:` | **네이티브 에이전트 훅** (`pre_tool_use` …) — settings.json 에 기록 | **○** |

직전 턴에 카탈로그 스키마의 `provides.hooks` 만 보고 "구현 미상"으로 판단했는데, 정작 능력은 `events:` 쪽에 있었다.

### 덤으로 발견한 것

Spec-Kit 은 Claude 용 커맨드를 **Claude Code Skill 형태**(`.claude/skills/speckit-*/SKILL.md`)로 설치한다 — specops-ko 스킬과 같은 형상이다. 스킬 층 이식은 거의 1:1이다.

### 검증 한계 — 핸들러는 "bash 스크립트"가 아니라 "커맨드 템플릿"이다

호출 사슬이 한 단계 더 있다:

```
events: {pre_tool_use: {command: speckit.<ext>.<cmd>}}
  → _find_command_template(command_name)      # 커맨드 템플릿 .md 를 찾는다
  → _extract_scripts(template)                 # frontmatter 의 scripts: 블록을 읽고
  → _resolve_argv(...)                         # argv 를 만든다 (base = .specify/extensions/<ext_id>/)
```

따라서 `pretool-governance.sh` 를 그대로 못 꽂는다 — **커맨드 템플릿으로 감싸고 `scripts: sh: <상대경로>` 를 선언**해야 하며, 경로 기준이 `.specify/extensions/<ext_id>/` 다. 현행 훅이 쓰는 `${CLAUDE_PLUGIN_ROOT}` 는 그 아래에서 존재하지 않는다.

**그리고 이 경로는 fail-open 이다** — `_find_command_template` 이 못 찾으면 `return 0`(주석: *"command not found: fail open (no-op)"*). 즉 커맨드명 정규화(`my-ext.boot` → `speckit.my-ext.boot`) 하나만 어긋나도 **차단 게이트가 조용히 무력화된다.** 소스 주석이 그 시나리오를 직접 경고한다("leaving the hook silently inert").

**코드 경로를 읽었을 뿐 실행하지 않았다.** 스파이크는 훅 등록이 아니라 **deny 가 실제로 발화하는지**를 확인해야 한다(§5).

---

## 2. 비용 근거 철회 — "45k LOC → 절반 이하" 는 틀렸다

직전 턴 근거였다. 실측이 반박한다.

### specops-ko 실측 (`wc -l`)

| 층 | 줄 수 | 이식 시 |
|---|---:|---|
| 테스트 (`scripts/tests`) | 18,120 | **전량 유지** — 내 게이트를 테스트한다 |
| 스킬 30종 | 7,573 | 일부만 |
| `scripts/_internal` | 4,263 | 유지 (재배선 필요) |
| 템플릿 33종 | 2,514 | 일부만 |
| 커맨드 23종 | 1,952 | 일부만 |
| 훅 | 1,731 | 유지 |
| agents 8 | 688 | 유지 |
| `scripts/dag` | 577 | 대체 가능 (`/speckit.tasks` 의존성 인지) |
| **생산 코드 계** | **19,298** | |

### 실제 감축분

Spec-Kit 이 대체하는 앞단 스킬:

```
specifying 486 + clarifying 196 + planning 291 + decomposing 346 + brainstorming 366 = 1,685
```

그런데 `specifying-ko` 486줄의 상당부는 **분기 6종**(maintain·maintain-lite·lite·foundation·batch·신규)과 **Step 5.5/5.6 design-first** 로, Spec-Kit 에 대응물이 없어 재구현 대상이다. `scripts/dag` 577 을 더해도:

> **순 감축 ≈ 1.2k~2.2k — 생산 코드 19,298줄의 6~11%이자, 45,268줄 전체의 3~5%.**

**절반이 아니다.** 45k 는 테스트(18.1k)와 이식 불가 층으로 부풀어 있었다.

---

## 3. 마이그레이션 청구서 (직전 턴에 계산 안 한 항목)

### 3.1 계약 배선 재작성

`propagation-matrix.jsonl` 실측:

| | |
|---|---:|
| 전체 edge | 81 |
| 앞단 산출물에 걸린 edge | **11 (14%)** |
| 영향받는 계약 그룹 | 7 / 21 |

영향 그룹: `lite-clarify-plan-skip` · `lite-screen-if-keep` · `lite-strict-guard` · `regression-ac-gate` · `foundation-manifest-gate` · `decisions-ledger-resolved` · `template-example-detectable`

### 3.2 checker 재배선 — 16개

`.specops` 경로·`spec.md`·`§` 마커에 결합된 스크립트(결합 횟수 순):

```
17  risk-profile.sh            17  check-regression-ac.sh
12  check-stack-decided.sh      8  check-review-presence.sh
 7  check-review-audit.sh       7  check-foundation-reuse.sh
 7  check-foundation-manifest.sh 6 check-maintain-baseline.sh
 4  record-task-receipt.sh      3  check-tdd-red.sh
 3  check-task-receipt.sh       2  scan-enrich-placeholders.sh
 2  collect-assumptions.sh      1  record-metric.sh
 1  check-fr-table.sh           1  check-decisions-ledger.sh
```

대표 사례 — `check-maintain-baseline.sh` 는 `spec.md` 의 `**§유형**: 유지보수` 와 FID 디렉터리의 `current-state.md` 를 동시에 읽는다. Spec-Kit 아래에서는 산출물이 `.specify/` 에 다른 형상으로 놓이고 `§` 마커가 없다 → **판정 로직 전면 재작성.**

### 3.3 그 외

- **경로 이원화** `.specify/` ↔ `.specops/` — FID 규약(`YYYYMMDD-kebab`)과 Spec-Kit 브랜치/디렉터리 규약 충돌
- **PreToolUse 지연** — Spec-Kit 경로는 `python3 events.py` 서브프로세스를 거친다. 현행은 직접 bash. `matcher: Bash` 로 좁혀도 커밋마다 파이썬 기동 비용 추가
- **상류 의존** — Spec-Kit 의 이벤트/확장 API 는 아직 진화 중(사설 카탈로그 "Phase 4 예정"). 파손 시 우리 강제력이 함께 죽는다

---

## 4. 세 안 비교

| | A. 전면 이식 | B. 하이브리드 | C. 현행 유지 + 차용 |
|---|---|---|---|
| 앞단 | Spec-Kit | Spec-Kit | specops |
| 강제층 | Spec-Kit extension `events:` | specops 플러그인 유지 | specops |
| 감축 | ~2.2k (11%) | ~1.7k (9%) | 0 |
| 재작성 | checker 16 · edge 11 · 경로 이원화 | 동일 + 두 시스템 병존 | 0 |
| 이식성 획득 | **8개 에이전트** | Claude 전용 유지 | Claude 전용 |
| 상류 파손 위험 | 높음 | 중 | 없음 |

---

## 5. 권고

### 재포지셔닝의 근거가 바뀌었다

원래 근거(**유지비 절감**)는 실측으로 죽었다 — 6~11%는 이 규모 수술을 정당화하지 못한다.
살아있는 근거는 하나뿐이다: **Spec-Kit `events:` 로 옮기면 specops-ko 의 강제층이 Claude·Cursor·Copilot·Codex·Gemini·Qwen·Devin·Tabnine 8종에서 동작한다.**

그런데 **specops-ko 는 실사용 0이다.** 아무도 검증하지 않은 제도를 8개 에이전트로 넓히는 건 순서가 틀렸다.

### 결정

**재포지셔닝 — 지금은 하지 않는다. 다만 폐기도 아니다(조건부 보류).**

해제 조건 2개:
1. **실사용 검증** — 실제 기능 1건을 lifecycle 완주시켜 게이트 13개가 견디는지 확인
2. **스파이크 1건** — Spec-Kit 확장 하나를 만들어 `events: pre_tool_use` 로 `git commit` **deny 가 실제로 발화하는지** 실측. 훅이 등록됐는지가 아니라 **차단되는지**를 본다 (§1 검증 한계 참조 — 커맨드 템플릿 래핑 · `${CLAUDE_PLUGIN_ROOT}` 부재 · fail-open 무력화 3건이 여기서 걸린다)

둘 다 통과하면 **안 A(전면 이식)** 로 간다 — 하이브리드는 두 시스템을 동시에 부양해야 해서 최악이다.

### 지금 대신 할 것 (직전 턴 2·3순위 승격)

1. **`/speckit.checklist` 개념 도입** — 스펙 문서 자체의 완전성·명확성·일관성 검증. specops-ko 의 명확한 빈칸이고, 우리는 체크리스트를 **기계 게이트로** 바꿀 수 있다(Spec-Kit 은 프롬프트로 둔다).
2. **커스터마이징 1단** — 한국 SI 산출물·5원칙을 override 가능한 층으로 분리. 지금은 하드코딩이라 이 repo 밖에서 못 쓴다.
3. **`[NEEDS CLARIFICATION]` 마커** — placeholder 스캐너에 편입.

---

## 부록: 이번 검토가 정정한 것

| 직전 턴 주장 | 실측 |
|---|---|
| "Spec-Kit extension 이 Claude 훅을 번들 못 하면 안 성립" | **번들 가능** — `events:` + `CANONICAL_TO_NATIVE` (단 `Notification` 미매핑) |
| "45k LOC 유지 부담이 절반 이하로" | **6~11% 감축**(생산 코드 19.3k 기준) — 45k 는 테스트 18.1k 포함 수치 |
| 마이그레이션 비용 | 미계산 → **checker 16 · edge 11 · 경로 이원화 · 커맨드 템플릿 래핑 · 파이썬 dispatch 지연** |
