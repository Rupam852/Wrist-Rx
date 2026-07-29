const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const HealthData = require('../models/HealthData');

// Helper: get today's date string "YYYY-MM-DD"
function todayStr() {
  return new Date().toISOString().split('T')[0];
}

// Helper: compute daily summary from readings array
function computeSummary(readings) {
  if (!readings || readings.length === 0) {
    return { avgHeartRate: 0, maxHeartRate: 0, minHeartRate: 0, totalSteps: 0, avgSystolic: 0, avgDiastolic: 0 };
  }
  const hrs = readings.map((r) => r.heartRate).filter((v) => v > 0);
  const totalSteps = Math.max(...readings.map((r) => r.steps)); // cumulative steps
  const systolics = readings.map((r) => r.systolic).filter((v) => v > 0);
  const diastolics = readings.map((r) => r.diastolic).filter((v) => v > 0);

  const avg = (arr) => (arr.length ? Math.round(arr.reduce((a, b) => a + b, 0) / arr.length) : 0);

  return {
    avgHeartRate: avg(hrs),
    maxHeartRate: hrs.length ? Math.max(...hrs) : 0,
    minHeartRate: hrs.length ? Math.min(...hrs) : 0,
    totalSteps: isFinite(totalSteps) ? totalSteps : 0,
    avgSystolic: avg(systolics),
    avgDiastolic: avg(diastolics),
  };
}

// POST /api/health/reading — Save a single health reading
router.post('/reading', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const date = todayStr();
    const { heartRate = 0, systolic = 0, diastolic = 0, steps = 0, coordinates = {} } = req.body;

    const reading = { heartRate, systolic, diastolic, steps, coordinates, timestamp: new Date() };

    let doc = await HealthData.findOne({ userId: uid, date });

    if (!doc) {
      doc = await HealthData.create({ userId: uid, date, readings: [reading] });
    } else {
      doc.readings.push(reading);
    }

    doc.dailySummary = computeSummary(doc.readings);
    await doc.save();

    res.json({ success: true, data: doc });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/health/:uid/today — Get today's health data
router.get('/:uid/today', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) return res.status(403).json({ success: false, message: 'Forbidden' });

    const date = todayStr();
    const doc = await HealthData.findOne({ userId: req.params.uid, date });

    if (!doc) {
      return res.json({
        success: true,
        data: null,
        message: 'No data for today yet',
        defaults: { heartRate: 0, systolic: 0, diastolic: 0, steps: 0, coordinates: null },
      });
    }

    // Return latest reading + summary
    const latest = doc.readings[doc.readings.length - 1] || null;
    res.json({ success: true, data: { latest, summary: doc.dailySummary, date } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/health/:uid/history?days=7 — Get historical data
router.get('/:uid/history', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) return res.status(403).json({ success: false, message: 'Forbidden' });

    const days = Math.min(parseInt(req.query.days) || 7, 30);
    const fromDate = new Date();
    fromDate.setDate(fromDate.getDate() - days);
    const fromDateStr = fromDate.toISOString().split('T')[0];

    const docs = await HealthData.find({
      userId: req.params.uid,
      date: { $gte: fromDateStr },
    })
      .select('date dailySummary -_id')
      .sort({ date: -1 });

    res.json({ success: true, data: docs });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/health/:uid/cache — Clear user's local cache (admin use)
router.delete('/:uid/cache', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) return res.status(403).json({ success: false, message: 'Forbidden' });
    // Only delete readings older than 30 days
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);
    const cutoffStr = cutoff.toISOString().split('T')[0];
    await HealthData.deleteMany({ userId: req.params.uid, date: { $lt: cutoffStr } });
    res.json({ success: true, message: 'Old cache cleared' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
