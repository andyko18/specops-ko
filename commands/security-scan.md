---
name: security-scan
description: 온디맨드 보안 점검 슬래시 — SAST(소스코드) + DAST(동적) 능동 스캔
triggers:
  - "/security-scan"
mode: ask
specops_version: 1.18.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-auto-ko 독자 추가
---

# /security-scan [URL]

## 목적

소스코드 정적 분석(SAST) 및 배포된 서버의 동적 분석(DAST)을 온디맨드로 실행하는 독립 점검 슬래시.
라이프사이클 자동 게이트(security-review-ko)와는 독립적으로 개발자가 언제든 호출 가능.

## Process

1. **능동 스캔 경고** (URL 인자 있을 때만)
   - 메시지: `이 URL은 본인 소유 서버입니까? 무단 스캔은 불법 [y/N]`
   - 거절 시 중단 (exit 1)
   - 승인 시 → 2~3번 진행

2. **SAST 실행** — 소스코드 정적 분석
   ```bash
   bash scripts/security-scan.sh .
   ```
   - 전체 소스 스캔 (대상 디렉터리 고정: 현재 경로)
   - 취약점 목록 + 심각도(critical/high/medium/low) 출력

3. **DAST 실행** (URL 인자 있을 경우만)
   ```bash
   bash scripts/dast-scan.sh <URL>
   ```
   - 배포 서버에 대한 동적 점검
   - nuclei > ZAP(docker) > nikto 우선순위로 도구 탐지
   - 도구 부재 시 graceful skip (실행 실패 없음)
   - 취약점 등급별 집계 출력

4. **결과 종합**
   - SAST 결과 + DAST 결과 통합 리포트
   - critical/high 존재 시 추가 검토 안내

## 사용 예

### SAST만 (소스 검사)
```
/security-scan
```

### SAST + DAST (동적 검사 포함)
```
/security-scan https://api.example.com
```

## 안티패턴

- **무단 대상 스캔 금지** — 본인 소유가 아닌 서버를 스캔하면 불법(hacking). 소유 확인 후 승인만 진행
- **lifecycle 게이트와 혼동 금지** — 이 슬래시는 개발자 온디맨드 점검. 자동 PR/release 게이트는 security-review-ko 참조
- **CI/CD 자동화 금지** — interactive mode(ask) 설계 — 명시적 승인 필요

## 참조

- `scripts/security-scan.sh` — SAST 래퍼 (정적 분석)
- `scripts/dast-scan.sh` — DAST 래퍼 (동적 분석, nuclei/ZAP/nikto)
- `skills/security-review-ko/SKILL.md` — lifecycle 자동 보안 검증 gate
- AC: AC-1(command), AC-3(소유확인), AC-4(README), AC-R-2(회귀), AC-R-3(기존 무변경)

---

*specops-auto-ko v1.18.0 · 2026-06-20 · FID 20260620-security-scan-command*
