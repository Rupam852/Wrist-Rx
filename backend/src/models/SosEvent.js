const mongoose = require('mongoose');

const sosSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    location: {
      lat: { type: Number, default: null },
      lng: { type: Number, default: null },
    },
    contactsNotified: [{ type: String }],
    message: { type: String, default: 'Emergency! I need help.' },
    resolved: { type: Boolean, default: false },
    resolvedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('SosEvent', sosSchema);
