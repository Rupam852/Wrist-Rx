const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');

// POST /api/auth/register
// Called after Google Sign-In to create user in MongoDB if not exists
router.post('/register', authMiddleware, async (req, res) => {
  try {
    const { uid, email, name, picture } = req.user;

    let user = await User.findById(uid);

    if (!user) {
      // First time user — create record
      user = await User.create({
        _id: uid,
        name: name || 'Wrist Rx User',
        email: email || '',
        photoUrl: picture || '',
        provider: 'google',
        isFirstLogin: true,
      });
      return res.status(201).json({ success: true, isNewUser: true, user });
    }

    // Returning user
    return res.json({ success: true, isNewUser: false, user });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/auth/user/:uid
router.get('/user/:uid', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    const user = await User.findById(req.params.uid);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/auth/user/:uid  — Update profile
router.put('/user/:uid', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    const allowedUpdates = ['name', 'photoUrl', 'profile', 'settings'];
    const updates = {};
    allowedUpdates.forEach((key) => {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    });

    const user = await User.findByIdAndUpdate(
      req.params.uid,
      { $set: updates },
      { new: true, runValidators: true }
    );

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/auth/user/:uid/onboarding — Save AI onboarding answers
router.put('/user/:uid/onboarding', authMiddleware, async (req, res) => {
  try {
    if (req.params.uid !== req.user.uid) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    const { age, gender, conditions, goals, activityLevel } = req.body;
    const user = await User.findByIdAndUpdate(
      req.params.uid,
      {
        $set: {
          'profile.age': age,
          'profile.gender': gender,
          'profile.conditions': conditions,
          'profile.goals': goals,
          'profile.activityLevel': activityLevel,
          isFirstLogin: false,
        },
      },
      { new: true }
    );
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
