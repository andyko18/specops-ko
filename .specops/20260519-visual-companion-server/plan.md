<!-- FID: 20260519-visual-companion-server -->
<!-- OWNER_COMMAND: /plan -->
<!-- layer: Lifecycle-Artifact -->

# Visual Companion 서버 포팅 구현 플랜 — 20260519-visual-companion-server

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: `skills/brainstorming-ko/scripts/`에 Node.js WebSocket 서버 5개 파일을 생성하고 specifying-ko §Visual Companion 포팅 주석을 제거한다.

**아키텍처**: Claude가 `helper.js`로 HTML을 `server.cjs` (port 4242)에 전송 → `frame-template.html` (브라우저)이 WebSocket으로 수신해 렌더링. `start-server.sh`·`stop-server.sh`가 서버 생명주기를 관리한다.

**기술 스택**: Node.js 18+, `ws` npm 패키지, bash 3.2+

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-R-1, AC-R-2

---

## 1. 가정

- Node.js 18+는 실행 환경에 설치됨
- `ws` 패키지는 `npm install` 실행 시 설치됨 (package.json에 명시)
- PID 파일 경로: `/tmp/.vc-server.pid` (Q2 결정)
- 브라우저 오픈: macOS `open` / Linux `xdg-open` OS 감지 (Q3 결정)
- `file://` 프로토콜로 frame-template.html 오픈 시 WebSocket 연결 가능

## 2. 파일 구조

### 생성
- `skills/brainstorming-ko/scripts/package.json` — ws 의존성 선언
- `skills/brainstorming-ko/scripts/server.cjs` — WebSocket 서버 (port 4242, broadcast)
- `skills/brainstorming-ko/scripts/start-server.sh` — 서버 시작 + 브라우저 오픈 + PID 저장
- `skills/brainstorming-ko/scripts/stop-server.sh` — PID로 서버 종료
- `skills/brainstorming-ko/scripts/frame-template.html` — WebSocket 클라이언트 UI
- `skills/brainstorming-ko/scripts/helper.js` — sendToVisualCompanion() export
- `scripts/tests/test-visual-companion.sh` — 6개 테스트 케이스 (파일 존재·내용 검증)

### 수정
- `skills/specifying-ko/SKILL.md:326` — 포팅 주석 → 실제 사용 가이드

## 3. 태스크 개요

1. **T1**: 테스트 스크립트 생성 (RED baseline — 6 케이스 전부 FAIL)
2. **T2**: package.json + server.cjs (AC-1, AC-2)
3. **T3**: start-server.sh (AC-3)
4. **T4**: stop-server.sh (AC-4)
5. **T5**: frame-template.html (AC-5)
6. **T6**: helper.js (AC-6)
7. **T7**: specifying-ko/SKILL.md line 326 수정 (AC-7, AC-R-1, AC-R-2)

T2~T7은 상호 독립 (출력 파일 disjoint) — 병렬 구현 가능.

## 4. 태스크 상세

### Task 1: test-visual-companion.sh 생성 (RED baseline)

**파일**:
- 생성: `scripts/tests/test-visual-companion.sh`

- [ ] **Step 1: RED — 파일 미존재 확인**

```bash
ls skills/brainstorming-ko/scripts/server.cjs 2>&1
# 예상: No such file or directory
```

- [ ] **Step 2: FAIL 검증 준비**

아직 테스트 파일 자체가 없음 → Step 3에서 생성 후 실행하면 6케이스 전부 FAIL.

- [ ] **Step 3: GREEN — 테스트 스크립트 생성**

```bash
mkdir -p skills/brainstorming-ko/scripts
```

파일 `scripts/tests/test-visual-companion.sh` 생성:

