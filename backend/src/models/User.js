const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    _id: { type: String }, // Firebase UID
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, lowercase: true },
    photoUrl: { type: String, default: '' },
    provider: { type: String, enum: ['google'], default: 'google' },
    isFirstLogin: { type: Boolean, default: true },

    profile: {
      age: { type: Number, default: null },
      gender: { type: String, enum: ['male', 'female', 'other', null], default: null },
      conditions: { type: [String], default: [] },
      goals: { type: [String], default: [] },
      activityLevel: {
        type: String,
        enum: ['sedentary', 'lightly_active', 'moderately_active', 'very_active', null],
        default: null,
      },
    },

    settings: {
      notifications: { type: Boolean, default: true },
      watchStepNotification: { type: Boolean, default: true },
      watchHrAlert: { type: Boolean, default: true },
      watchBpAlert: { type: Boolean, default: true },
      dailySummary: { type: Boolean, default: false },
      sound: { type: Boolean, default: false },
      haptic: { type: Boolean, default: false },
      aiProvider: { type: String, default: 'gemini' },
      aiModel: { type: String, default: 'gemini-2.0-flash' },
      emergencyContacts: [
        {
          name: { type: String },
          phone: { type: String },
        },
      ],
    },

    watchInfo: {
      connectionType: { type: String, enum: ['bluetooth', 'wifi_token', null], default: null },
      macAddress: { type: String, default: null },
      token: { type: String, default: null },
      lastConnected: { type: Date, default: null },
      isConnected: { type: Boolean, default: false },
    },
  },
  {
    _id: false, // We use Firebase UID as _id
    timestamps: true,
  }
);

module.exports = mongoose.model('User', userSchema);
