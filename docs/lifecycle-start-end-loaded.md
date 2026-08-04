# `/start` implementing — end-loaded 리뷰

기본 `review_mode: end-loaded` (tasks.md YAML; 필드 부재 시 동일).

## 현재(기본)

```mermaid
flowchart TD
  D[decomposing] --> W[wave: Phase A only]
  W --> A1[task N: implementer]
  A1 --> R[receipt + commit]
  R --> W
  W -->|all A done| B[spec-reviewer FID x1]
  B --> C[code-reviewer FID x1]
  C --> V[verifying-evidence]
  V --> S[requesting: review-skip if B+C reports]
  S --> Sec[security → integration → perf → PR]
```

- B/C는 **1회씩**이지만 감사 파일은 **tid마다** `reviews/<tid>-B-report.md` / `-C-report.md`.
- requesting 추가 리뷰는 end-loaded C와 중복 → `review-skip.md` (`end-loaded: …`).

## 레거시 (`review_mode: per-task`)

```mermaid
flowchart TD
  D[decomposing] --> W[wave]
  W --> A[implementer]
  A --> B[spec-reviewer per task]
  B --> C[code-reviewer per task]
  C --> R[receipt + commit]
  R --> W
  W -->|done| F[최종 C if N≥2]
  F --> V[verify → request → …]
```

## 비용

| 모드 | 리뷰 dispatch |
|---|---|
| end-loaded | B×1 + C×1 (+ requesting skip) |
| per-task | (B+C)×N (+ 최종 C if N≥2) |
