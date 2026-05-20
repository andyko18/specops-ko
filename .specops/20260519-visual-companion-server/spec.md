<!-- FID: 20260519-visual-companion-server -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md -->
<!-- layer: Lifecycle-Artifact -->

# Visual Companion 서버 포팅 명세 — 20260519-visual-companion-server

## 1. 개요

**§유형**: 유지보수

**목적**: specifying-ko §Visual Companion에 선언만 되고 미구현인 WebSocket 서버 + 브라우저 UI를 `skills/brainstorming-ko/scripts/`에 실제 구현한다.

**배경**: obra/superpowers@v5.0.7는 `skills/brainstorming/scripts/` 아래 5개 파일로 Visual Companion 서버를 제공한다. specops-auto-ko는 specifying-ko:326에 `"(Phase 1 현재 — visual-companion 상세 가이드는 v0.1+에서 포팅)"` 주석만 존재한다. 사용자가 Visual Companion 수락 후 실제 서버가 없어 기능이 동작하지 않는다.

**성공 판정**: `bash skills/brainstorming-ko/scripts/start-server.sh`로 서버가 시작되고, Claude가 `helper.js`로 HTML을 전송하면 브라우저에 렌더링된다.

## 2. 범위

### 포함
- `server.cjs` — Node.js WebSocket 서버 (port 4242) (독립 — 병렬 구현 가능)
- `start-server.sh` — 서버 시작·PID 저장·브라우저 오픈 (독립 — 병렬 구현 가능)
- `stop-server.sh` — PID로 서버 종료 (독립 — 병렬 구현 가능)
- `frame-template.html` — WebSocket 수신 + HTML 렌더링 UI (독립 — 병렬 구현 가능)
- `helper.js` — Claude → 서버 콘텐츠 전송 클라이언트 (독립 — 병렬 구현 가능)
- `skills/specifying-ko/SKILL.md` line 326 — 포팅 완료 선언으로 교체 (독립 — 병렬 구현 가능)

### 제외 (YAGNI)
- HTTPS/WSS 지원 (로컬 전용)
- 다중 세션/탭 관리
- 인증/인가
- 히스토리 저장

## 3. 사용자 시나리오

### 주요 시나리오
**사용자**: Claude Code 세션에서 brainstorming-ko 진행 중인 사용자
**상황**: specifying-ko가 UI 설계 관련 시각 질문을 제안하며 "써보시겠어요?" 문의
**행동**: 사용자가 "예"로 응답 → Claude가 `start-server.sh` 실행 → 브라우저 오픈 → `helper.js`로 HTML mockup 전송
**기대 결과**: 브라우저 탭에 mockup이 실시간 렌더링됨

### 종료 시나리오
**행동**: 세션 종료 시 Claude가 `stop-server.sh` 실행
**기대 결과**: 서버 프로세스 종료, PID 파일 삭제

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `server.cjs`는 port 4242에서 WebSocket 서버를 시작한다 | must |
| FR-2 | `server.cjs`는 연결된 모든 클라이언트에 수신 메시지를 broadcast한다 | must |
| FR-3 | `start-server.sh`는 서버를 백그라운드로 시작하고 PID를 `.vc-server.pid`에 저장한다 | must |
| FR-4 | `start-server.sh`는 `frame-template.html`을 기본 브라우저로 연다 | must |
| FR-5 | `stop-server.sh`는 `.vc-server.pid`의 PID로 프로세스를 종료하고 파일을 삭제한다 | must |
| FR-6 | `frame-template.html`은 ws://localhost:4242에 WebSocket 연결을 수립한다 | must |
| FR-7 | `frame-template.html`은 수신 메시지(HTML 문자열)를 `#content` div에 innerHTML로 렌더링한다 | must |
| FR-8 | `helper.js`는 `sendToVisualCompanion(html)` 함수를 export한다 | must |
| FR-9 | `helper.js`는 서버 미기동 시 오류 메시지를 출력하고 조용히 실패한다 | must |
| FR-10 | `specifying-ko/SKILL.md` line 326의 포팅 주석을 실제 사용 가이드로 교체한다 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 런타임 | Node.js 18+ (실측 미확인) |
| NFR-2 | 의존 패키지 | `ws` npm 패키지 (선택적 — 미설치 시 시작 실패 + 오류 메시지) |
| NFR-3 | 범위 | 로컬 전용 (127.0.0.1 바인딩) |
| NFR-4 | 쉘 호환성 | bash 3.2+ (macOS 실측 · Linux 미검증) |

## 6. 제약사항

- 기존 `skills/brainstorming-ko/SKILL.md` 수정 없음 (scripts/ 신규 디렉토리만 추가)
- `validate-structure.sh` `file_counts` 변경 없음 (`skills/*/SKILL.md` glob 외 파일)
- `specifying-ko/SKILL.md` 수정 범위: line 326 1줄만

## 7. 데이터 흐름

```
Claude (helper.js)
  ↓ sendToVisualCompanion(html)
  ↓ WebSocket connect to ws://localhost:4242
server.cjs (port 4242)
  ↓ broadcast to all clients
frame-template.html (browser)
  ↓ document.getElementById('content').innerHTML = html
사용자 브라우저에 렌더링
```

## 8. 참조

- `.specops/20260519-visual-companion-server/current-state.md`
- `.specops/20260519-visual-companion-server/impact-analysis.md`
- upstream 원본: `obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md`

---

*작성: specifying-ko [유지보수 분기] · 2026-05-19 · FID: 20260519-visual-companion-server*
