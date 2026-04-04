
const express = require('express');
const mongoose = require('mongoose');
const admin = require('firebase-admin');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Trust Vercel's proxy for Rate Limiting
app.set('trust proxy', 1);

// Global Rate Limiting (BR-Security)
app.use(express.json());

// 🟢 PUBLIC STATUS CHECK (NO TOKEN NEEDED)
// This is at the very top to ensure it is always accessible without 401
app.get('/api/health/ping', (req, res) => res.json({ status: 'Server Active 🟢', timestamp: new Date() }));

// Global Rate Limiting (BR-Security)
const rateLimit = require('express-rate-limit');
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 500, // Increased from 100 — app makes many requests per session
  standardHeaders: true,
  legacyHeaders: false,
  validate: { trustProxy: false },
});
app.use(limiter);

// Request Logger — See what the Flutter app is sending
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  if (req.method === 'POST' || req.method === 'PATCH' || req.method === 'PUT') {
    console.log('  Body:', JSON.stringify(req.body));
  }
  next();
});

// Database Connection — Vercel serverless: one shared in-flight promise per instance
const mongoGlobal = global;
if (!mongoGlobal.__seniorsyncConn) {
  mongoGlobal.__seniorsyncConn = { promise: null };
}
const connCache = mongoGlobal.__seniorsyncConn;

async function connectDB() {
  if (!process.env.MONGODB_URI || !String(process.env.MONGODB_URI).trim()) {
    throw new Error('MONGODB_URI is missing — add it in Vercel Project → Settings → Environment Variables');
  }
  if (mongoose.connection.readyState === 1) return;

  if (mongoose.connection.readyState === 2) {
    await mongoose.connection.asPromise();
    return;
  }

  if (!connCache.promise) {
    const uri = process.env.MONGODB_URI;
    connCache.promise = mongoose
      .connect(uri, {
        serverSelectionTimeoutMS: 20000,
        socketTimeoutMS: 45000,
        connectTimeoutMS: 20000,
        maxPoolSize: 5,
        // Buffer until connected — avoids 503 when readyState lags one tick after connect resolves on serverless
        bufferCommands: true,
      })
      .then(() => {
        console.log('Connected to MongoDB ✅');
      })
      .catch((err) => {
        connCache.promise = null;
        throw err;
      });
  }

  try {
    await connCache.promise;
  } catch (err) {
    connCache.promise = null;
    console.error('MongoDB connection error:', err);
    throw err;
  }
}

// Connect immediately on boot and also ensure connected on each request
connectDB();

// Middleware to ensure DB is connected before any route that needs it
app.use(async (req, res, next) => {
  if (req.path === '/api/health/ping') return next();
  const run = async () => {
    await connectDB();
    next();
  };
  try {
    await run();
  } catch (err) {
    console.warn('[DB] First connect attempt failed:', err.message);
    try {
      await new Promise((r) => setTimeout(r, 200));
      connCache.promise = null;
      await run();
    } catch (err2) {
      console.error('[DB] Connection failed:', err2.message);
      res.status(503).json({ error: 'Database unavailable, please retry.' });
    }
  }
});

// Initialize Firebase Admin (for SOS & Missed Dose Notifications)
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        // Ensure private key handles newlines correctly from Vercel
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      }),
    });
    console.log('Firebase Admin Initialized');
  } catch (err) {
    console.error('Firebase Admin initialization error:', err);
  }
}

// Routes
app.get('/', (req, res) => {
  res.send('SeniorSync Backend is running...');
});

// Import Routes
const authRoutes = require('./routes/authRoutes');
const medicationRoutes = require('./routes/medicationRoutes');
const healthRoutes = require('./routes/healthRoutes'); // Add this for status check
const sosRoutes = require('./routes/sosRoutes');
const routineRoutes = require('./routes/routineRoutes');

const caregiverRoutes = require('./routes/caregiverRoutes');
const requireAuth = require('./middleware/authMiddleware');
// Scheduled jobs run via Vercel Cron → GET /api/cron/trigger (see cronJobs.js)

// Final Route Registration
app.use('/api/health', healthRoutes);           // Public: /api/health/ping, /api/health/status, /api/health/vitals
app.use('/api/auth', authRoutes);               // Public: sync, profile, pair
app.use('/api/medications', requireAuth, medicationRoutes);
app.use('/api/sos', requireAuth, sosRoutes);
app.use('/api/routines', requireAuth, routineRoutes);
app.use('/api/caregivers', requireAuth, caregiverRoutes);

// Vercel Cron Trigger Endpoint (SEC: Protected by a simple secret if desired)
app.get('/api/cron/trigger', async (req, res) => {
  console.log('[CRON-TRIGGER] Manual trigger received...');
  try {
    const { checkMissedAlerts, runMidnightReset, runDataArchival } = require('./cronJobs');

    // Run all tasks
    await checkMissedAlerts();

    // Run midnight tasks only if triggered around midnight (or just run them anyway for testing)
    const hour = new Date().getHours();
    if (hour === 0) await runMidnightReset();
    if (hour === 2) await runDataArchival();

    res.json({ status: 'Cron tasks executed successfully' });
  } catch (err) {
    console.error('[CRON-TRIGGER] Error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Module Exports (for Vercel)
module.exports = app;

if (process.env.NODE_ENV !== 'production' || !process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running locally on 0.0.0.0:${PORT}`);
  });
}
