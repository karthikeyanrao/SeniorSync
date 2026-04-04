const { DateTime, FixedOffsetZone } = require('luxon');

/**
 * Current wall-clock time in the user's zone, expressed as a Luxon DateTime.
 * Uses fixed offset minutes from UTC (no DST). Synced from the app on login.
 */
function nowInUserTz(timezoneOffsetMinutes) {
  const off = Number.isFinite(Number(timezoneOffsetMinutes)) ? Number(timezoneOffsetMinutes) : 0;
  return DateTime.now().setZone(FixedOffsetZone.instance(off));
}

/** Match JS getDay() labels used in Routine.days: 'Sun' … 'Sat' */
function appDayString(dtLuxon) {
  const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return names[dtLuxon.weekday % 7];
}

module.exports = { nowInUserTz, appDayString };
