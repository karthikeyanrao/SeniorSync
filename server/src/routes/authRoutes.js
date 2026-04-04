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
  const { firebaseUid, name, email, fcmToken } = req.body;
  const safeName = (name && name.trim()) ? name.trim() : (email ? email.split('@')[0] : 'User');
  
  try {
    let user = await User.findOne({ firebaseUid });
    
    if (user) {
      // Update existing user
      user.name = safeName || user.name;
      if (fcmToken) user.fcmToken = fcmToken;
    } else {
      // Create new user
      user = new User({
        firebaseUid,
        name: safeName,
        email,
        fcmToken: fcmToken || null
      });
    }

    // Generate Tokens
    const accessToken = jwt.sign(
      { uid: user.firebaseUid, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
    
    const refreshToken = jwt.sign(
      { uid: user.firebaseUid },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: '7d' }
    );

    // Store refresh token in user document
    user.refreshToken = refreshToken;
    await user.save();
    
    res.status(user.isNew ? 201 : 200).json({ 
      message: user.isNew ? 'User created' : 'User updated', 
      user,
      accessToken,
      refreshToken
    });
  } catch (error) {
    console.error('Error syncing user:', error);
    res.status(500).json({ error: 'Internal Server Error' });
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
    const { name, age, conditions, allergies, foodTimes, onboarded, role } = req.body;
    const updateData = { name, age, conditions, allergies, foodTimes, role };
    if (onboarded !== undefined) updateData.onboarded = onboarded;

    const user = await User.findOneAndUpdate(
      { firebaseUid: req.params.uid },
      { $set: updateData },
      { new: true }
    );
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
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
      { new: true }
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
      { new: true }
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

    // Clear code after use
    senior.pairingCode = null;
    senior.pairingCodeExpires = null;
    await senior.save();

    res.json({ message: 'Linked successfully via code', seniorUid: senior.firebaseUid });
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

module.exports = router;