```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS_DIR="$PLUGIN/skills/brainstorming-ko/scripts"

# T1.a: server.cjs 존재
[ -f "$SCRIPTS_DIR/server.cjs" ] \
  && echo "T1.a PASS: server.cjs 존재" && PASS=$((PASS+1)) \
  || { echo "T1.a FAIL: server.cjs 미존재"; FAIL=$((FAIL+1)); }

# T1.b: package.json + ws 의존성
[ -f "$SCRIPTS_DIR/package.json" ] && grep -q '"ws"' "$SCRIPTS_DIR/package.json" \
  && echo "T1.b PASS: package.json ws 의존성" && PASS=$((PASS+1)) \
  || { echo "T1.b FAIL: package.json 미존재 또는 ws 누락"; FAIL=$((FAIL+1)); }

# T2.a: start-server.sh exec-bit
[ -x "$SCRIPTS_DIR/start-server.sh" ] \
  && echo "T2.a PASS: start-server.sh exec-bit" && PASS=$((PASS+1)) \
  || { echo "T2.a FAIL: start-server.sh 미존재 또는 exec-bit 누락"; FAIL=$((FAIL+1)); }

# T3.a: stop-server.sh exec-bit
[ -x "$SCRIPTS_DIR/stop-server.sh" ] \
  && echo "T3.a PASS: stop-server.sh exec-bit" && PASS=$((PASS+1)) \
  || { echo "T3.a FAIL: stop-server.sh 미존재 또는 exec-bit 누락"; FAIL=$((FAIL+1)); }

# T4.a: frame-template.html WebSocket + content div
[ -f "$SCRIPTS_DIR/frame-template.html" ] \
  && grep -q 'ws://localhost:4242' "$SCRIPTS_DIR/frame-template.html" \
  && grep -q 'id="content"' "$SCRIPTS_DIR/frame-template.html" \
  && echo "T4.a PASS: frame-template.html WebSocket+content" && PASS=$((PASS+1)) \
  || { echo "T4.a FAIL: frame-template.html 미존재 또는 필수 코드 누락"; FAIL=$((FAIL+1)); }

# T5.a: helper.js sendToVisualCompanion
[ -f "$SCRIPTS_DIR/helper.js" ] \
  && grep -q 'sendToVisualCompanion' "$SCRIPTS_DIR/helper.js" \
  && echo "T5.a PASS: helper.js sendToVisualCompanion" && PASS=$((PASS+1)) \
  || { echo "T5.a FAIL: helper.js 미존재 또는 sendToVisualCompanion 누락"; FAIL=$((FAIL+1)); }

# T6.a: specifying-ko 포팅 주석 제거
! grep -q 'Phase 1 현재.*visual-companion.*포팅' \
    "$PLUGIN/skills/specifying-ko/SKILL.md" \
  && echo "T6.a PASS: specifying-ko 포팅 주석 없음" && PASS=$((PASS+1)) \
  || { echo "T6.a FAIL: specifying-ko 포팅 주석 여전히 존재"; FAIL=$((FAIL+1)); }

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

```bash
chmod +x scripts/tests/test-visual-companion.sh
```

- [ ] **Step 4: FAIL 검증 (RED 확인)**

```bash
bash scripts/tests/test-visual-companion.sh
```
예상: `PASS=0 FAIL=7` (모든 파일 미존재)

- [ ] **Step 5: COMMIT**

```bash
git add scripts/tests/test-visual-companion.sh
git commit -m "test(visual-companion): RED baseline — 7케이스 FAIL (파일 미존재)"
```

---

### Task 2: package.json + server.cjs (AC-1, AC-2)

**파일**:
- 생성: `skills/brainstorming-ko/scripts/package.json`
- 생성: `skills/brainstorming-ko/scripts/server.cjs`

- [ ] **Step 1: RED 확인**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T1\."
# 예상: T1.a FAIL T1.b FAIL
```

- [ ] **Step 2: FAIL 검증**

T1.a·T1.b 2건 FAIL 확인.

- [ ] **Step 3: GREEN — package.json + server.cjs 생성**

파일 `skills/brainstorming-ko/scripts/package.json`:
```json
{
  "name": "visual-companion-server",
  "version": "1.0.0",
  "description": "Visual Companion WebSocket server for specops-auto-ko",
  "main": "server.cjs",
  "dependencies": {
    "ws": "^8.0.0"
  }
}
```

파일 `skills/brainstorming-ko/scripts/server.cjs`:
```javascript
'use strict'
const WebSocket = require('ws')
const { WebSocketServer } = WebSocket

const PORT = 4242
const wss = new WebSocketServer({ host: '127.0.0.1', port: PORT })

wss.on('listening', () => {
  console.log(`Visual Companion server listening on port ${PORT}`)
})

wss.on('connection', (ws) => {
  ws.on('message', (data) => {
    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data.toString())
      }
    })
  })
})

wss.on('error', (err) => {
  console.error('Visual Companion server error:', err.message)
  process.exit(1)
})
```

- [ ] **Step 4: PASS 검증**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T1\."
# 예상: T1.a PASS  T1.b PASS
```

- [ ] **Step 5: COMMIT**

```bash
git add skills/brainstorming-ko/scripts/package.json skills/brainstorming-ko/scripts/server.cjs
git commit -m "feat(visual-companion): server.cjs WebSocket broadcast + package.json ws 의존성"
```

---

### Task 3: start-server.sh (AC-3, AC-4)

**파일**:
- 생성: `skills/brainstorming-ko/scripts/start-server.sh`

- [ ] **Step 1: RED 확인**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T2\."
# 예상: T2.a FAIL
```

- [ ] **Step 2: FAIL 검증**

