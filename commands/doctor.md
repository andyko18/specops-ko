---
name: doctor
description: specops 설치·환경 건강 진단 — git hook 2단 게이트·memory 채움·고아 FID·progress 정합 4항목 read-only 점검
triggers:
  - "/doctor"
mode: ask
specops_version: 1.62.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-ko 독자 추가
---

# /doctor

## 목적

사용자 프로젝트의 **specops 설치·환경 건강**을 read-only 로 진단한다. `validate-structure.sh` 는 플러그인 개발자용이라 사용자 프로젝트 상태를 보는 층이 없었다.

`/status` 와 역할이 다르다 — `/status` = FID 진행 상황, `/doctor` = 설치·환경 건강.

## Process

1. `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/doctor.sh` 실행
2. 출력 표를 그대로 사용자에게 제시
3. `⚠️` 항목의 **조치 명령**을 함께 안내

## 점검 항목

| 항목 | 판정 |
|---|---|
| `git_hooks` | `core.hooksPath=.githooks` + `pre-commit`·`pre-push` 실행 가능 |
| `memory` | `.specops/memory/*.md` placeholder 잔존 (판정 SoT = `scan-enrich-placeholders.sh`) |
| `orphan_fid` | `spec.md` 만 있고 `tasks.md`·`evidence.md` 둘 다 없는 FID |
| `progress` | `/verify PASS` 기록인데 `evidence.md` 부재 |

## 계약

- **항상 exit 0** — 조회 도구. 어떤 흐름도 막지 않는다.
- **read-only** — 어떤 파일도 쓰지 않는다.
- `--json` 으로 기계 판독 가능.
- `.specops/` 부재 시 안내 후 종료 (비-specops repo 면제).

## 안티패턴

- **자동 수정** — 본 커맨드는 진단만. 조치는 사용자가 실행한다 (5원칙 4 주권).
- **게이트화** — exit 0 계약을 깨고 CI 를 막지 않는다. 필요해지면 `--strict` 를 별도 설계한다.

## 참조

- `scripts/doctor.sh` — 진단 본체
- `scripts/_internal/install-git-hooks.sh` — `git_hooks` ⚠️ 조치
- `commands/status.md` — FID 진행 상황 (역할 구분)
