const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const Vitals = require('../models/Vitals');
const requireAuth = require('../middleware/authMiddleware');

// Simple Ping (No DB Needed) — public
router.get('/ping', (req, res) => {
  res.json({ status: 'Server Alive ⚡', timestamp: new Date().toISOString() });
});

// Global Health Check Status (Requires DB) — public
router.get('/status', async (req, res) => {
  const dbStatus = mongoose.connection.readyState === 1 ? 'Connected 🟢' : 'Disconnected 🔴';
  const firebaseStatus = admin.apps.length > 0 ? 'Initialized 🟢' : 'Offline 🔴';
  
  let databaseTest = 'Not tested';
  try {
    if (mongoose.connection.readyState === 1) {
      const db = mongoose.connection.db;
      const collections = await db.listCollections().toArray();
      databaseTest = `Success! Found ${collections.length} tables 🟢`;
    }
  } catch (err) {
    databaseTest = `Failed 🔴: ${err.message}`;
  }

  res.json({
    status: 'Server Active',
    vercelEnv: process.env.VERCEL ? 'Production 🌐' : 'Development 💻',
    database: dbStatus,
    firebase: firebaseStatus,
    databasePingTest: databaseTest,
    timestamp: new Date().toISOString()
  });
});

// ─── VITALS (Protected) ───────────────────────────────────────────────────────

// Get vitals for a user
router.get('/vitals/:userId', requireAuth, async (req, res) => {
  try {
    const vitals = await Vitals.find({ userId: req.params.userId })
      .sort({ timestamp: -1 })
      .limit(30)
      .lean();
    res.json(vitals);
  } catch (error) {
    console.error('Error fetching vitals:', error);
    res.status(500).json({ error: error.message });
  }
});

// Add a vitals reading
router.post('/vitals', requireAuth, async (req, res) => {
  try {
    const newVitals = new Vitals(req.body);
    await newVitals.save();
    res.status(201).json(newVitals);
  } catch (error) {
    console.error('Error adding vitals:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete a vitals reading
router.delete('/vitals/:id', requireAuth, async (req, res) => {
  try {
    await Vitals.findByIdAndDelete(req.params.id);
    res.json({ message: 'Vitals deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete vitals' });
  }
});

module.exports = router;

