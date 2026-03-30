
const mongoose = require('mongoose');

const routineSchema = new mongoose.Schema({
  userId: {
    type: String, // Firebase UID
    required: true,
    index: true,
  },
  title: {
    type: String,
    required: true,
  },
  description: String,
  time: {
    hour: Number,
    minute: Number,
  },
  days: [String], // ['Mon', 'Tue', ...]
  isCompletedToday: {
    type: Boolean,
    default: false,
  },
  lastCompletedDate: Date,
  streak: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('Routine', routineSchema);
