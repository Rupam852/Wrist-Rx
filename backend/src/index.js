require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const http = require('http');
const { connectDB } = require('./config/database');
const { initFirebase } = require('./config/firebase');
const { initWebSocket } = require('./config/websocket');

// Route imports
const authRoutes = require('./routes/auth');
const healthRoutes = require('./routes/health');
const watchRoutes = require('./routes/watch');
const aiRoutes = require('./routes/ai');
const sosRoutes = require('./routes/sos');
const { startMidnightReset } = require('./jobs/midnightReset');

const app = express();
const server = http.createServer(app);

// ─── Middleware ───────────────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: process.env.FRONTEND_URL || '*' }));
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined'));

// ─── Health check (Render needs this) ─────────────────────────
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    app: 'Wrist Rx Backend',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', uptime: process.uptime() });
});

// ─── API Routes ───────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/health', healthRoutes);
app.use('/api/watch', watchRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/sos', sosRoutes);

// ─── 404 Handler ──────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// ─── Global Error Handler ─────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('❌ Error:', err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

// ─── Start Server ─────────────────────────────────────────────
const PORT = process.env.PORT || 3000;

async function startServer() {
  try {
    await connectDB();
    initFirebase();
    initWebSocket(server);

    server.listen(PORT, () => {
      console.log(`\n🚀 Wrist Rx Backend running on port ${PORT}`);
      console.log(`📡 WebSocket server ready`);
      console.log(`🌿 Environment: ${process.env.NODE_ENV || 'development'}\n`);
      startMidnightReset();
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

module.exports = { app, server };
