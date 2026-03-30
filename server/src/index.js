
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Global Rate Limiting (BR-Security)
const rateLimit = require('express-rate-limit');
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 500, // Increased from 100 — app makes many requests per session
  standardHeaders: true,
  legacyHeaders: false,
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

// Start cron background workers
startCronJobs();

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on 0.0.0.0:${PORT}`);
});
