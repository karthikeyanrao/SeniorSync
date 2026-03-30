
const mongoose = require('mongoose');

const vitalsSchema = new mongoose.Schema({
  userId: {
    type: String, // Firebase UID
    required: true,
    index: true,
  },
  bloodPressure: {
    type: String,
    required: true,
  },
  heartRate: {
    type: Number,
    required: true,
  },
  bloodSugar: {
    type: Number,
    required: true,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('Vitals', vitalsSchema);
