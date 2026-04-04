const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Medication = require('../models/Medication');
const Vitals = require('../models/Vitals');
const SOS = require('../models/SOS');
const { nowInUserTz } = require('../utils/userLocalTime');

// Get all linked seniors for a caregiver
router.get('/seniors/:caregiverUid', async (req, res) => {
  try {
    // 1. Connection Guard: Don't attempt if DB is disconnected
    const mongoose = require('mongoose');
    if (mongoose.connection.readyState !== 1) {
      console.error('[DB-GUARD] Database not connected. Current state:', mongoose.connection.readyState);
      return res.status(503).json({ error: 'Database connecting, please try again in a moment.' });
    }

    const caregiver = await User.findOne({ firebaseUid: req.params.caregiverUid }).lean();
    if (!caregiver) return res.status(404).json({ error: 'Caregiver not found' });

    // Fetch raw details of all linked seniors (use .lean() to prevent crashes)
    const seniors = await User.find({ firebaseUid: { $in: caregiver.linkedSeniors || [] } }).lean();
    
    // For each senior, fetch latest vitals, active SOS, and missed medications
    const enrichedSeniors = await Promise.all(seniors.map(async (senior) => {
      const activeSOS = await SOS.findOne({ userId: senior.firebaseUid, status: 'active' }).sort({ timestamp: -1 });
      const lastVitals = await Vitals.findOne({ userId: senior.firebaseUid }).sort({ timestamp: -1 });
      
      const local = nowInUserTz(senior.timezoneOffsetMinutes);
      const currH = local.hour;
      const currM = local.minute;

      const allPendingMeds = await Medication.find({
        userId: senior.firebaseUid,
        status: 'scheduled'
      });

      const missedMedications = allPendingMeds.filter((med) => {
        if (!med.timeOfDay) return false;
        const h = med.timeOfDay.hour ?? 0;
        const m = med.timeOfDay.minute ?? 0;
        return h < currH || (h === currH && m <= currM);
      });

      return {
        ...senior,
        activeSOS: activeSOS ? activeSOS.toObject() : null,
        latestVitals: lastVitals ? lastVitals.toObject() : null,
        missedMedications: missedMedications.map(m => m.toObject())
      };
    }));

    res.json(enrichedSeniors);
  } catch (error) {
    console.error('Error fetching linked seniors:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

module.exports = router;
