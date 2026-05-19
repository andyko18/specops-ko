'use strict'

const WebSocket = require('ws')
const { WebSocketServer } = WebSocket

const PORT = 4242
const wss = new WebSocketServer({ host: '127.0.0.1', port: PORT })

wss.on('listening', () => {
  console.log(`Visual Companion server listening on port ${PORT}`)
})

wss.on('connection', (ws) => {
  ws.on('error', () => {})
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
