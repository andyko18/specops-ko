# Pair Artifact Cross-Review

**상태**: 권장 사례 (v0.1.0, 2026-04-22)
**근거**: FRICTION-LOG F-14 · dogfood FID `20260422-csv-lines`

## 정의

**짝 아티팩트** (pair artifact) 는 기능적으로 대칭인 두 산출물을 말한다. 예:

- `wc-lines` (물리 라인 카운터) ↔ `csv-lines` (논리 레코드 카운터)
- `json-pretty` (예쁜 출력) ↔ `json-minify` (최소화 출력)
- `encode-base64` ↔ `decode-base64`

**Pair Artifact Cross-Review** 는 두 번째 짝 아티팩트를 Lifecycle 로 빌드할 때 외부 리뷰어가 **두 아티팩트의 규약 일관성을 교차 점검**하여 첫 번째 아티팩트의 잠재 버그를 부수적으로 포착하는 현상이다.

## PoC 사례

`csv-lines` 외부 리뷰 (`requesting-code-review-ko` 단계, 2026-04-22 09:50) 에서 리뷰어가 일관성 점검 중 기존 `wc-lines` 의 버그를 발견:

| 파일 | 라인 | 코드 | 영향 |
|---|---|---|---|
| `wc-lines` | 11 | `f=$1`  **비인용** | 공백 포함 파일명(`wc-lines "my file.txt"`) 에서 `$1` 전개 시 공백 분리 → 실제 버그 |
| `csv-lines` | 11 | `f="$1"` **인용** | 동일 실수 회피 |

리뷰어가 csv-lines 를 점검하며 "wc-lines 와 일관성이 있는가" 를 묻던 중 이 차이를 발견. 단일 FID 리뷰에서는 드러나지 않을 버그를 **교차 비교** 로 포착.

## 적용 조건

아래 모든 조건을 만족할 때 cross-review 가치가 발현된다:

1. **동일 도메인** — 두 아티팩트가 같은 문제 공간 (파일 카운팅, 인코딩, 파싱 등) 에 속함
2. **공유 규약** — shebang · exit code · error message prefix · CLI flag 패턴 등이 같은 convention 을 따름
3. **순차 빌드** — 하나가 먼저 빌드되고 다른 하나가 뒤이어 빌드됨 (동시 빌드는 교차 point 가 애매)
4. **동일 저장소** — 외부 리뷰어가 두 아티팩트 모두 직접 읽을 수 있음

## 운용 권장

### 1. `requesting-code-review-ko` 외부 리뷰어 프롬프트에 포함

외부 리뷰 요청 시 다음 지시를 프롬프트에 추가:

> 프로젝트에 현 FID 의 짝 아티팩트가 존재하는지 확인하고, 있다면 두 아티팩트의 shebang · exit code · error prefix · 변수 quoting 스타일을 대조해 불일치를 보고하라.

### 2. 짝 아티팩트 선언 (선택)

spec.md 의 §개요 또는 §참조 섹션에 명시:

```markdown
## 짝 아티팩트

- `wc-lines` (FID 20260421-wc-lines) — 물리 라인 카운터. 본 아티팩트는 논리 레코드 카운터로 기능 대칭.
```

선언이 있으면 cross-review 자동화 여지 (예: 리뷰어 프롬프트가 spec.md §짝 아티팩트를 읽고 해당 파일을 자동 참조).

### 3. 발견 이슈 처리 경로

cross-review 로 **첫 번째 아티팩트의 버그** 가 발견된 경우:

- **현 Lifecycle 범위 외** — 현 FID 의 spec/AC/verifying 는 그대로 완주
- **FRICTION-LOG 에 기록** — "교차 리뷰 부수 발견" 항목으로 로그
- **후속 Lifecycle 진입 권장** — 첫 번째 아티팩트의 fix 를 별도 `/start` 로 처리. FRICTION-LOG 항목이 spec 입력의 근거 증거

## 안티패턴 — 하지 말 것

- **현 Lifecycle 에서 첫 번째 아티팩트 함께 수정** — sprint-contracts 상 범위 이탈. AC 가 첫 번째 아티팩트를 커버하지 않음
- **발견 자체를 무시** — 버그를 알고도 기록 안 하면 다른 Lifecycle 에서 재발
- **교차 비교를 유사도 높음 근거로 강제 통일** — 두 아티팩트가 각자의 이유로 다른 선택을 했을 수 있음 (예: `wc-lines` 는 stdin 지원, `csv-lines` 는 미지원). 불일치 ≠ 버그

## 참조

- Case study: `docs/case-studies/2026-04-22-specops-auto-ko-v0.0-poc-pass.md` §F-14
- Dogfood 로그: `~/Project/0.Claude/dogfood-demo/FRICTION-LOG.md` F-14
- 연관 skill: `skills/requesting-code-review-ko/SKILL.md` · `skills/specifying-ko/SKILL.md`
