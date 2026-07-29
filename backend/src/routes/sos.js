const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const SosEvent = require('../models/SosEvent');
const User = require('../models/User');

// POST /api/sos/trigger — Trigger SOS event
router.post('/trigger', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const { lat, lng, message } = req.body;

    const user = await User.findById(uid).select('settings.emergencyContacts name');

    const contacts = user?.settings?.emergencyContacts?.map((c) => c.name) || [];

    const event = await SosEvent.create({
      userId: uid,
      location: { lat: lat || null, lng: lng || null },
      contactsNotified: contacts,
      message: message || `Emergency! ${user?.name || 'Wrist Rx user'} needs help!`,
    });

    // TODO: Integrate SMS/Twilio here if needed
    // For now, just logs and returns the event

    res.status(201).json({
      success: true,
      message: 'SOS triggered',
      event,
      contactsToNotify: user?.settings?.emergencyContacts || [],
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/sos/:uid/history — Get SOS event history
router.get('/:uid/history', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) return res.status(403).json({ success: false, message: 'Forbidden' });

    const events = await SosEvent.find({ userId: req.params.uid }).sort({ createdAt: -1 }).limit(20);
    res.json({ success: true, events });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/sos/:eventId/resolve — Mark SOS as resolved
router.put('/:eventId/resolve', authMiddleware, async (req, res) => {
  try {
    const event = await SosEvent.findByIdAndUpdate(
      req.params.eventId,
      { $set: { resolved: true, resolvedAt: new Date() } },
      { new: true }
    );
    if (!event) return res.status(404).json({ success: false, message: 'Event not found' });
    res.json({ success: true, event });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
