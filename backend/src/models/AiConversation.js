const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  role: { type: String, enum: ['user', 'ai'], required: true },
  content: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
});

const aiConversationSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true, index: true },
    messages: [messageSchema],
    onboardingComplete: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model('AiConversation', aiConversationSchema);
