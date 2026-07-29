const express = require('express');
const router = express.Router();
const https = require('https');
const { authMiddleware } = require('../middleware/auth');
const AiConversation = require('../models/AiConversation');
const HealthData = require('../models/HealthData');
const User = require('../models/User');

// Helper: call Gemini API
async function callGemini(apiKey, model, messages) {
  const body = JSON.stringify({
    contents: messages.map((m) => ({
      role: m.role === 'ai' ? 'model' : 'user',
      parts: [{ text: m.content }],
    })),
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 1024,
    },
  });

  return new Promise((resolve, reject) => {
    const modelName = model || 'gemini-2.0-flash';
    const options = {
      hostname: 'generativelanguage.googleapis.com',
      path: `/v1beta/models/${modelName}:generateContent?key=${apiKey}`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          const text = parsed?.candidates?.[0]?.content?.parts?.[0]?.text || 'No response from AI.';
          resolve(text);
        } catch (e) {
          reject(new Error('Failed to parse Gemini response'));
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// POST /api/ai/chat — Send message & get AI response
router.post('/chat', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const { message, apiKey, model } = req.body;

    if (!message) return res.status(400).json({ success: false, message: 'Message is required' });
    if (!apiKey) return res.status(400).json({ success: false, message: 'API key is required' });

    // Get user profile for context
    const user = await User.findById(uid).select('profile settings');
    const todayStr = new Date().toISOString().split('T')[0];
    const healthDoc = await HealthData.findOne({ userId: uid, date: todayStr }).select('dailySummary');

    // Build system context
    const systemContext = `You are a personal health AI assistant for the Wrist Rx app.
User profile:
- Age: ${user?.profile?.age || 'Unknown'}
- Gender: ${user?.profile?.gender || 'Unknown'}
- Medical conditions: ${user?.profile?.conditions?.join(', ') || 'None'}
- Health goals: ${user?.profile?.goals?.join(', ') || 'Not set'}
- Activity level: ${user?.profile?.activityLevel || 'Unknown'}

Today's health data:
- Avg Heart Rate: ${healthDoc?.dailySummary?.avgHeartRate || 0} BPM
- Max Heart Rate: ${healthDoc?.dailySummary?.maxHeartRate || 0} BPM
- Total Steps: ${healthDoc?.dailySummary?.totalSteps || 0}
- Avg BP: ${healthDoc?.dailySummary?.avgSystolic || 0}/${healthDoc?.dailySummary?.avgDiastolic || 0} mmHg

Give concise, personalized health advice. Always recommend consulting a doctor for medical concerns.`;

    // Get conversation history
    let conv = await AiConversation.findOne({ userId: uid });
    if (!conv) conv = await AiConversation.create({ userId: uid, messages: [] });

    // Add system context + user message to history for API call
    const apiMessages = [
      { role: 'user', content: systemContext + '\n\nUser: ' + message },
    ];

    // Call Gemini
    const aiResponse = await callGemini(apiKey, model || user?.settings?.aiModel, apiMessages);

    // Save to conversation history
    conv.messages.push({ role: 'user', content: message });
    conv.messages.push({ role: 'ai', content: aiResponse });

    // Keep last 50 messages to avoid bloat
    if (conv.messages.length > 50) conv.messages = conv.messages.slice(-50);
    await conv.save();

    res.json({ success: true, response: aiResponse });
  } catch (error) {
    console.error('AI chat error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/ai/conversation/:uid — Get conversation history
router.get('/conversation/:uid', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) return res.status(403).json({ success: false, message: 'Forbidden' });

    const conv = await AiConversation.findOne({ userId: req.params.uid });
    res.json({ success: true, messages: conv?.messages || [], onboardingComplete: conv?.onboardingComplete || false });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/ai/onboarding/complete — Mark onboarding done
router.post('/onboarding/complete', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    await AiConversation.findOneAndUpdate(
      { userId: uid },
      { $set: { onboardingComplete: true } },
      { upsert: true, new: true }
    );
    res.json({ success: true, message: 'Onboarding marked complete' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
