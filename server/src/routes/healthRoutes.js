const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const admin = require('firebase-admin');

// Simple Ping (No DB Needed)
router.get('/ping', (req, res) => {
  res.json({ status: 'Server Alive ⚡', timestamp: new Date().toISOString() });
});

// Global Health Check Status (Requires DB)
router.get('/status', async (req, res) => {
  const dbStatus = mongoose.connection.readyState === 1 ? 'Connected 🟢' : 'Disconnected 🔴';
  const firebaseStatus = admin.apps.length > 0 ? 'Initialized 🟢' : 'Offline 🔴';
  
  let databaseTest = 'Not tested';
  try {
    // 🔍 Real-time test: Can we reach the database RIGHT NOW?
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

module.exports = router;
