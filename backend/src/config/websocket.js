const { WebSocketServer } = require('ws');

const watchClients = new Map(); // userId -> ws

function initWebSocket(server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const userId = url.searchParams.get('userId');

    if (!userId) {
      ws.close(1008, 'Missing userId');
      return;
    }

    watchClients.set(userId, ws);
    console.log(`📡 WebSocket connected: userId=${userId}`);

    ws.on('message', (message) => {
      try {
        const data = JSON.parse(message.toString());
        console.log(`📥 WS message from ${userId}:`, data.type);
        // Watch data arrives here from watch device
        if (data.type === 'HEALTH_DATA') {
          broadcastToUser(userId, { type: 'HEALTH_UPDATE', payload: data.payload });
        }
      } catch (e) {
        console.error('WS message parse error:', e);
      }
    });

    ws.on('close', () => {
      watchClients.delete(userId);
      console.log(`📡 WebSocket disconnected: userId=${userId}`);
    });

    ws.on('error', (err) => {
      console.error(`WS error for ${userId}:`, err.message);
    });

    // Send acknowledgment
    ws.send(JSON.stringify({ type: 'CONNECTED', userId }));
  });

  console.log('✅ WebSocket server initialized on /ws');
}

function broadcastToUser(userId, data) {
  const ws = watchClients.get(userId);
  if (ws && ws.readyState === 1) {
    ws.send(JSON.stringify(data));
  }
}

function sendToUser(userId, data) {
  broadcastToUser(userId, data);
}

module.exports = { initWebSocket, sendToUser, watchClients };
