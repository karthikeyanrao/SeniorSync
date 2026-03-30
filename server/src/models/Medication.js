
const mongoose = require('mongoose');

const medicationSchema = new mongoose.Schema({
  userId: {
    type: String, // Firebase UID
    required: true,
    index: true,
  },
  name: {
    type: String,
    required: true,
  },
  dosage: {
    type: String,
    required: true,
  },
  timeOfDay: {
    hour: Number,
    minute: Number,
  },
  notes: String,
  status: {
    type: String,
    enum: ['scheduled', 'taken', 'skipped', 'missed', 'snoozed'],
    default: 'scheduled',
  },
  lastUpdated: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('Medication', medicationSchema);
