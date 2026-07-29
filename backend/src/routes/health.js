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
    return { avgHeartRate: 0, maxHeartRate: 0, minHeartRate: 0, totalSteps: 0, avgSystolic: 0, avgDiastolic: 0, avgSpo2: 0 };
  }
  const hrs = readings.map((r) => r.heartRate).filter((v) => v > 0);
  const totalSteps = Math.max(...readings.map((r) => r.steps)); // cumulative steps
  const systolics = readings.map((r) => r.systolic).filter((v) => v > 0);
  const diastolics = readings.map((r) => r.diastolic).filter((v) => v > 0);
  const spo2s = readings.map((r) => r.spo2).filter((v) => v > 0);

  const avg = (arr) => (arr.length ? Math.round(arr.reduce((a, b) => a + b, 0) / arr.length) : 0);

  return {
    avgHeartRate: avg(hrs),
    maxHeartRate: hrs.length ? Math.max(...hrs) : 0,
    minHeartRate: hrs.length ? Math.min(...hrs) : 0,
    totalSteps: isFinite(totalSteps) ? totalSteps : 0,
    avgSystolic: avg(systolics),
    avgDiastolic: avg(diastolics),
    avgSpo2: avg(spo2s),
  };
}

// POST /api/health/reading — Save a single health reading
router.post('/reading', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const date = todayStr();
    const { heartRate = 0, systolic = 0, diastolic = 0, spo2 = 0, steps = 0, coordinates = {} } = req.body;

    const reading = { heartRate, systolic, diastolic, spo2, steps, coordinates, timestamp: new Date() };

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
    const date = todayStr();
    const doc = await HealthData.findOne({ userId: req.params.uid, date });

    if (!doc || doc.readings.length === 0) {
      return res.json({
        success: true,
        data: { heartRate: 0, systolic: 0, diastolic: 0, spo2: 0, steps: 0, coordinates: { lat: null, lng: null }, dailySummary: {} },
      });
    }

    const latest = doc.readings[doc.readings.length - 1];
    res.json({
      success: true,
      data: {
        heartRate: latest.heartRate,
        systolic: latest.systolic,
        diastolic: latest.diastolic,
        spo2: latest.spo2,
        steps: latest.steps,
        coordinates: latest.coordinates,
        dailySummary: doc.dailySummary,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/health/:uid/history — Get historical health data for charts
router.get('/:uid/history', authMiddleware, async (req, res) => {
  try {
    const docs = await HealthData.find({ userId: req.params.uid }).sort({ date: -1 }).limit(30);
    res.json({ success: true, data: docs });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/health/:uid/clean — Clean all user health data & AI chat history from database
router.delete('/:uid/clean', authMiddleware, async (req, res) => {
  try {
    const AiConversation = require('../models/AiConversation');
    await HealthData.deleteMany({ userId: req.params.uid });
    await AiConversation.deleteMany({ userId: req.params.uid });
    res.json({ success: true, message: 'All user health data and AI chat history wiped successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