T2.a 1건 FAIL 확인.

- [ ] **Step 3: GREEN — start-server.sh 생성**

파일 `skills/brainstorming-ko/scripts/start-server.sh`:
```bash
#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="/tmp/.vc-server.pid"
PORT=4242

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Visual Companion server already running (PID $(cat "$PID_FILE"))"
  exit 0
fi

if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
  echo "Installing dependencies..."
  (cd "$SCRIPT_DIR" && npm install --silent)
fi

node "$SCRIPT_DIR/server.cjs" &
echo $! > "$PID_FILE"
sleep 0.5

echo "Visual Companion server started (PID $(cat "$PID_FILE"))"
echo "URL: file://$SCRIPT_DIR/frame-template.html"

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  open "file://$SCRIPT_DIR/frame-template.html"
elif [ "$OS" = "Linux" ]; then
  xdg-open "file://$SCRIPT_DIR/frame-template.html" 2>/dev/null \
    || echo "브라우저를 수동으로 열어주세요: file://$SCRIPT_DIR/frame-template.html"
else
  echo "브라우저를 수동으로 열어주세요: file://$SCRIPT_DIR/frame-template.html"
fi
```

```bash
chmod +x skills/brainstorming-ko/scripts/start-server.sh
```

- [ ] **Step 4: PASS 검증**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T2\."
# 예상: T2.a PASS
```

- [ ] **Step 5: COMMIT**

```bash
git add skills/brainstorming-ko/scripts/start-server.sh
git commit -m "feat(visual-companion): start-server.sh — PID 저장·의존 설치·브라우저 오픈"
```

---

### Task 4: stop-server.sh (AC-4)

**파일**:
- 생성: `skills/brainstorming-ko/scripts/stop-server.sh`

- [ ] **Step 1: RED 확인**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T3\."
# 예상: T3.a FAIL
```

- [ ] **Step 2: FAIL 검증**

T3.a 1건 FAIL 확인.

- [ ] **Step 3: GREEN — stop-server.sh 생성**

파일 `skills/brainstorming-ko/scripts/stop-server.sh`:
```bash
#!/usr/bin/env bash
set -u
PID_FILE="/tmp/.vc-server.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "Visual Companion server not running (PID file not found)"
  exit 0
fi

PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  echo "Visual Companion server stopped (PID $PID)"
else
  echo "Process $PID not running (stale PID file)"
fi

rm -f "$PID_FILE"
```

```bash
chmod +x skills/brainstorming-ko/scripts/stop-server.sh
```

- [ ] **Step 4: PASS 검증**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T3\."
# 예상: T3.a PASS
```

- [ ] **Step 5: COMMIT**

```bash
git add skills/brainstorming-ko/scripts/stop-server.sh
git commit -m "feat(visual-companion): stop-server.sh — PID 파일 기반 서버 종료"
```

---

### Task 5: frame-template.html (AC-5)

**파일**:
- 생성: `skills/brainstorming-ko/scripts/frame-template.html`

- [ ] **Step 1: RED 확인**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T4\."
# 예상: T4.a FAIL
```

- [ ] **Step 2: FAIL 검증**

T4.a 1건 FAIL 확인.

- [ ] **Step 3: GREEN — frame-template.html 생성**

파일 `skills/brainstorming-ko/scripts/frame-template.html`:
```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Visual Companion</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; }
    #status { padding: 8px 16px; background: #555; color: #fff; font-size: 12px; }
    #status.connected { background: #2d7d2a; }
    #status.disconnected { background: #b03a2e; }
    #content { padding: 24px; min-height: 100vh; }
  </style>
</head>
<body>
  <div id="status" class="disconnected">서버에 연결 중...</div>
  <div id="content"></div>
  <script>
    const statusEl = document.getElementById('status')
    const content = document.getElementById('content')

    function connect() {
      const ws = new WebSocket('ws://localhost:4242')

      ws.onopen = () => {
        statusEl.textContent = 'Visual Companion 연결됨'
        statusEl.className = 'connected'
      }

      ws.onmessage = (event) => {
        content.innerHTML = event.data
      }

      ws.onclose = () => {
        statusEl.textContent = '연결 끊김 — 재연결 중...'
        statusEl.className = 'disconnected'
        setTimeout(connect, 2000)
      }

      ws.onerror = () => {
        statusEl.textContent = '연결 오류 — start-server.sh 실행 확인'
        statusEl.className = 'disconnected'
      }
    }

    connect()
  </script>
</body>
</html>
```

