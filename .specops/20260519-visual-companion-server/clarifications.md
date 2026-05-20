<!-- FID: 20260519-visual-companion-server -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260519-visual-companion-server

**status**: RESOLVED
**timestamp**: 2026-05-19

---

## Q1 · ws-package-install · DESIRABLE

**질문**: `ws` npm 패키지 설치 전략 — scripts/ 디렉토리에 package.json 추가 vs 전역 설치 가이드만?

**답변**: `skills/brainstorming-ko/scripts/package.json` 추가 (표준 Node.js 패턴). start-server.sh가 `npm install` 여부를 안내. package.json에 `{"dependencies": {"ws": "^8.0.0"}}` 포함.

**영향**: T1(server.cjs)에 package.json 신규 추가 태스크 포함. AC 추가 없음 (NFR-2 범위 내).

---

## Q2 · pid-file-location · DESIRABLE

**질문**: `.vc-server.pid` 저장 위치 — 프로젝트 루트 vs `$HOME` vs `/tmp/`?

**답변**: `/tmp/.vc-server.pid` — 플랫폼 간 일관, 재시작 시 자동 정리, 권한 문제 없음.

**영향**: start-server.sh·stop-server.sh 모두 `/tmp/.vc-server.pid` 사용. AC-3·AC-4 검증 명령 반영.

---

## Q3 · browser-open · DESIRABLE

**질문**: 브라우저 오픈 명령 — macOS 전용 `open` vs 멀티플랫폼 감지?

**답변**: OS 감지 — macOS: `open`, Linux: `xdg-open`, 기타: 경고 출력 후 URL 표시. YAGNI 수준에서 두 플랫폼 지원.

**영향**: start-server.sh에 `uname` 기반 분기 추가. AC 추가 없음.

---

*작성: clarifying-ko · 2026-05-19 · FID: 20260519-visual-companion-server · BLOCKING 0건 / DESIRABLE 3건*
