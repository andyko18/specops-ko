#!/usr/bin/env bash
# test-gate-presence.sh — skill-body HARD GATE 존재 회귀 (②)
#
# 목적: skill body 의 핵심 게이트 문구가 실수로 삭제·drift 되는 것을 **결정적 grep** 으로 방어한다.
#   - LLM 이 게이트를 "지키는지"(행동) 는 llm-eval(주간 smoke) 관할.
#   - 본 테스트는 게이트가 "존재하는지"(구조) 만 — 무료·결정적·CI 상시.
#   - recurring 결함 클래스(feedback_skill_body_infra_propagation: teeth in body, 인프라 소실)의
#     "게이트 자체 소실" 절반을 봉쇄. cross-skill signal 정합은 validate-structure contract_consistency(①) 담당.
# (templates·scripts 파일의 문구·배선 존재도 has 로 확인한다 — task id 규약 등)
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 1
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
cd "$PLUGIN" || exit 1

# has <file> <regex...> — 모든 패턴이 파일에 존재하면 0
has() {
  local f="$1"; shift
  local p
  for p in "$@"; do grep -qE "$p" "$f" || return 1; done
  return 0
}

# ── foundation 재사용 메커니즘 3-지점 계약 (PR #165) ─────────────
V=skills/verifying-evidence-ko/SKILL.md
if has "$V" '§유형.*foundation' 'foundation-manifest' 'VERIFY: FAIL foundation-manifest'; then
  ok "foundation manifest 생산 게이트 존재 (verify: §유형=foundation → 실제 파일 검사)"
else
  nope "foundation manifest 생산 게이트 소실" "verifying-evidence-ko — 소비 게이트가 침묵 no-op 될 수 있음"
fi

D=skills/decomposing-ko/SKILL.md
if has "$D" 'foundation 재사용 게이트' '재사용 foundation' '미재사용 근거'; then
  ok "foundation 재사용 소비 게이트 존재 (decomposing)"
else
  nope "foundation 재사용 소비 게이트 소실" "decomposing-ko"
fi

P=skills/planning-ko/SKILL.md
if has "$P" 'foundation-manifest' 'verifying-evidence-ko'; then
  ok "foundation 생산 지시 + verify 강제 cross-ref 존재 (planning)"
else
  nope "foundation 생산 지시/강제 cross-ref 소실" "planning-ko"
fi

# 경로 정합 — 생산 게이트·소비 게이트가 동일 정규 경로를 가리키는가
if has "$V" '\.specops/memory/foundation-manifest\.md' && has "$D" 'foundation-manifest\.md'; then
  ok "foundation-manifest 경로 정합 (.specops/memory/)"
else
  nope "foundation-manifest 경로 drift" "verify↔decomposing 경로 불일치"
fi

# ── 입력 프로브 (fixture-외) 의무 — code-reviewer-ko 4단계 + 보고서 섹션 ────
# 한계 (5원칙 5): 본 검사는 **문구 존재**만 본다 — 리뷰어가 실제로 프로브했는지는 검증하지 않는다.
#   프로브는 행동이라 파일 대조로 검증 가능한 객관 신호가 없다(F1 의 누락 검사와 다른 지점).
#   guidance-level 이라는 뜻이며, 그 천장을 알고 넣는다 (#226 P4 넛지와 같은 등급).
CR=agents/code-reviewer-ko.md
#   패턴 3종은 각각 다른 소실을 잡는다: ① 프로세스 단계(번호 앵커) ② fixture 수정 금지 계약
#   ③ 보고서 섹션. ①·③ 중 하나만 검사하면 나머지 삭제가 mutation 생존한다 (실측).
if has "$CR" '^4\. \*\*입력 프로브' 'fixture.*수정하지 않는다' '^## 입력 프로브'; then
  ok "입력 프로브(fixture-외) 의무 + 보고서 섹션 존재 (code-reviewer-ko)"
else
  nope "입력 프로브 의무 소실" "code-reviewer-ko — 작성자 fixture 안에서만 판정하게 됨"
fi

