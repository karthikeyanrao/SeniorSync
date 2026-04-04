const cron = require('node-cron');
const admin = require('firebase-admin');
const Medication = require('./models/Medication');
const Routine = require('./models/Routine');
const User = require('./models/User');

const checkMissedAlerts = async () => {
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

        // Alert senior as well
        if (senior.fcmToken) {
          try {
            await admin.messaging().send({
              notification: { title: 'Dose Missed! ⚠️', body: `You missed your dose of ${med.name} (${med.dosage}). Please take it as soon as possible if safe.` },
              data: { type: 'MISSED_MED_PATIENT', medId: med._id.toString() },
              android: { 
                priority: 'high',
                notification: {
                  sound: med.notificationSound || 'default'
                }
              },
              token: senior.fcmToken,
            });
            console.log(`[CRON] Senior push sent for missed med: ${senior.firebaseUid}`);
          } catch (e) {
            console.error(`[CRON] Failed to send missed push to senior:`, e);
          }
        }

        if (senior.caregivers && senior.caregivers.length > 0) {
          const caregiverUids = senior.caregivers.map(c => c.uid);
          const caregivers = await User.find({ firebaseUid: { $in: caregiverUids }, fcmToken: { $exists: true, $ne: null } });
          for (const caregiver of caregivers) {
            try {
              const medTimeString = `${med.timeOfDay.hour.toString().padStart(2,'0')}:${med.timeOfDay.minute.toString().padStart(2,'0')}`;
              await admin.messaging().send({
                notification: { title: 'Missed Medication Alert! 🚨', body: `${senior.name || 'Your senior'} has missed their dose of ${med.name} (${med.dosage}) scheduled at ${medTimeString}. Please check on them.` },
                data: { type: 'MISSED_MED', seniorUid: senior.firebaseUid, medId: med._id.toString() },
                android: { 
                  priority: 'high',
                  notification: {
                    sound: 'warning_alert_tone'
                  }
                },
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
              android: { 
                priority: 'high',
                notification: {
                  sound: med.notificationSound || 'default'
                }
              },
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
};

const runMidnightReset = async () => {
  try {
    console.log('[CRON] Running Midnight Reset...');
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][yesterday.getDay()];

    const failedRoutines = await Routine.find({ isCompletedToday: false, days: yesterdayStr });
    for (const r of failedRoutines) {
      r.streak = 0;
      await r.save();
    }
    console.log(`[CRON] Reset streaks for ${failedRoutines.length} missed routines.`);

    await Routine.updateMany({}, { isCompletedToday: false });
    await Medication.updateMany({ status: { $in: ['taken', 'skipped', 'missed', 'snoozed'] } }, { status: 'scheduled', skippedReason: null });
  } catch (e) {
    console.error('[CRON] Midnight reset failed:', e);
  }
};

const runDataArchival = async () => {
  try {
    console.log('[CRON] Checking for old records to archive...');
    const twoYearsAgo = new Date();
    twoYearsAgo.setFullYear(twoYearsAgo.getFullYear() - 2);

    const Vitals = require('./models/Vitals');
    if (Vitals) {
      const result = await Vitals.deleteMany({ timestamp: { $lt: twoYearsAgo } });
      console.log(`[CRON] Archived/Deleted ${result.deletedCount} old vitals records.`);
    }
  } catch (e) {
    console.error('[CRON] Archival job failed:', e);
  }
};

const startCronJobs = () => {
  cron.schedule('*/10 * * * *', checkMissedAlerts);
  cron.schedule('0 0 * * *', runMidnightReset);
  cron.schedule('0 2 * * *', runDataArchival);
};

module.exports = { startCronJobs, checkMissedAlerts, runMidnightReset, runDataArchival };
