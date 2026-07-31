const express = require('express');
const router = express.Router();
const https = require('https');
const { authMiddleware } = require('../middleware/auth');
const AiConversation = require('../models/AiConversation');
const HealthData = require('../models/HealthData');
const User = require('../models/User');

// Helper: call single Gemini API model
async function callGeminiSingle(apiKey, model, messages) {
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

  return new Promise((resolve) => {
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
          if (parsed.error) {
            const code = parsed.error.code || res.statusCode;
            const msg = parsed.error.message || 'Unknown API Error';
            if (code === 400 || msg.toLowerCase().includes('api key')) {
              return resolve(`⚠️ API Key Error (${code}): Invalid API key. Please generate a valid key at aistudio.google.com and save it in Settings.`);
            }
            if (code === 404 || msg.toLowerCase().includes('not found')) {
              return resolve(`⚠️ Model Error (${code}): Model '${modelName}' not found.`);
            }
            if (code === 429 || msg.toLowerCase().includes('quota')) {
              return resolve(`⚠️ Quota Limit (${code}): Free Gemini API rate limit reached.`);
            }
            return resolve(`⚠️ Gemini API Error (${code}): ${msg}`);
          }
          const text = parsed?.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text) {
            resolve(text);
          } else {
            resolve('⚠️ No response generated. Please check your Gemini API key and prompt.');
          }
        } catch (e) {
          resolve(`⚠️ Response Error: Failed to parse Gemini response (${e.message})`);
        }
      });
    });

    req.on('error', (err) => {
      resolve(`⚠️ Network Error: Unable to reach Gemini server (${err.message})`);
    });
    req.write(body);
    req.end();
  });
}

// AUTO_MODEL_CHAIN — tested & confirmed with real API key (2026-07-30)
// ✅ gemini-flash-latest    => OK (always points to latest flash)
// ✅ gemini-3.1-flash-lite  => OK (confirmed working)
// ⚠️ gemini-3.5-flash       => 503 temp (try as fallback)
// ⚠️ gemini-2.0-flash       => 429 quota (fallback when quota resets)
// ⚠️ gemini-2.0-flash-lite  => 429 quota (last resort)
const AUTO_MODEL_CHAIN = [
  'gemini-flash-latest',    // ✅ PRIMARY — always latest, confirmed working
  'gemini-3.1-flash-lite',  // ✅ FALLBACK 1 — confirmed working
  'gemini-3.5-flash',       // ⚠️ FALLBACK 2 — sometimes available
  'gemini-2.0-flash',       // ⚠️ FALLBACK 3 — exists, may hit quota
  'gemini-2.0-flash-lite',  // ⚠️ FALLBACK 4 — exists, lighter model
];

// Check if a response is an error (not a real AI response)
function isErrorResponse(resp) {
  return resp.startsWith('⚠️');
}

// Helper: call Gemini API with smart auto-fallback
async function callGemini(apiKey, model, messages) {
  // AUTO MODE: try the latest models in priority order
  if (!model || model === 'auto') {
    let lastError = '';
    for (const autoModel of AUTO_MODEL_CHAIN) {
      const resp = await callGeminiSingle(apiKey, autoModel, messages);
      if (!isErrorResponse(resp)) {
        return resp; // ✅ Success — return first working model's response
      }
      // Stop on API key errors (no point trying other models)
      if (resp.includes('API Key Error') || resp.includes('Invalid API key')) {
        return resp;
      }
      lastError = resp;
      // Continue to next model on quota/not-found errors
    }
    // All models failed
    return `⚠️ All Gemini models failed. Last error: ${lastError}\n\nPlease check your API key at aistudio.google.com`;
  }

  // CUSTOM / SPECIFIC MODEL MODE: try given model, fallback on quota
  const resp = await callGeminiSingle(apiKey, model, messages);
  if (isErrorResponse(resp) && (resp.includes('Quota Limit') || resp.includes('429'))) {
    // Fallback chain for quota errors on specific models
    const fallbacks = AUTO_MODEL_CHAIN.filter(m => m !== model);
    for (const fbModel of fallbacks) {
      const fbResp = await callGeminiSingle(apiKey, fbModel, messages);
      if (!isErrorResponse(fbResp)) return fbResp;
    }
    return '⚠️ Quota Limit (429): Rate limit reached across all models. Please wait 1 minute or get a new free key at aistudio.google.com.';
  }
  return resp;
}

// POST /api/ai/chat — Send message & get AI response
router.post('/chat', authMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid;
    const { message, apiKey, model, healthData } = req.body;

    if (!message) return res.status(400).json({ success: false, message: 'Message is required' });
    if (!apiKey) return res.status(400).json({ success: false, message: 'API key is required' });

    // Get user profile for context
    const user = await User.findById(uid).select('profile settings');
    const todayStr = new Date().toISOString().split('T')[0];
    const healthDoc = await HealthData.findOne({ userId: uid, date: todayStr }).select('dailySummary');

    // Prefer local healthData payload sent directly from app
    const hr = healthData?.heartRate ?? healthDoc?.dailySummary?.avgHeartRate ?? 0;
    const sys = healthData?.systolic ?? healthDoc?.dailySummary?.avgSystolic ?? 0;
    const dia = healthData?.diastolic ?? healthDoc?.dailySummary?.avgDiastolic ?? 0;
    const steps = healthData?.steps ?? healthDoc?.dailySummary?.totalSteps ?? 0;

    // Build system context
    const systemContext = `You are a personal health AI assistant for the Wrist Rx app.
User profile:
- Age: ${user?.profile?.age || 'Unknown'}
- Gender: ${user?.profile?.gender || 'Unknown'}
- Medical conditions: ${user?.profile?.conditions?.join(', ') || 'None'}
- Health goals: ${user?.profile?.goals?.join(', ') || 'Not set'}
- Activity level: ${user?.profile?.activityLevel || 'Unknown'}

Today's current health data:
- Heart Rate: ${hr > 0 ? hr + ' BPM' : 'Not recorded'}
- Blood Pressure: ${sys > 0 && dia > 0 ? `${sys}/${dia} mmHg` : 'Not recorded'}
- Steps Count: ${steps > 0 ? steps : '0'}

Give concise, personalized health advice based on the user's data. Always recommend consulting a doctor for medical concerns.`;


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