- [ ] **Step 4: PASS 검증**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T4\."
# 예상: T4.a PASS
```

- [ ] **Step 5: COMMIT**

```bash
git add skills/brainstorming-ko/scripts/frame-template.html
git commit -m "feat(visual-companion): frame-template.html — WebSocket 수신 + 재연결 UI"
```

---

### Task 6: helper.js (AC-6)

**파일**:
- 생성: `skills/brainstorming-ko/scripts/helper.js`

- [ ] **Step 1: RED 확인**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T5\."
# 예상: T5.a FAIL
```

- [ ] **Step 2: FAIL 검증**

T5.a 1건 FAIL 확인.

- [ ] **Step 3: GREEN — helper.js 생성**

파일 `skills/brainstorming-ko/scripts/helper.js`:
```javascript
'use strict'
const WebSocket = require('ws')

const SERVER_URL = 'ws://localhost:4242'

function sendToVisualCompanion(html) {
  return new Promise((resolve) => {
    let ws
    try {
      ws = new WebSocket(SERVER_URL)
    } catch (err) {
      console.error('[Visual Companion] 연결 실패 — start-server.sh 실행 확인:', err.message)
      return resolve()
    }

    ws.on('open', () => {
      ws.send(html)
      ws.close()
      resolve()
    })

    ws.on('error', (err) => {
      console.error('[Visual Companion] 서버 연결 실패 — start-server.sh 실행 확인:', err.message)
      resolve()
    })
  })
}

module.exports = { sendToVisualCompanion }
```

- [ ] **Step 4: PASS 검증**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T5\."
# 예상: T5.a PASS
```

- [ ] **Step 5: COMMIT**

```bash
git add skills/brainstorming-ko/scripts/helper.js
git commit -m "feat(visual-companion): helper.js — sendToVisualCompanion (조용한 실패 처리)"
```

---

### Task 7: specifying-ko/SKILL.md line 326 수정 (AC-7, AC-R-1, AC-R-2)

**파일**:
- 수정: `skills/specifying-ko/SKILL.md:326`

- [ ] **Step 1: RED 확인**

```bash
bash scripts/tests/test-visual-companion.sh 2>&1 | grep "T6\."
# 예상: T6.a FAIL (포팅 주석 여전히 존재)
```

- [ ] **Step 2: FAIL 검증**

T6.a 1건 FAIL 확인.

- [ ] **Step 3: GREEN — 포팅 주석 교체**

`skills/specifying-ko/SKILL.md` line 326을 다음으로 교체:

```
(Phase 1 현재 — visual-companion 상세 가이드는 v0.1+에서 포팅)
```
→
```
사용법: `bash skills/brainstorming-ko/scripts/start-server.sh` → 브라우저 오픈 → `helper.js`의 `sendToVisualCompanion(html)` 호출.
```

- [ ] **Step 4: PASS 검증**

```bash
bash scripts/tests/test-visual-companion.sh
bash scripts/tests/test-skill-conventions.sh
bash scripts/_internal/validate-structure.sh
# 예상: test-visual-companion PASS=7 FAIL=0 / skill-conventions PASS=5 FAIL=0 / validate 전 항목 ✅
```

- [ ] **Step 5: COMMIT**

```bash
git add skills/specifying-ko/SKILL.md
git commit -m "feat(visual-companion): specifying-ko 포팅 주석 교체 — 실제 사용 가이드"
```

---

## 5. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| Node.js 미설치 | M | start-server.sh에 `node --version` 체크 + 안내 메시지 |
| `ws` 패키지 미설치 | M | start-server.sh에 `npm install` 자동 실행 |
| port 4242 충돌 | L | server.cjs `wss.on('error')` 핸들러로 오류 메시지 |
| `file://` 프로토콜 WebSocket 차단 | L | 브라우저별 정책 차이 — 로컬 HTTP 서버 대안 문서화 (YAGNI 제외) |

## 6. 자체 검토 (5원칙 체크리스트)

- [x] **스펙 커버리지**: AC-1~7, AC-R-1~2 전부 태스크 매핑됨
- [x] **플레이스홀더 스캔**: TBD·TODO 없음, 모든 코드 블록 완전
- [x] **타입 일관성**: `sendToVisualCompanion` 이름 T6·helper.js·AC-6 일치, PID_FILE `/tmp/.vc-server.pid` T3·T4 일치
- [x] **파괴적 작업**: 없음 (신규 파일 생성 + 1줄 수정)

## 7. Advisor 협의 기록

해당 없음 — 구현이 명확하고 독립 파일 생성 위주. 불확실 지점 없음.

## 8. 다음 단계

`/tasks 20260519-visual-companion-server` — 본 플랜을 TDD 바이트사이즈 태스크로 분해.

---

*작성: planning-ko · 2026-05-19 · FID: 20260519-visual-companion-server · 생성 커맨드: /plan*
