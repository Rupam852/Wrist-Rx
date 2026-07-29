const mongoose = require('mongoose');

const readingSchema = new mongoose.Schema({
  timestamp: { type: Date, default: Date.now },
  heartRate: { type: Number, default: 0 },      // BPM
  systolic: { type: Number, default: 0 },        // mmHg
  diastolic: { type: Number, default: 0 },       // mmHg
  spo2: { type: Number, default: 0 },            // Blood Oxygen %
  steps: { type: Number, default: 0 },
  coordinates: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
  },
});

const healthDataSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    date: { type: String, required: true }, // "YYYY-MM-DD"
    readings: [readingSchema],
    dailySummary: {
      avgHeartRate: { type: Number, default: 0 },
      maxHeartRate: { type: Number, default: 0 },
      minHeartRate: { type: Number, default: 0 },
      totalSteps: { type: Number, default: 0 },
      avgSystolic: { type: Number, default: 0 },
      avgDiastolic: { type: Number, default: 0 },
      avgSpo2: { type: Number, default: 0 },
    },
    resetAt: { type: Date, default: null },
  },
  { timestamps: true }
);

// Compound index for fast user+date lookups
healthDataSchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('HealthData', healthDataSchema);
