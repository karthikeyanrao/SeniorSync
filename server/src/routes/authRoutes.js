const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Medication = require('../models/Medication');
const Routine = require('../models/Routine');
const Vitals = require('../models/Vitals');
const SOS = require('../models/SOS');
const jwt = require('jsonwebtoken');

// Register or Sync User
router.post('/sync', async (req, res) => {
  const { firebaseUid, name, email, fcmToken, timezoneOffsetMinutes } = req.body;
  const safeName = (name && name.trim()) ? name.trim() : (email ? email.split('@')[0] : 'User');

  try {
    // 1. Load raw data (lean) to check for basic structure/corruption
    let userRecord = await User.findOne({ firebaseUid }).lean();

    // 2. RAW FIX: If we see the 'caregivers' string corruption, fix it BEFORE loading the document
    if (userRecord && (typeof userRecord.caregivers === 'string' || !Array.isArray(userRecord.caregivers))) {
      console.warn(`[RAW-REPAIR] Sanitizing caregivers field for: ${firebaseUid}`);
      await User.updateOne({ firebaseUid }, { $set: { caregivers: [] } });
    }

    // 3. Now it is safe to load as a formal Mongoose Document
    let user = await User.findOne({ firebaseUid });

    if (user) {
      // Update existing user
      user.name = (user.name && user.name.trim() && user.name !== 'User') ? user.name : safeName;
      if (fcmToken) user.fcmToken = fcmToken;
      if (timezoneOffsetMinutes !== undefined && timezoneOffsetMinutes !== null && Number.isFinite(Number(timezoneOffsetMinutes))) {
        user.timezoneOffsetMinutes = Number(timezoneOffsetMinutes);
      }
    } else {
      // Create new user
      user = new User({
        firebaseUid,
        name: safeName,
        email,
        fcmToken: fcmToken || null,
        timezoneOffsetMinutes: Number.isFinite(Number(timezoneOffsetMinutes)) ? Number(timezoneOffsetMinutes) : 0,
      });
    }

    // Generate Tokens
    const accessToken = jwt.sign(
      { uid: user.firebaseUid, email: user.email },
      process.env.JWT_SECRET || 'seniorsync_emergency_key_2024',
      { expiresIn: '7d' } // Increased to 7d to prevent 401s after 1 hour session
    );

    const refreshToken = jwt.sign(
      { uid: user.firebaseUid },
      process.env.JWT_REFRESH_SECRET || 'seniorsync_refresh_emergency_key_2024',
      { expiresIn: '30d' }
    );

    // Store refresh token in user document
    user.refreshToken = refreshToken;

    // Aggressive SELF-REPAIR: If 'caregivers' is not a valid list, force-reset it.
    // This fixes the 'Tried to set nested object field to primitive' error.
    if (!Array.isArray(user.caregivers) || (user.caregivers.length > 0 && typeof user.caregivers[0] !== 'object')) {
      console.warn(`[REPAIR] Fixing corrupted caregivers field for: ${user.firebaseUid} (Found: ${typeof user.caregivers})`);
      user.caregivers = [];
    }

    try {
      await user.save();
    } catch (saveErr) {
      console.warn(`[REPAIR] Save failed for ${user.firebaseUid}, force-wiping and retrying...`);
      // Use raw update if save fails to bypass Mongoose validation lock
      await User.updateOne({ firebaseUid: user.firebaseUid }, { $set: { caregivers: [] } });
      await user.save();
    }

    res.status(user.isNew ? 201 : 200).json({
      message: user.isNew ? 'User created' : 'User updated',
      user,
      accessToken,
      refreshToken
    });
  } catch (error) {
    console.error('Error syncing user:', error);
    res.status(500).json({ error: error.message, stack: error.stack });
  }
});

