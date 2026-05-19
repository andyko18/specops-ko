<!-- FID: 20260519-gbrain-skill -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: github/spec-kit plan-template.md + obra/superpowers writing-plans -->
<!-- layer: Lifecycle-Artifact -->

# gbrain-ko 구현 플랜 — 20260519-gbrain-skill

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: `scripts/gbrain-append.sh`로 `.specops/memory/learnings.jsonl`에 JSONL 레코드를 추가하고, `skills/gbrain-ko/SKILL.md` + `commands/gbrain.md`로 `/gbrain` 슬래시 조회·요약 기능을 제공한다.

**아키텍처**: bash 단일 파일 스크립트 패턴 (jq 미사용). `gbrain-append.sh`는 인자를 받아 JSONL 1줄을 append. `gbrain-ko/SKILL.md`는 `cat + tail` 조합으로 최신 10건 출력 프로세스를 명시. `commands/gbrain.md`는 슬래시 진입점 역할.

**기술 스택**: bash 3.2+, date, cat, tail, grep (외부 의존성 없음)

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-R-1

---

## 1. 가정 (5원칙 5번)

- `.specops/memory/` 디렉토리는 사전 존재 (brainstorming-ko 선례 — 실측 미확인)
- bash `date -u +%Y-%m-%dT%H:%M:%SZ` 포맷이 macOS + Linux 모두 동작 (실측 미확인)
- JSONL 레코드는 단일 행이며 insight 내용에 큰따옴표가 없다고 가정 (이스케이프 처리 미구현 — YAGNI)

## 2. 파일 구조

### 생성
- `scripts/tests/test-gbrain.sh` — gbrain 기능 정적 검증 테스트 (AC-1~AC-7, T1.a~T7.a)
- `scripts/gbrain-append.sh` — JSONL 레코드 추가 스크립트 (FR-1~FR-3)
- `skills/gbrain-ko/SKILL.md` — 조회·요약 skill 본문 (FR-4)
- `commands/gbrain.md` — `/gbrain` 슬래시 진입점 (FR-5)

### 수정
- `scripts/_internal/.structure-baseline` — skills 24→25, commands 8→9
- `scripts/_internal/validate-structure.sh:5` — 주석 갱신 (1줄)

## 3. 데이터 모델

**JSONL 레코드 포맷** (한 줄 = 유효한 JSON):
```json
{"ts":"2026-05-19T10:30:00Z","fid":"20260519-foo","insight":"내용","tags":[]}
```

필드:
- `ts`: ISO-8601 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`)
- `fid`: `--fid FID` 인자값, 미지정 시 `""`
- `insight`: 첫 번째 위치 인자 (필수)
- `tags`: `--tags t1,t2` 인자값을 JSON 배열로 변환, 미지정 시 `[]`

## 4. 계약

**gbrain-append.sh 인터페이스**:
```bash
bash scripts/gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]
# exit 0: 성공 (레코드 append)
# exit 1: insight 인자 없음 (usage 출력)
```

**learnings.jsonl 경로**: `.specops/memory/learnings.jsonl`

## 5. 태스크 개요

1. **T1: 테스트 파일 작성** (RED — 선행) — `test-gbrain.sh` 작성, 전 케이스 FAIL 확인
2. **T2: gbrain-append.sh 구현** (독립 — T1 이후 병렬 가능) — 스크립트 작성, T1 GREEN
3. **T3: SKILL.md + command 구현** (독립 — T2와 병렬 가능) — SKILL.md + command 작성, T1 AC-4~AC-6 GREEN
4. **T4: baseline + validate 갱신** (의존: T2, T3) — 카운트 수정, validate-structure.sh PASS

## 6. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| `date -u` 포맷 플랫폼 차이 | M | `date -u +%Y-%m-%dT%H:%M:%SZ` — macOS/Linux 공통 포맷 사용 |
| insight에 큰따옴표 포함 시 JSON 깨짐 | L | YAGNI — 현재 단순 이스케이프 미처리, 가정 §1에 명시 |
| `.specops/memory/` 미존재 | M | `mkdir -p .specops/memory/` gbrain-append.sh 내부에서 자동 실행 |

## 7. 자체 검토 (5원칙 체크리스트)

- [x] **투명성**: 각 태스크 카테고리에 "왜" 한 줄 포함 (T1 선행 이유: RED 먼저, T4 후행 이유: 파일 수 확정 후)
- [x] **문지기**: 파괴적 작업 없음 — 신규 파일 추가 + 주석 1줄 수정만
- [x] **주권 존중**: 파괴적 작업 없으므로 ⚠️ 표기 불필요
- [x] **한계 고백**: §1 가정 3건 명시 (`.specops/memory/` 존재, date 포맷, 큰따옴표 미이스케이프)

## 8. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음

## 9. 다음 단계

`decomposing-ko` → 태스크별 TDD 5스텝 분해 → `implementing-ko` 서브에이전트 dispatch.

---

*작성: planning-ko · 2026-05-19 · FID: 20260519-gbrain-skill · 생성 커맨드: /plan*
