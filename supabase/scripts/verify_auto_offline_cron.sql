-- =====================================================================================
-- VERIFY AUTO-OFFLINE DRIVERS CRON JOB
-- =====================================================================================
-- This script checks if the auto-offline drivers cron job is properly scheduled
-- =====================================================================================

-- Check if pg_cron extension is enabled
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') 
    THEN '✅ pg_cron is ENABLED' 
    ELSE '❌ pg_cron is NOT ENABLED - Go to Supabase Dashboard > Database > Extensions > Enable pg_cron'
  END as pg_cron_status;

-- Check if the cron job is scheduled
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  active,
  CASE 
    WHEN active THEN '✅ ACTIVE' 
    ELSE '❌ INACTIVE' 
  END as status
FROM cron.job
WHERE jobname = 'auto-offline-drivers-by-location';

-- If no results, the job is not scheduled
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'auto-offline-drivers-by-location') THEN
    RAISE NOTICE '⚠️  Cron job "auto-offline-drivers-by-location" is NOT scheduled';
    RAISE NOTICE '   Run the migration: 20260117000000_auto_offline_drivers_by_location.sql';
  ELSE
    RAISE NOTICE '✅ Cron job is scheduled';
  END IF;
END $$;

-- Show recent execution history (last 10 runs)
SELECT 
  j.jobname,
  jrd.start_time,
  jrd.end_time,
  jrd.status,
  jrd.return_message,
  CASE 
    WHEN jrd.status = 'succeeded' THEN '✅ SUCCESS'
    WHEN jrd.status = 'failed' THEN '❌ FAILED'
    WHEN jrd.status = 'running' THEN '🔄 RUNNING'
    ELSE '⚠️ ' || jrd.status
  END as status_display
FROM cron.job_run_details jrd
JOIN cron.job j ON jrd.jobid = j.jobid
WHERE j.jobname = 'auto-offline-drivers-by-location'
ORDER BY jrd.start_time DESC
LIMIT 10;

-- Test the function manually (uncomment to run)
-- SELECT * FROM mark_drivers_offline_by_location();

-- Check which drivers would be affected (drivers who should be offline)
SELECT 
  u.id,
  u.name,
  u.is_online,
  MAX(dl.created_at) as last_location_update,
  NOW() - MAX(dl.created_at) as time_since_update,
  CASE 
    WHEN MAX(dl.created_at) IS NULL THEN 'No location records'
    WHEN MAX(dl.created_at) < NOW() - INTERVAL '10 minutes' THEN 'Should be offline (>10 min)'
    ELSE 'OK'
  END as status
FROM users u
LEFT JOIN driver_locations dl ON u.id = dl.driver_id
WHERE u.role = 'driver' AND u.is_online = TRUE
GROUP BY u.id, u.name, u.is_online
HAVING MAX(dl.created_at) IS NULL OR MAX(dl.created_at) < NOW() - INTERVAL '10 minutes'
ORDER BY last_location_update ASC NULLS FIRST;

