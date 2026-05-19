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
