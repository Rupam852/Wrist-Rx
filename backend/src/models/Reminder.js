const mongoose = require('mongoose');

const reminderItemSchema = new mongoose.Schema({
  reminderId: { type: String, required: true }, // UUID from client
  name:        { type: String, required: true, trim: true },
  description: { type: String, default: '', trim: true },
  timeHour:    { type: Number, required: true, min: 0, max: 23 },
  timeMinute:  { type: Number, required: true, min: 0, max: 59 },
}, { _id: false });

const reminderSchema = new mongoose.Schema(
  {
    userId:            { type: String, required: true, unique: true, index: true },
    watchAlertEnabled: { type: Boolean, default: false }, // global toggle
    reminders:         { type: [reminderItemSchema], default: [] },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Reminder', reminderSchema);
