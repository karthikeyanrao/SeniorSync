
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  firebaseUid: {
    type: String,
    required: true,
    unique: true,
  },
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
  },
  age: Number,
  allergies: [String],
  conditions: [String],
  foodTimes: {
    morning: String,
    afternoon: String,
    night: String,
  },
  onboarded: {
    type: Boolean,
    default: false,
  },
  role: {
    type: String,
    enum: ['senior', 'caregiver'],
    default: 'senior',
  },
  pairingCode: {
    type: String,
    sparse: true,
    unique: true,
  },
  pairingCodeExpires: Date,
  caregivers: [{ 
    uid: String, 
    permissionLevel: { type: String, enum: ['admin', 'viewer'], default: 'admin' } 
  }], // Array of caregiver objects
  linkedSeniors: [String], // Array of senior firebaseUids
  refreshToken: {
    type: String,
    sparse: true,
  },
  fcmToken: {
    type: String,
    sparse: true,
  },
  /** Device offset from UTC in minutes (e.g. India +330). Used for med/routine cron. */
  timezoneOffsetMinutes: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Caregiver self-repair runs in authRoutes (sync) before save — avoids Mongoose 9 / Kareem pre('save') bugs on Vercel.

module.exports = mongoose.model('User', userSchema);
