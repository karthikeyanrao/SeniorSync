
const mongoose = require('mongoose');

const sosSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true,
  },
  location: {
    latitude: Number,
    longitude: Number,
    address: String,
  },
  status: {
    type: String,
    enum: ['active', 'resolved', 'cancelled'],
    default: 'active',
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
  resolvedBy: String, // Caregiver ID if resolved
  note: String,
});

module.exports = mongoose.model('SOS', sosSchema);
