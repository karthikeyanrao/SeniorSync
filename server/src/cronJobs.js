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
        if (!med.timeOfDay) continue;

        const medMins = med.timeOfDay.hour * 60 + med.timeOfDay.minute;
        const currMins = currH * 60 + currM;
        const elapsedMins = currMins - medMins;

        // If time is in the future, do nothing
        if (elapsedMins < 0) continue;

        // If >= 30 mins elapsed, formally mark as missed & alert caregiver ONCE
        if (elapsedMins >= 30) {
          med.status = 'missed';
          await med.save();
          console.log(`[CRON] Marking med ${med._id} as MISSED (elapsed 30+ mins)`);

          const senior = await User.findOne({ firebaseUid: med.userId });
          if (!senior) continue;

          if (senior.caregivers && senior.caregivers.length > 0) {
            const caregivers = await User.find({ firebaseUid: { $in: senior.caregivers }, fcmToken: { $exists: true, $ne: null } });
            for (const caregiver of caregivers) {
              try {
                const medTimeString = `${med.timeOfDay.hour.toString().padStart(2,'0')}:${med.timeOfDay.minute.toString().padStart(2,'0')}`;
                await admin.messaging().send({
                  notification: { title: 'Missed Medication Alert! 🚨', body: `${senior.name || 'Your senior'} has missed their dose of ${med.name} (${med.dosage}) scheduled at ${medTimeString}. Please check on them.` },
                  data: { type: 'MISSED_MED', seniorUid: senior.firebaseUid, medId: med._id.toString() },
                  android: { priority: 'high' },
                  token: caregiver.fcmToken,
                });
                console.log(`[CRON] Caregiver push sent for missed med: ${caregiver.firebaseUid}`);
              } catch (e) {
                console.error(`[CRON] Failed to send push to caregiver:`, e);
              }
            }
          }
        } 
        // If elapsed is 0-9 mins (right on time window), send soft reminder to senior ONCE
        else if (elapsedMins >= 0 && elapsedMins < 10) {
          const senior = await User.findOne({ firebaseUid: med.userId });
          if (senior && senior.fcmToken) {
            try {
              await admin.messaging().send({
                notification: { title: 'Time for Medication! 💊', body: `Don't forget to take ${med.name} (${med.dosage}) right now!` },
                data: { type: 'REMINDER_MED' },
                android: { priority: 'high' },
                token: senior.fcmToken,
              });
              console.log(`[CRON] Senior reminder push sent for med: ${senior.firebaseUid}`);
            } catch (e) {
              console.error(`[CRON] Failed to send push to senior:`, e);
            }
          }
        }
      }

      // 2. MISSED ROUTINES
      const missedRoutines = await Routine.find({ isCompletedToday: false, days: currentDayStr });
      for (const routine of missedRoutines) {
        if (!routine.time) continue;
        const rMins = routine.time.hour * 60 + routine.time.minute;
        const currMins = currH * 60 + currM;
        const elapsedMins = currMins - rMins;

        // Only send routine reminder once when it hits schedule (0-9 min window)
        // rather than repeatedly spamming every 10 mins as before
        if (elapsedMins >= 0 && elapsedMins < 10) {
          const senior = await User.findOne({ firebaseUid: routine.userId });
          if (senior && senior.fcmToken) {
            try {
              await admin.messaging().send({
                notification: { title: 'Routine Reminder! 📋', body: `It's time to complete your task: ${routine.title}` },
                data: { type: 'REMINDER_ROUTINE' },
                android: { priority: 'high' },
                token: senior.fcmToken,
              });
            } catch (e) {
              console.error(`[CRON] Failed to send routine push to senior:`, e);
            }
          }
        }
      }
    } catch (e) {
      console.error('[CRON] Error running scheduled jobs:', e);
    }
  });
};

module.exports = startCronJobs;
