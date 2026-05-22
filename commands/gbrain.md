---
name: gbrain
description: 개발 세션 인사이트 조회·요약 슬래시 — gbrain-ko 호출. learnings.jsonl 최신 10건 + 전체 개수 출력.
triggers:
  - "/gbrain"
mode: ask
specops_version: 1.0.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-auto-ko 독자 추가 (garrytan/gstack office-hours gbrain 패턴 한국어 재창작)
---

# /gbrain [--fid <FID>]

## 목적

`.specops/memory/learnings.jsonl`에 누적된 개발 인사이트를 조회·요약한다.

## Process

1. **즉시 `specops-auto-ko:gbrain-ko` 호출** — `--fid` 인자를 그대로 전달
2. learnings.jsonl 읽기 → 전체 개수 + 최신 10건 출력
3. `--fid FID` 지정 시 해당 FID 레코드만 추가 출력

## 사용 예

```
/gbrain

→ gbrain-ko 호출
→ 전체 N건, 최신 10건 출력
```

```
/gbrain --fid 20260519-foo

→ 최신 10건 + "20260519-foo" FID 레코드 필터 출력
```

## 인사이트 추가

```bash
bash scripts/gbrain-append.sh "인사이트 내용" --fid <FID> --tags tag1,tag2
```

## 안티패턴

- **인사이트 수정·삭제** — 본 슬래시는 읽기 전용
- **자동 추가** — 추가는 `gbrain-append.sh` 수동 호출만

## 참조

- `skills/gbrain-ko/SKILL.md` — 실행 skill
- `scripts/gbrain-append.sh` — 인사이트 추가 스크립트
- `.specops/memory/learnings.jsonl` — 저장소

---

*specops-auto-ko v1.0.0 · 2026-05-19 · garrytan/gstack office-hours gbrain 패턴 한국어 재창작*
