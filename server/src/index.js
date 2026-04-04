
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Trust Vercel's proxy for Rate Limiting
app.set('trust proxy', 1);

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

// Middleware
app.use(cors());
app.use(express.json());

// Request Logger — See what the Flutter app is sending
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  if (req.method === 'POST' || req.method === 'PATCH' || req.method === 'PUT') {
    console.log('  Body:', JSON.stringify(req.body));
  }
  next();
});

// Database Connection
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('Connected to MongoDB'))
  .catch(err => console.error('MongoDB connection error:', err));

// Routes
app.get('/', (req, res) => {
  res.send('SeniorSync Backend is running...');
});

// Import Routes
const authRoutes = require('./routes/authRoutes');
const healthRoutes = require('./routes/healthRoutes');
const medicationRoutes = require('./routes/medicationRoutes');
const sosRoutes = require('./routes/sosRoutes');
const routineRoutes = require('./routes/routineRoutes');

const caregiverRoutes = require('./routes/caregiverRoutes');
const requireAuth = require('./middleware/authMiddleware');
const startCronJobs = require('./cronJobs');

app.use('/api/auth', authRoutes);
app.use('/api/health', requireAuth, healthRoutes);
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
