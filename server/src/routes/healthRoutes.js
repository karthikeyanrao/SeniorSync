
const express = require('express');
const router = express.Router();
const Vitals = require('../models/Vitals');

// Add Vitals
router.post('/vitals', async (req, res) => {
  const { userId, bloodPressure, heartRate, bloodSugar } = req.body;
  try {
    const newVitals = new Vitals({
      userId,
      bloodPressure,
      heartRate,
      bloodSugar
    });
    await newVitals.save();
    res.status(201).json(newVitals);
  } catch (error) {
    res.status(500).json({ error: 'Failed to add vitals' });
  }
});

// Get Vitals for a User
router.get('/vitals/:userId', async (req, res) => {
  try {
    const oneMonthAgo = new Date();
    oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);

    const history = await Vitals.find({ 
      userId: req.params.userId,
      timestamp: { $gte: oneMonthAgo }
    }).sort({ timestamp: -1 });
    
    res.json(history);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch vitals' });
  }
});

module.exports = router;
