
const express = require('express');
const router = express.Router();
const SOS = require('../models/SOS');
const User = require('../models/User');
const admin = require('firebase-admin');

// Trigger SOS
router.post('/trigger', async (req, res) => {
  try {
    const { userId, location } = req.body;
    const newSOS = new SOS({
      userId,
      location,
      status: 'active',
      timestamp: new Date(),
    });
    await newSOS.save();
    
    // Trigger push notifications to caregivers
    try {
      const senior = await User.findOne({ firebaseUid: userId });
      if (senior && senior.caregivers && senior.caregivers.length > 0) {
        const caregivers = await User.find({ firebaseUid: { $in: senior.caregivers }, fcmToken: { $exists: true, $ne: null } });
        
        for (const caregiver of caregivers) {
          await admin.messaging().send({
            notification: { 
              title: 'EMERGENCY SOS Triggered! 🚨', 
              body: `${senior.name} has just triggered an SOS alert from their device!` 
            },
            data: { 
              type: 'SOS_ALERT', 
              seniorUid: userId 
            },
            token: caregiver.fcmToken,
          });
        }
      }
    } catch (pushErr) {
      console.error('Failed to dispatch SOS Push Notifications:', pushErr);
    }
    
    res.status(201).json(newSOS);
  } catch (error) {
    res.status(500).json({ error: 'Failed to trigger SOS' });
  }
});

// Resolve or Cancel SOS
router.put('/:id', async (req, res) => {
  try {
    const { status, note, resolvedBy } = req.body;
    const updatedSOS = await SOS.findByIdAndUpdate(
      req.params.id,
      { status, note, resolvedBy },
      { new: true }
    );
    res.json(updatedSOS);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update SOS' });
  }
});

// Get active SOS for a user (if any)
router.get('/active/:userId', async (req, res) => {
  try {
    const activeSOS = await SOS.findOne({ 
      userId: req.params.userId, 
      status: 'active' 
    }).sort({ timestamp: -1 });
    res.json(activeSOS);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch active SOS' });
  }
});

// Get SOS history for a user
router.get('/history/:userId', async (req, res) => {
  try {
    const history = await SOS.find({ userId: req.params.userId })
      .sort({ timestamp: -1 })
      .limit(30);
    res.json(history);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch SOS history' });
  }
});

module.exports = router;