# ── BATCH halt signal — 방출 skill 에 signal + halt 동시 존재 ────
# (cross-skill 방출↔감시 정합은 ① contract_consistency; 여기선 방출측 halt 구조만)
declare -a SIG=(
  "BATCH-PHASE1-DONE:decomposing-ko"
  "BATCH-REVIEW-DONE:receiving-code-review-ko"
  "BATCH-SECURITY-DONE:security-review-ko"
  "BATCH-INTEGRATION-DONE:integration-test-ko"
  "BATCH-PERF-DONE:performance-test-ko"
)
for pair in "${SIG[@]}"; do
  token="${pair%%:*}"; skill="${pair##*:}"
  f="skills/${skill}/SKILL.md"
  if has "$f" "$token" 'halt|PR 게이트'; then
    ok "batch halt signal 존재: ${token} (${skill})"
  else
    nope "batch halt signal 소실: ${token}" "${skill} — signal 또는 halt 문구 부재"
  fi
done

# ── 가정 다이제스트 "자동 결정 인터페이스" 수집 3-소비처 (P1-3 audit 20260710) ──
# specifying §auto Step 5.6 이 spec.md 에 기록하는 라벨을 다이제스트 소비처가 실제 수집하는지.
for f in skills/performance-test-ko/SKILL.md commands/start-auto.md commands/start-all-auto.md; do
  if grep -q '자동 결정 인터페이스' "$f"; then
    ok "다이제스트 인터페이스 수집 존재 ($f)"
  else
    nope "다이제스트 인터페이스 수집 ($f)" "'자동 결정 인터페이스' 미수집 — 무인 API 가정이 PR 게이트에 안 보임"
  fi
done

# ── FID 크기 규약 (완성율 레버, 20260718-fid-size) ──
# decomposing-ko body 에 per-FID 태스크 수 소프트 신호가 존재하는지 (silent drift 방어).
# dogfood: test2 3-태스크 FID 6/6 완주 vs test1 10-태스크 FID 정체 → 큰 FID = 완성율 리스크.
if has skills/decomposing-ko/SKILL.md 'FID 크기' 'FID-SIZE' '재개는? ?/status|/status.*재개|reconcile'; then
  ok "decomposing-ko FID 크기 규약 존재 (완성율 소프트 신호 + 재개 연결)"
else
  nope "decomposing-ko FID 크기 규약 소실" "per-FID 태스크수 신호 부재 — 큰 FID 정체 리스크 무경고"
fi

# ── E2 최종 리뷰 right-size + end-loaded (경제성) ──
# end-loaded C 또는 단일 태스크 per-task C 와의 중복 최종 리뷰 skip + B/C 생략 금지(시점 통합만 허용).
if has skills/implementing-ko/SKILL.md '최종 리뷰 right-size|최종 리뷰 SKIP' 'end-loaded|태스크 수 == 1' 'Phase B/C \*\*생략\*\*|시점 통합|생략 금지'; then
  ok "implementing-ko E2/end-loaded 최종 리뷰 right-size 존재 (중복 skip + B/C 생략 금지)"
else
  nope "implementing-ko E2/end-loaded 최종 리뷰 right-size 소실" "중복 제거 게이트 또는 품질 가드 부재"
fi

# ── P1 Evaluator 모델 불가 fallback (20260718 test2 회고) ──
# 지정 모델 한도 소진·접근 불가 시 부모 self-review 붕괴 금지 + 독립 리뷰어 fallback 존재.
if has skills/implementing-ko/SKILL.md 'Evaluator 모델 불가' '부모 self-review 로 후퇴 금지|부모 self-review.*금지' '독립 서브에이전트'; then
  ok "implementing-ko Evaluator fallback 존재 (독립 리뷰어 + 부모 self-review 금지)"
else
  nope "implementing-ko Evaluator fallback 소실" "지정 모델 불가 시 Generator↔Evaluator 붕괴 무방어"
fi
if grep -q '부모 self-review 로 후퇴 금지' skills/planning-ko/SKILL.md && grep -q 'plan-reviewer-ko .*독립 서브에이전트\|독립 서브에이전트로 가용 모델' skills/planning-ko/SKILL.md; then
  ok "planning-ko plan-reviewer fallback 참조 존재"
else
  nope "planning-ko plan-reviewer fallback 소실" "plan-reviewer 도 동일 붕괴 표면"
fi

