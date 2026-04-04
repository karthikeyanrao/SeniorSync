
const express = require('express');
const router = express.Router();
const Medication = require('../models/Medication');

// Get all medications for a user
router.get('/:userId', async (req, res) => {
  try {
    // 💡 Use .lean() to bypass potential corruption crashes
    const medications = await Medication.find({ userId: req.params.userId }).lean();
    res.json(medications);
  } catch (error) {
    console.error('Error fetching medications:', error);
    res.status(500).json({ error: error.message });
  }
});

// Add a medication
router.post('/', async (req, res) => {
  try {
    const newMed = new Medication(req.body);
    await newMed.save();
    res.status(201).json(newMed);
  } catch (error) {
    res.status(500).json({ error: 'Failed to add medication' });
  }
});

// Update medication status or details
router.put('/:id', async (req, res) => {
  try {
    const updatedMed = await Medication.findByIdAndUpdate(
      req.params.id,
      { ...req.body, lastUpdated: Date.now() },
      { new: true }
    );
    res.json(updatedMed);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update medication' });
  }
});

// Delete medication
router.delete('/:id', async (req, res) => {
  try {
    await Medication.findByIdAndDelete(req.params.id);
    res.json({ message: 'Medication deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete medication' });
  }
});

module.exports = router;
