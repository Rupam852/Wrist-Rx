const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');
const { watchClients } = require('../config/websocket');

// POST /api/watch/connect-token — Connect watch via unique token
router.post('/connect-token', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const { token } = req.body;

    if (!token) return res.status(400).json({ success: false, message: 'Watch token is required' });

    // Save watch token to user record
    const user = await User.findByIdAndUpdate(
      uid,
      {
        $set: {
          'watchInfo.token': token,
          'watchInfo.connectionType': 'wifi_token',
          'watchInfo.lastConnected': new Date(),
          'watchInfo.isConnected': true,
        },
      },
      { new: true }
    );

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    res.json({ success: true, message: 'Watch connected via token', watchInfo: user.watchInfo });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/watch/connect-bluetooth — Register Bluetooth MAC address
router.post('/connect-bluetooth', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const { macAddress } = req.body;

    if (!macAddress) return res.status(400).json({ success: false, message: 'MAC address is required' });

    const user = await User.findByIdAndUpdate(
      uid,
      {
        $set: {
          'watchInfo.macAddress': macAddress,
          'watchInfo.connectionType': 'bluetooth',
          'watchInfo.lastConnected': new Date(),
          'watchInfo.isConnected': true,
        },
      },
      { new: true }
    );

    res.json({ success: true, message: 'Watch connected via Bluetooth', watchInfo: user.watchInfo });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/watch/:uid/status — Get watch connection status
router.get('/:uid/status', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) return res.status(403).json({ success: false, message: 'Forbidden' });

    const user = await User.findById(req.params.uid).select('watchInfo');
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    // Check if WebSocket is live
    const wsConnected = watchClients.has(req.params.uid);

    res.json({
      success: true,
      watchInfo: user.watchInfo,
      wsConnected,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/watch/:uid/disconnect
router.post('/:uid/disconnect', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) return res.status(403).json({ success: false, message: 'Forbidden' });

    await User.findByIdAndUpdate(req.params.uid, {
      $set: { 'watchInfo.isConnected': false },
    });

    res.json({ success: true, message: 'Watch disconnected' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/watch/data — Watch device pushes health data (token auth)
router.post('/data', async (req, res) => {
  try {
    const { token, heartRate, systolic, diastolic, steps, lat, lng } = req.body;

    if (!token) return res.status(400).json({ success: false, message: 'Token required' });

    // Find user by watch token
    const user = await User.findOne({ 'watchInfo.token': token });
    if (!user) return res.status(404).json({ success: false, message: 'Unknown watch token' });

    // Send data to user via WebSocket if connected
    const { sendToUser } = require('../config/websocket');
    sendToUser(user._id.toString(), {
      type: 'HEALTH_UPDATE',
      payload: { heartRate, systolic, diastolic, steps, coordinates: { lat, lng }, timestamp: new Date() },
    });

    res.json({ success: true, message: 'Data received and forwarded' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