# ── P5 detection-proof (테스트 전용 태스크 RED 대체, 20260718 test2 회고) ──
if has skills/tdd-ko/SKILL.md 'detection-proof' '규칙 뒤집기|rule inversion' '유령 주입|ghost' '변이해도 통과.*tautology|tautology'; then
  ok "tdd-ko detection-proof 존재 (RED 대체: 변이로 탐지력 증명)"
else
  nope "tdd-ko detection-proof 소실" "테스트 전용 태스크가 자연 RED 없어 가짜 RED/공회전"
fi

# ── P2 공유유틸 창발중복 경고 + P4 implement 선언 넛지 (20260718 test2 회고) ──
if has skills/planning-ko/SKILL.md '공유 유틸 창발 중복' '공통 lib|공통lib' '창발 중복 리스크'; then
  ok "planning-ko P2 창발중복 경고 존재"
else
  nope "planning-ko P2 창발중복 경고 소실" "형제-FID 유틸 복제 무경고 → 승격 backlog 반복"
fi

# ── batch plan-reviewer DEFER ──
if has skills/planning-ko/SKILL.md 'plan-reviewer DEFER|DEFERRED → Phase 2 batch' '§batch' 'dispatch 하지 않음'; then
  ok "planning-ko batch plan-reviewer DEFER 존재"
else
  nope "planning-ko batch DEFER 소실" "Phase 1 FR마다 reviewer 회귀 위험"
fi
if grep -q 'Batch plan-review' commands/start-all.md && grep -q 'batch-plan-digest.sh' commands/start-all.md; then
  ok "start-all Phase 2 batch plan-review + digest 배선"
else
  nope "start-all Phase 2 plan-review 배선 소실" "DEFER 해소 경로 부재"
fi
if grep -q '호출 직전 한 줄 선언' skills/decomposing-ko/SKILL.md && grep -q 'implementing-ko 를 호출합니다' skills/decomposing-ko/SKILL.md; then
  ok "decomposing-ko P4 implement 선언 넛지 존재 (R-3 투명성)"
else
  nope "decomposing-ko P4 선언 넛지 소실" "implementing-ko 자동호출 R-3 warn 재발"
fi

# ── /security-scan 소유확인 게이트 (M3, 20260806) ────────────────
# DAST 는 타인 서버에 쏘면 불법이다. 소유 확인 프롬프트는 **법적 안전장치**인데
# 커맨드 문서에 문구만 있고 이를 잠그는 테스트가 0 이었다 — 리팩터링에서 조용히 사라질 수 있다.
S=commands/security-scan.md
# ★ 프롬프트 **한 줄** 안에 소유확인 + [y/N] 이 함께 있어야 한다.
#   느슨하게 '본인 소유' 만 보면 §안티패턴의 서술문("본인 소유가 아닌 서버를 스캔하면 불법")에
#   걸려 프롬프트를 지워도 통과한다 — mutation 으로 실제 확인된 false-pass.
if grep -qE '본인 소유.*\[y/N\]' "$S"; then
  ok "security-scan DAST 소유확인 프롬프트 존재 (법적 안전장치)"
else
  nope "security-scan 소유확인 프롬프트 소실" "'본인 소유…[y/N]' 단일 줄 부재"
fi
if grep -qE '무단.*불법|불법.*무단|무단 스캔' "$S"; then
  ok "security-scan 무단 스캔 위법 고지 존재"
else
  nope "security-scan 위법 고지 소실" "무단 스캔 경고 문구 부재"
fi
# 승인 없이 dast-scan.sh 를 먼저 실행하는 순서 역전 방지 — 경고(Process 1)가 DAST(Process 3)보다 앞
_l_warn=$(grep -n '능동 스캔 경고' "$S" | head -1 | cut -d: -f1)
_l_dast=$(grep -n 'dast-scan.sh' "$S" | head -1 | cut -d: -f1)
if [ -n "$_l_warn" ] && [ -n "$_l_dast" ] && [ "$_l_warn" -lt "$_l_dast" ]; then
  ok "security-scan 승인→DAST 순서 보존"
else
  nope "security-scan 순서 역전" "warn=$_l_warn dast=$_l_dast"
fi

# ── self-config 적대감사 토큰 경고 (M3 동반) ─────────────────────
if has "$S" 'self-config' '토큰 비용' '\[y/N\]'; then
  ok "security-scan --self-config 토큰 경고 게이트 존재"
