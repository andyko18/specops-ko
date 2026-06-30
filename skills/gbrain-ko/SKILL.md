---
name: gbrain-ko
description: 개발 세션 인사이트를 learnings.jsonl에서 조회·요약 — 최신 10건 + 전체 개수 출력, --fid 필터링 가능
layer: 2
reference_upstream: specops-auto-ko 독자 추가 (garrytan/gstack office-hours gbrain 패턴 한국어 재창작)
specops_version: 1.28.0
used_by: /gbrain
---

# gbrain — 세션 인사이트 조회·요약

## 개요

`scripts/gbrain-append.sh`로 누적된 `.specops/memory/learnings.jsonl` 레코드를 읽어 최신 10건을 요약 출력한다.

- 레코드에 `confidence`(low/medium/high) 필드가 있으면 조회·요약 출력에 신뢰도로 표시한다 (없으면 생략 — 기존 레코드 호환).

## 사용법

```
/gbrain [--fid FID]
```

## 프로세스

### Step 1: learnings.jsonl 존재 확인

```bash
GBRAIN_FILE="${GBRAIN_FILE:-.specops/memory/learnings.jsonl}"
if [ ! -f "$GBRAIN_FILE" ]; then
  echo "learnings.jsonl 없음 — 아직 인사이트 없음"
  exit 0
fi
```

### Step 2: 전체 개수 + 최신 10건 출력

```bash
total=$(wc -l < "$GBRAIN_FILE" | tr -d ' ')
echo "## gbrain 인사이트 요약 (전체 ${total}건)"
echo ""
echo "### 최신 10건"

parse_line() {
  local line="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$line" <<'PYEOF'
import sys, json
try:
    obj = json.loads(sys.argv[1])
    ts = obj.get("ts", "")
    fid = obj.get("fid", "")
    insight = obj.get("insight", "")
    conf = obj.get("confidence", "")
    fid_part = f" (FID: {fid})" if fid else ""
    conf_part = f" [conf:{conf}]" if conf else ""
    print(f"- [{ts}]{fid_part} {insight}{conf_part}")
except Exception:
    print(f"- [parse error] {sys.argv[1][:80]}")
PYEOF
  else
    ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
    insight=$(echo "$line" | grep -o '"insight":"[^"]*"' | cut -d'"' -f4)
    fid=$(echo "$line" | grep -o '"fid":"[^"]*"' | cut -d'"' -f4)
    conf=$(echo "$line" | grep -o '"confidence":"[^"]*"' | cut -d'"' -f4)
    echo "- [$ts]${fid:+ (FID: $fid)} $insight${conf:+ [conf:$conf]}"
  fi
}

tail -10 "$GBRAIN_FILE" | while IFS= read -r line; do
  parse_line "$line"
done
```

### Step 3: --fid 필터링 (인자 지정 시)

```bash
FID_FILTER="${1:-}"
if [ -n "$FID_FILTER" ]; then
  echo ""
  echo "### FID 필터: $FID_FILTER"
  grep -F "\"fid\":\"$FID_FILTER\"" "$GBRAIN_FILE" | while IFS= read -r line; do
    parse_line "$line"
  done
fi
```

## 연계 유틸 (learning-loop)

| 스크립트 | 역할 | 호출 지점 |
|---|---|---|
| `scripts/gbrain-append.sh` | 인사이트 1줄 기록 | performance-test-ko 학습 추출 (자동) + 수동 |
| `scripts/gbrain-collect.sh <FID>` | handoffs/evidence 결정적 수집 | performance-test-ko 학습 추출 1단계 |
| `scripts/gbrain-recall.sh "<질의>" [--top N]` | 토큰 중첩 관련 인사이트 조회 | specifying-ko Step 1 환류 (자동) + 수동 |

learnings.jsonl 은 git 추적 (학습 자산 영속 — gitignore 예외).

## 인사이트 추가

세션 중 발견한 패턴·주의사항을 추가:

```bash
bash scripts/gbrain-append.sh "인사이트 내용" --fid <FID> --tags tag1,tag2
```

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 skill 적용 |
|---|---|
| 1 **투명성** | 전체 개수 + 최신 10건 동시 출력 |
| 2 **문지기** | 파일 미존재 시 조용히 안내 후 종료 |
| 3 **깊이** | python3 json 파싱 (기본) — 큰따옴표·이스케이프 포함 insight 완전 지원 |
| 4 **주권 존중** | 조회·요약만. 삭제·수정 기능 없음 |
| 5 **한계 고백** | python3 미설치 시 grep fallback — 큰따옴표 포함 insight 깨질 수 있음 |

## 참조

- `scripts/gbrain-append.sh` — 인사이트 추가 스크립트
- `commands/gbrain.md` — 슬래시 진입점
- `.specops/memory/learnings.jsonl` — 저장소
- upstream 패턴: garrytan/gstack office-hours gbrain 누적 패턴

## 다음 skill

chain 종료. 본 skill은 조회·요약만. 인사이트 추가는 `scripts/gbrain-append.sh` 직접 호출.
