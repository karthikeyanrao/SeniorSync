
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

userSchema.pre('save', function(next) {
  // Global SELF-REPAIR: If 'caregivers' is corrupted (string/null/etc), force reset to []
  if (!Array.isArray(this.caregivers)) {
    console.warn(`[MODEL-REPAIR] Fixing caregivers array for: ${this.firebaseUid}`);
    this.caregivers = [];
  } else if (this.caregivers.length > 0 && typeof this.caregivers[0] !== 'object') {
    // If it's an array of strings instead of array of objects
    console.warn(`[MODEL-REPAIR] Fixing caregivers object map for: ${this.firebaseUid}`);
    this.caregivers = [];
  }
  next();
});

module.exports = mongoose.model('User', userSchema);