else
  nope "security-scan self-config 토큰 경고 소실" "3 서브에이전트 dispatch 무경고"
fi

# ── task id 규격 게이트 배선 (20261001-task-id-guard) ──
if has scripts/dag/emit-context.sh 'check-task-ids\.sh' 'task id 규격 위반'; then
  ok "task-ids: emit-context 가 check-task-ids 를 구현 전에 호출"
else
  nope "task-ids: emit-context 배선 부재"
fi

# ── 숫자 전용 task id 규약 문서화 (20261001-task-id-guard AC-7) ──
if has templates/tasks.md '숫자 전용' 'T1a'; then ok "task-ids: templates/tasks.md 숫자 전용 규약"; else nope "task-ids: templates/tasks.md 규약 문구 부재"; fi
if has skills/decomposing-ko/SKILL.md '숫자 전용' 'check-task-ids'; then ok "task-ids: decomposing-ko 숫자 전용 규약·판정기 언급"; else nope "task-ids: decomposing-ko 규약 문구 부재"; fi

# ── FID 스코프 게이트 배선 (20261007-fid-size-gate) ──
if has scripts/dag/emit-context.sh 'bash "\$_FS_SH"' 'FID 스코프 초과'; then
  ok "fid-size: emit-context 가 check-fid-size 를 구현 전에 호출"
else
  nope "fid-size: emit-context 배선 부재"
fi
if has templates/tasks.md '분할 계획' 'check-fid-size'; then ok "fid-size: templates/tasks.md 분할 계획행 규약·판정기 언급"; else nope "fid-size: templates/tasks.md 규약 문구 부재"; fi
if has skills/decomposing-ko/SKILL.md '분할 계획' 'check-fid-size'; then ok "fid-size: decomposing-ko 분할 계획행·판정기 언급"; else nope "fid-size: decomposing-ko 규약 문구 부재"; fi

# ── 무인 계약의 리프 전달 · 범위 위생 (20261007-fable-tips) ──
if has scripts/dag/emit-context.sh '## 7\. 실행 모드' 'run_mode' '사용자와 직접 대화할 수 없다'; then
  ok "fable-tips: emit-context 가 dispatch-context §7 실행 모드를 쓴다"
else
  nope "fable-tips: emit-context §7 배선 부재"
fi
if has agents/implementer-ko.md '## 실행 모드 계약' '시작 시 한 번에' '의존 없는 나머지는 끝까지' 'NEEDS_APPROVAL' '의견·설명만 요청'; then
  ok "fable-tips: implementer-ko 실행 모드 계약 5항목"
else
  nope "fable-tips: implementer-ko 실행 모드 계약 문구 부재"
fi
if has agents/implementer-ko.md '## 범위 위생' '무관 발견:' '`Edit` 로 필요한 부분만' '임시 확인 코드를 남기지 않는다' 'RED 테스트는 이 규칙의 예외가 아니라'; then
  ok "fable-tips: implementer-ko 범위 위생(무관 발견·부분 수정·임시 코드·TDD 예외 아님)"
else
  nope "fable-tips: implementer-ko 범위 위생 문구 부재"
fi
if has templates/dispatch-context.md '## 7\. 실행 모드'; then ok "fable-tips: dispatch-context 템플릿 §7"; else nope "fable-tips: 템플릿 §7 부재"; fi

# ── 사용자 전용 command 는 모델 자동 호출을 막는다 (20261007-doc-conformance) ──
#   공식 문서(skills): `disable-model-invocation: true` = "Description not in context, full skill loads when invoked".
#   release·promote·e2e-test 처럼 부작용이 있는 명령을 모델이 스스로 부르지 못하게 하고, 상시 목록에서 빠진다
#   (실측 `/context`: specops skill 행 54→32, ~870 tok 절감 — `claude plugin details` 투영값은 이 플래그를 반영하지 않는다).
#   모델이 부를 수 있어야 하는 init-project(메타 skill 이 y 응답 시 호출)·status(재개 조회)는 켜 두지 않는다.
_dmi_ok=ok; _dmi_n=0
for c in brainstorming design-interface design-interfaces design-screen design-screens doctor e2e-test gbrain improve-arch log maintain-lite maintain promote release security-scan start-all-auto start-all start-auto start-foundation start-lite start statusline-install; do
  _dmi_n=$((_dmi_n+1))
  awk 'NR==1&&$0=="---"{on=1;next} on&&$0=="---"{exit} on' "$PLUGIN/commands/$c.md" | grep -qx 'disable-model-invocation: true' || { _dmi_ok=no; echo "  (플래그 누락: commands/$c.md)"; }
