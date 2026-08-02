const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const Reminder = require('../models/Reminder');

// GET /api/reminders — Fetch user's reminders + toggle state
router.get('/', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const doc = await Reminder.findOne({ userId: uid });
    if (!doc) {
      return res.json({ success: true, watchAlertEnabled: false, reminders: [] });
    }
    res.json({ success: true, watchAlertEnabled: doc.watchAlertEnabled, reminders: doc.reminders });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/reminders — Save all reminders + toggle (upsert)
router.post('/', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const { watchAlertEnabled, reminders } = req.body;

    const doc = await Reminder.findOneAndUpdate(
      { userId: uid },
      { $set: { watchAlertEnabled: !!watchAlertEnabled, reminders: reminders || [] } },
      { upsert: true, new: true }
    );

    res.json({ success: true, watchAlertEnabled: doc.watchAlertEnabled, reminders: doc.reminders });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/reminders/:reminderId — Remove single reminder
router.delete('/:reminderId', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const { reminderId } = req.params;

    await Reminder.findOneAndUpdate(
      { userId: uid },
      { $pull: { reminders: { reminderId } } }
    );

    res.json({ success: true, message: 'Reminder removed' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
