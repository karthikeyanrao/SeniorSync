
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
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('User', userSchema);