done
for c in init-project status; do
  awk 'NR==1&&$0=="---"{on=1;next} on&&$0=="---"{exit} on' "$PLUGIN/commands/$c.md" | grep -q 'disable-model-invocation' && { _dmi_ok=no; echo "  (모델 호출 필요 command 에 플래그: $c)"; }
done
[ "$_dmi_ok" = ok ] && ok "dmi: 사용자 전용 command ${_dmi_n}종 disable-model-invocation · init-project·status 는 제외" || nope "dmi: command 플래그 계약 위반"
# 비활성 command 를 skill 호출 문법(specops-ko:<cmd>)으로 부르는 본문이 없다 — 있으면 모델이 못 불러 체인이 끊긴다
_dmi_ref=$(cd "$PLUGIN" && git grep -n -E 'specops-ko:(brainstorming|design-interfaces?|design-screens?|doctor|e2e-test|gbrain|improve-arch|log|maintain-lite|maintain|promote|release|security-scan|start-all-auto|start-all|start-auto|start-foundation|start-lite|start|statusline-install)([^-a-z]|$)' -- skills agents hooks 2>/dev/null | head -3)
[ -z "$_dmi_ref" ] && ok "dmi: 비활성 command 를 모델이 skill 로 호출하는 본문 0건" || nope "dmi: 비활성 command 호출 참조" "$_dmi_ref"

# ── implementer-ko 가 karpathy-ko 를 프리로드한다 (공식 sub-agents: `skills` frontmatter = 시작 시 전체 내용 주입) ──
#   실측: --plugin-dir 로 구현자를 띄워 첫 제목 `# Karpathy 행동 원칙` 이 컨텍스트에 있음을 확인(맨 이름 `karpathy-ko` 로 해석됨).
#   프리로드 대상은 disable-model-invocation 이 아닌 skill 이어야 한다(문서: 그런 skill 은 프리로드 불가).
if awk 'NR==1&&$0=="---"{on=1;next} on&&$0=="---"{exit} on' agents/implementer-ko.md 2>/dev/null | grep -q '^  - karpathy-ko$' \
   || awk 'NR==1&&$0=="---"{on=1;next} on&&$0=="---"{exit} on' "$PLUGIN/agents/implementer-ko.md" | grep -q '^  - karpathy-ko$'; then
  ok "preload: implementer-ko frontmatter skills 에 karpathy-ko"
else
  nope "preload: implementer-ko skills 프리로드 부재"
fi
if ! awk 'NR==1&&$0=="---"{on=1;next} on&&$0=="---"{exit} on' "$PLUGIN/skills/karpathy-ko/SKILL.md" | grep -q 'disable-model-invocation'; then
  ok "preload: karpathy-ko 는 프리로드 가능(disable-model-invocation 아님)"
else
  nope "preload: karpathy-ko 가 disable-model-invocation — 프리로드 불가"
fi

# ── 20261005 전체 스위트 병행 · 리뷰어 실행 예산 (implementing-ko) ──
# Phase A 직후 run-all 백그라운드 병행(리뷰 대기와 겹침) + 리뷰어 실행량 상한. 문구가 사라지면 병행·예산이 조용히 꺼진다.
if has skills/implementing-ko/SKILL.md '전체 스위트 병행' 'run-all\.sh --quiet' 'run-all\.log' '증거가 아니다' '라운드마다 다시 띄우지 않는다' 'FAILED. 줄을 사용자에게 알리되' '임시 복사본'; then
  ok "implementing-ko 전체 스위트 병행 계약 존재 (백그라운드·log·비증거·수정 라운드·FAIL 알림·실 트리 변조 금지)"
else
  nope "implementing-ko 전체 스위트 병행 계약 소실" "병행 실행 절차 또는 안전 규칙 부재"
