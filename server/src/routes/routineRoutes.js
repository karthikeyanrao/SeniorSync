
const express = require('express');
const router = express.Router();
const Routine = require('../models/Routine');

// Get all routines for a user
router.get('/:userId', async (req, res) => {
  try {
    // Reset isCompletedToday if it's a new day (single bulk operation)
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    
    await Routine.updateMany(
      { 
        userId: req.params.userId,
        isCompletedToday: true,
        lastCompletedDate: { $lt: startOfToday }
      },
      { $set: { isCompletedToday: false } }
    );

    const routines = await Routine.find({ userId: req.params.userId });
    res.json(routines);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch routines' });
  }
});

// Add a routine
router.post('/', async (req, res) => {
  try {
    const newRoutine = new Routine(req.body);
    await newRoutine.save();
    res.status(201).json(newRoutine);
  } catch (error) {
    res.status(500).json({ error: 'Failed to add routine' });
  }
});

// Edit routine
router.put('/:id', async (req, res) => {
  try {
    const updated = await Routine.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!updated) return res.status(404).json({ error: 'Routine not found' });
    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update routine' });
  }
});

// Mark routine as completed
router.put('/complete/:id', async (req, res) => {
  try {
    const routine = await Routine.findById(req.params.id);
    if (!routine) return res.status(404).json({ error: 'Routine not found' });

    const now = new Date();
    const lastDate = routine.lastCompletedDate ? new Date(routine.lastCompletedDate) : null;
    
    // Streak logic
    if (lastDate) {
      const diffTime = Math.abs(now - lastDate);
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      if (diffDays === 1) {
        routine.streak += 1;
      } else if (diffDays > 1) {
        routine.streak = 1;
      }
    } else {
      routine.streak = 1;
    }

    routine.isCompletedToday = true;
    routine.lastCompletedDate = now;
    await routine.save();
    
    res.json(routine);
  } catch (error) {
    res.status(500).json({ error: 'Failed to complete routine' });
  }
});

// Delete routine
router.delete('/:id', async (req, res) => {
  try {
    await Routine.findByIdAndDelete(req.params.id);
    res.json({ message: 'Routine deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete routine' });
  }
});

module.exports = router;
