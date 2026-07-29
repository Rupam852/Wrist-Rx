/**
 * Midnight Health Data Reset Job
 * Runs daily at 00:00 to reset the "current" readings
 * but ARCHIVES daily summary before reset (data retained 30 days)
 *
 * This is called via a simple setInterval on server start.
 * For production, use a cron job or Render cron service.
 */
const HealthData = require('../models/HealthData');

function getMsUntilMidnight() {
  const now = new Date();
  const midnight = new Date(now);
  midnight.setHours(24, 0, 0, 0); // Next midnight
  return midnight.getTime() - now.getTime();
}

function startMidnightReset() {
  const msUntilMidnight = getMsUntilMidnight();
  console.log(`⏰ Midnight reset scheduled in ${Math.round(msUntilMidnight / 60000)} minutes`);

  setTimeout(async () => {
    await runReset();
    // After first run, repeat every 24 hours
    setInterval(runReset, 24 * 60 * 60 * 1000);
  }, msUntilMidnight);
}

async function runReset() {
  try {
    const today = new Date().toISOString().split('T')[0];
    console.log(`🔄 Running midnight health data reset for date: ${today}`);

    // Mark all of yesterday's docs as "reset"
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split('T')[0];

    await HealthData.updateMany(
      { date: yesterdayStr, resetAt: null },
      { $set: { resetAt: new Date() } }
    );

    // Clean up data older than 30 days
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);
    const cutoffStr = cutoff.toISOString().split('T')[0];
    const deleted = await HealthData.deleteMany({ date: { $lt: cutoffStr } });

    console.log(`✅ Midnight reset done. Archived yesterday. Deleted ${deleted.deletedCount} old records.`);
  } catch (error) {
    console.error('❌ Midnight reset error:', error);
  }
}

module.exports = { startMidnightReset };