// Get User Profile
router.get('/profile/:uid', async (req, res) => {
  try {
    const user = await User.findOne({ firebaseUid: req.params.uid });
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Update User Profile
router.patch('/profile/:uid', async (req, res) => {
  try {
    const { name, age, conditions, allergies, foodTimes, onboarded, role, timezoneOffsetMinutes } = req.body;
    // Never $set undefined — MongoDB driver / Mongoose can reject or behave oddly
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (age !== undefined) updateData.age = age;
    if (conditions !== undefined) updateData.conditions = conditions;
    if (allergies !== undefined) updateData.allergies = allergies;
    if (foodTimes !== undefined) updateData.foodTimes = foodTimes;
    if (onboarded !== undefined) updateData.onboarded = onboarded;
    if (role !== undefined) updateData.role = role;
    if (timezoneOffsetMinutes !== undefined && timezoneOffsetMinutes !== null && Number.isFinite(Number(timezoneOffsetMinutes))) {
      updateData.timezoneOffsetMinutes = Number(timezoneOffsetMinutes);
    }

    if (Object.keys(updateData).length === 0) {
      const user = await User.findOne({ firebaseUid: req.params.uid });
      if (!user) return res.status(404).json({ error: 'User not found' });
      return res.json(user);
    }

    const user = await User.findOneAndUpdate(
      { firebaseUid: req.params.uid },
      { $set: updateData },
      { returnDocument: 'after' }
    );
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    console.error('PATCH /auth/profile error:', error);
    res.status(500).json({ error: error.message || 'Internal Server Error' });
  }
});

// Pair Caregiver by Email
router.post('/pair/caregiver', async (req, res) => {
  const { seniorUid, caregiverEmail } = req.body;

  try {
    const caregiver = await User.findOne({ email: caregiverEmail });
    if (!caregiver) return res.status(404).json({ error: 'Caregiver not found with this email' });

    // Add caregiver to senior
    const senior = await User.findOneAndUpdate(
      { firebaseUid: seniorUid },
      { $addToSet: { caregivers: { uid: caregiver.firebaseUid, permissionLevel: 'admin' } } },
      { returnDocument: 'after' }
    );

    // Add senior to caregiver
    await User.findOneAndUpdate(
      { firebaseUid: caregiver.firebaseUid },
      { $addToSet: { linkedSeniors: seniorUid } }
    );

    res.json({ message: 'Caregiver linked successfully', senior });
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Pair Senior by UID (QR Code Scan)
router.post('/pair/senior', async (req, res) => {
  const { caregiverUid, seniorUid } = req.body;

  try {
    const senior = await User.findOne({ firebaseUid: seniorUid });
    if (!senior) return res.status(404).json({ error: 'Senior not found from this QR code' });

    // Add caregiver to senior
    await User.findOneAndUpdate(
      { firebaseUid: seniorUid },
      { $addToSet: { caregivers: { uid: caregiverUid, permissionLevel: 'admin' } } }
    );

    // Add senior to caregiver
    await User.findOneAndUpdate(
      { firebaseUid: caregiverUid },
      { $addToSet: { linkedSeniors: seniorUid } },
      { returnDocument: 'after' }
    );

    res.json({ message: 'Senior linked successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Unlink Caregiver (SEC-04)
router.post('/unlink', async (req, res) => {
  const { seniorUid, caregiverUid } = req.body;
  try {
    // Remove caregiver from senior
    await User.findOneAndUpdate(
      { firebaseUid: seniorUid },
      { $pull: { caregivers: { uid: caregiverUid } } }
    );
    // Remove senior from caregiver
    await User.findOneAndUpdate(
      { firebaseUid: caregiverUid },
      { $pull: { linkedSeniors: seniorUid } }
    );
    res.json({ message: 'Caregiver unlinked successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Data Archive / Cleanup (BR-05)
router.delete('/profile/:uid', async (req, res) => {
  try {
    const { uid } = req.params;

    // Delete all user related data across modules to cleanly archive/wipe account
    await Promise.all([
      User.findOneAndDelete({ firebaseUid: uid }),
      Medication.deleteMany({ userId: uid }),
      Routine.deleteMany({ userId: uid }),
      Vitals.deleteMany({ userId: uid }),
      SOS.deleteMany({ userId: uid }),
    ]);

    res.json({ success: true, message: 'Account and all related user data completely erased.' });
  } catch (err) {
    res.status(500).json({ error: 'Server error wiping account data' });
  }
});

// Generate Pairing Code (DASH-03)
router.post('/pair/generate', async (req, res) => {
  const { seniorUid } = req.body;
  try {
    const code = Math.random().toString(36).substring(2, 8).toUpperCase();
    const expires = new Date();
    expires.setHours(expires.getHours() + 24);

    await User.findOneAndUpdate(
      { firebaseUid: seniorUid },
      { $set: { pairingCode: code, pairingCodeExpires: expires } }
    );
    res.json({ code, expires });
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Pair by Code (DASH-03)
router.post('/pair/code', async (req, res) => {
  const { caregiverUid, code } = req.body;
  try {
    const senior = await User.findOne({ pairingCode: code });
    if (!senior) return res.status(404).json({ error: 'Invalid pairing code' });

    if (senior.pairingCodeExpires && senior.pairingCodeExpires < new Date()) {
      return res.status(400).json({ error: 'Pairing code has expired' });
    }

    // Link them
    await User.findOneAndUpdate(
      { firebaseUid: senior.firebaseUid },
      { $addToSet: { caregivers: { uid: caregiverUid, permissionLevel: 'admin' } } }
    );
    await User.findOneAndUpdate(
      { firebaseUid: caregiverUid },
      { $addToSet: { linkedSeniors: senior.firebaseUid } }
    );

    // Clear code after use (no pre-save hook — keep caregivers valid for save)
    if (!Array.isArray(senior.caregivers)) senior.caregivers = [];
    senior.pairingCode = null;
    senior.pairingCodeExpires = null;
    await senior.save();

    res.json({ message: 'Linked successfully via code', seniorUid: senior.firebaseUid });
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

module.exports = router;
