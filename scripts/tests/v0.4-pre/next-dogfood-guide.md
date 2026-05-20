# v0.4-pre 실측 검증 dogfood 가이드

**목적**: v0.4-pre W1+W2 매처 정정 (commits `c2efe5c`, `6912ca6`)이 실제 dogfood에서 false positive 0건을 달성하는지 실측 검증.

**예상 시간**: 30-60분 (작은 기능 1건)

---

## ⭐ 추천 dogfood 대상: `timestamp-converter` bash CLI

**근거 4가지** (slug-cli와 다른 도메인 + 비슷한 규모):
1. **slug-cli와 다른 도메인** — 문자열 변환이 아닌 시간 변환, R-3·R-4 매처가 다른 lifecycle 발화 패턴에서 작동하는지 검증
2. **AC 명확** — Given/When/Then 쉽게 작성 (epoch ↔ ISO 8601 양방향)
3. **bash CLI** — `bash scripts/tests/test-*.sh` 컨벤션 사용 → R-4 W2 runner 확장 직접 검증
4. **~30-50 LOC** — slug-cli (~200 LOC)보다 작아 빠른 lifecycle

**대안** (사용자 선호 시):
- `url-decode` — 더 작음 (~20 LOC), 변환 도구 일관성
- `json-pretty` — 더 큼 (jq 의존), R-1·R-2 검증에 유리

---

## 사전 점검

```bash
# 1. v0.4-pre W1+W2 적용 확인
git log --oneline | grep -E "v0.4-pre" | head -3
# 기대: c2efe5c·6912ca6·966f7aa 3개 commit 보여야 함

# 2. archive 태그 보존 확인
git tag --list 'archive/*'
# 기대: archive/v0.2-v0.3-attempt-20260425, archive/v0.3-w5.4-demo-20260425

# 3. governance 회귀 0
bash scripts/tests/governance/test-rules.sh 2>&1 | tail -3
# 기대: ==== Results: PASS=36 FAIL=0 ====

# 4. 측정 helper 작동 확인
bash scripts/tests/v0.4-pre/measure-false-positives.sh .specops/20260425-slug-cli/friction-log.jsonl
# 기대: 정정 전 R-3=3 R-4=4 총 7건 출력
```

위 4개 모두 OK 시 다음 단계로.

---

## dogfood 진행 단계

### Step 1: Claude Code 재시작

- Claude Code 앱 또는 CLI 완전 종료
- 다시 실행
- **새 conversation** 시작 (기존 이어가기 ❌)

### Step 2: SessionStart hook 메타 skill 자동 주입 검증

새 conversation 첫 발화로:
```
specops-auto-ko 메타 skill이 활성화 되어있어?
```

**기대**: assistant가 메타 skill 본문 인용하며 응답 (5원칙 또는 자율 lifecycle 키워드 등장).

### Step 3: 자연어 진입 (timestamp-converter 추천)

```
epoch 시간(int)과 ISO 8601(string)을 양방향 변환하는 bash CLI 만들고 싶어
```

**예상 lifecycle 흐름**:
1. specifying-ko 자동 호출 → mode 추론 ("Standard" 추천)
2. clarifying-ko → 모호성 해소 (timezone 처리, 입력 형식 자동 감지 등)
3. planning-ko → plan.md 작성
4. decomposing-ko → tasks.md TDD 분해
5. implementing-ko → 서브에이전트 dispatch (또는 F-12 ESCAPE HATCH 집약)
6. verifying-evidence-ko → evidence.md 작성
7. requesting-code-review-ko → 외부 리뷰
8. (선택) receiving-code-review-ko → 피드백 반영

### Step 4: dogfood 종료 후 측정

```bash
# FID 자동 감지 (.specops/session-progress.md 첫 ## 섹션)
FID=$(grep -E '^## [0-9]{8}-' .specops/session-progress.md | head -1 | sed -E 's/## ([0-9]{8}-[a-z0-9-]+).*/\1/')
echo "FID: $FID"

# 매처 결과 측정 (W1+W2 정정 후 dogfood)
bash scripts/tests/v0.4-pre/measure-false-positives.sh \
  .specops/$FID/friction-log.jsonl \
  .specops/20260425-slug-cli/friction-log.jsonl
```

**예상 출력 (성공 시)**:
```
=== NEW: .specops/<new-FID>/friction-log.jsonl ===
총 매칭: ≤2
  R-3 (Skill 호출 선언 부재):    0~1
  R-4 (assertion + runner 부재): 0~1

=== BASELINE: .specops/20260425-slug-cli/friction-log.jsonl ===
총 매칭: 7

=== 정정 효과 ===
Baseline FP: 7
New FP: ≤2
감소율: ≥71%  (또는 100%)
```

**v0.4-pre PASS 기준**: 감소율 ≥80% (이상적으로 100%).

---

## 검증 항목 (5가지)

dogfood 진행 중 다음을 관찰:

| # | 검증 항목 | 어디서 확인 | 기대 |
|---|---|---|---|
| 1 | 메타 skill 자동 주입 | 첫 응답에 메타 skill 본문 인용 | ✅ 5원칙·lifecycle 키워드 등장 |
| 2 | mode 추론 (v0.3 부분 적용 흔적) | spec.md §0 | mode = Standard, 결정 근거 명시 |
| 3 | F-12 ESCAPE HATCH | dispatch-log.md Phase A | 동일 파일 쌍 시 1 cluster dispatch |
| 4 | R-3 false positive 감소 (v0.4-pre W1) | friction-log.jsonl R-3 카운트 | slug-cli 3건 → ≤1건 |
| 5 | R-4 false positive 감소 (v0.4-pre W2) | friction-log.jsonl R-4 카운트 | slug-cli 4건 → ≤1건 |

---

## 결과 보고

dogfood 종료 후 다음 conversation에서:
```
v0.4-pre 실측 검증 dogfood 완료. .specops/<new-FID>/ 분석해서 case-study 작성해줘
```

→ assistant가 자동으로 `docs/case-studies/2026-04-26-v0.4-pre-validation-dogfood.md` 작성.

case-study에 포함될 항목:
- 새 FID 메타 + 완주 commits
- 매처 false positive 측정 결과 (감소율 %)
- W1+W2 정정 효과 검증 (실제 dogfood vs slug-cli baseline)
- 미해결 false positive 패턴 발견 시 → v0.4 추가 매처 보강 후보

---

## 문제 발생 시 fallback

| 증상 | 진단 | 해결 |
|---|---|---|
| 메타 skill 미주입 | `cat ~/.claude/settings.json \| jq '.enabledPlugins'` | specops-auto-ko 활성 확인 |
| `/start` 미인식 | `/help` 입력 → specops-auto-ko 슬래시 표시 | marketplace 경로 점검 |
| R-3 false positive ≥3건 | friction-log evidence_snippet 분석 | 미커버 동사 → W1 regex 추가 확장 plan |
| R-4 false positive ≥3건 | evidence_snippet 분석 | 미커버 assertion 패턴 → W2 추가 plan |

---

*v0.4-pre 실측 검증 가이드 · 2026-04-26 · advisor 협의 v3 후속*
