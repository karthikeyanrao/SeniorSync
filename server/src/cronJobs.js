const cron = require('node-cron');
const admin = require('firebase-admin');
const Medication = require('./models/Medication');
const Routine = require('./models/Routine');
const User = require('./models/User');

const startCronJobs = () => {
  cron.schedule('*/10 * * * *', async () => {
    try {
      console.log('[CRON] Checking for missed medications and routines...');
      const now = new Date();
      const currH = now.getHours();
      const currM = now.getMinutes();
      const currentDayStr = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][now.getDay()];

      // 1. MISSED MEDICATIONS
      const medications = await Medication.find({ status: 'scheduled' });
      for (const med of medications) {
        if (!med.timeOfDay || (med.timeOfDay.hour > currH || (med.timeOfDay.hour === currH && med.timeOfDay.minute > currM))) continue;

        const senior = await User.findOne({ firebaseUid: med.userId });
        if (!senior) continue;

        if (senior.fcmToken) {
          try {
            await admin.messaging().send({
              notification: { title: 'Time for Medication! 💊', body: `Don't forget to take ${med.name} (${med.dosage}) right now!` },
              data: { type: 'REMINDER_MED' },
              token: senior.fcmToken,
            });
          } catch (e) {
            console.error(`[CRON] Failed to send push to senior:`, e);
          }
        }

        if (senior.caregivers && senior.caregivers.length > 0) {
          const caregivers = await User.find({ firebaseUid: { $in: senior.caregivers }, fcmToken: { $exists: true, $ne: null } });
          for (const caregiver of caregivers) {
            try {
              const medTimeString = `${med.timeOfDay.hour.toString().padStart(2,'0')}:${med.timeOfDay.minute.toString().padStart(2,'0')}`;
              await admin.messaging().send({
                notification: { title: 'Missed Medication Alert! 🚨', body: `${senior.name} has missed their dose of ${med.name} (${med.dosage}) scheduled at ${medTimeString}. Please check on them.` },
                data: { type: 'MISSED_MED', seniorUid: senior.firebaseUid, medId: med._id.toString() },
                token: caregiver.fcmToken,
              });
            } catch (e) {
              console.error(`[CRON] Failed to send push to caregiver:`, e);
            }
          }
        }
      }

      // 2. MISSED ROUTINES
      const missedRoutines = await Routine.find({ isCompletedToday: false, days: currentDayStr });
      for (const routine of missedRoutines) {
        if (!routine.time || (routine.time.hour > currH || (routine.time.hour === currH && routine.time.minute > currM))) continue;

        const senior = await User.findOne({ firebaseUid: routine.userId });
        if (senior && senior.fcmToken) {
          try {
            await admin.messaging().send({
              notification: { title: 'Routine Reminder! 📋', body: `It's time to complete your task: ${routine.title}` },
              data: { type: 'REMINDER_ROUTINE' },
              token: senior.fcmToken,
            });
          } catch (e) {
            console.error(`[CRON] Failed to send routine push to senior:`, e);
          }
        }
      }
    } catch (e) {
      console.error('[CRON] Error running scheduled jobs:', e);
    }
  });
};

module.exports = startCronJobs;