fi
if has skills/implementing-ko/SKILL.md '리뷰어 실행 예산' '핵심 실행 2회' '되돌려-관찰 3회' '전체 소비자 스위트 재실행은 하지 않는다' 'strict. 는 종전 그대로'; then
  ok "implementing-ko 리뷰어 실행 예산 존재 (B 2회·C 3회·전체 재실행 금지·strict 불변)"
else
  nope "implementing-ko 리뷰어 실행 예산 소실" "리뷰어 재실행이 다시 무제한이 된다"
fi

# ── 20261005 전체 스위트 신선도 확인 (verifying-evidence-ko) ──
# FRESH 면 수동 전체 스위트 생략, 그 밖(STALE·부재·FAIL·판정 불가)은 포그라운드 재실행. 게이트 증거는 별개.
if has skills/verifying-evidence-ko/SKILL.md '전체 스위트 신선도 확인' 'full-suite-fresh\.sh' '재실행을 생략' '완료줄' '생략 판정이 애매하면 \*\*재실행\*\*' '게이트 증거는 여전히' 'PARTIAL·NOT_RUN 이면' '지문 한계'; then
  ok "verifying-evidence-ko 신선도 확인 절차 존재 (FRESH 생략·백그라운드 대기·애매하면 재실행·게이트 증거 별개)"
else
  nope "verifying-evidence-ko 신선도 확인 절차 소실" "생략 조건이 불명확해지거나 재실행 폴백이 사라진다"
fi
# ── 20261005 end-loaded 리뷰 완료 FID 의 기계적 단계 생략 (verifying-evidence-ko → review-skip-pass.sh) ──
# 조건 충족 시 requesting·receiving-code-review-ko 를 호출하지 않고 security-review-ko 로 간다. 문구가 사라지면 두 skill 이 다시 매번 주입된다.
if has skills/verifying-evidence-ko/SKILL.md 'review-skip-pass\.sh' 'rc 0 .*호출하지 않고.*Skill: specops-ko:security-review-ko' 'rc 1 이면.*아래 기본 경로다' '판정이 애매하면 기본 경로다'; then
  ok "verifying-evidence-ko review-skip-pass fast path 존재 (rc 0 → security-review · rc 1 → 종전 · 애매하면 기본)"
else
  nope "verifying-evidence-ko review-skip-pass fast path 소실" "end-loaded FID 의 기계적 리뷰 단계 생략 문구 부재"
fi



# ── 20261005 서브에이전트 모델·effort 프로파일 — 구현자 sonnet·medium + 재dispatch 상향 규칙 ──
# 구현자는 기본 Sonnet 이고 BLOCKED·Phase B/C FAIL 재dispatch 때만 부모가 opus 로 1회 상향한다. 문구가 사라지면 상향 근거가 없어진다.
# shellcheck disable=SC2016  # 패턴 안의 백틱은 리터럴이다
if grep -qx 'model: sonnet' agents/implementer-ko.md && grep -qx 'effort: medium' agents/implementer-ko.md \
   && has skills/implementing-ko/SKILL.md '재dispatch 시 \(상향 규칙\)' '인자로 `opus` 를 지정해 \*\*1회 상향\*\*'; then
  ok "implementer-ko sonnet·medium + implementing-ko 재dispatch opus 1회 상향 규칙 존재"
else
  nope "implementer 프로파일·상향 규칙 소실" "implementer-ko frontmatter 또는 implementing-ko 상향 규칙 문구 부재"
fi


# ── 20261005 README 모델·effort 운용 가이드 — 프로파일 표·effort 우선순위·덮어쓰기·문서 미확인 고지 ──
# 사용자가 환경변수 우선순위와 덮어쓰기를 알아야 프로파일이 의도대로 적용된다. 절이 사라지면 안내가 끊긴다.
if has README.md '^## 모델 · effort 운용' 'CLAUDE_CODE_EFFORT_LEVEL' 'CLAUDE_CODE_SUBAGENT_MODEL_FORCE' '문서 미확인'; then
  ok "README 모델·effort 운용 가이드 존재 (우선순위·덮어쓰기·문서 미확인 고지)"
else
  nope "README 모델·effort 운용 가이드 소실" "프로파일 표·환경변수 우선순위·덮어쓰기·한계 고지 중 일부 부재"
fi

finish
