-- =====================================================================================
-- CHECK AUTO-OFFLINE DRIVERS CRON JOB EXECUTION
-- =====================================================================================
-- This script checks if the cron job is actually running and if there are any errors
-- =====================================================================================

-- 1. Check execution history for auto-offline-drivers-by-location
SELECT 
  jrd.jobid,
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
  END as status_display,
  EXTRACT(EPOCH FROM (jrd.end_time - jrd.start_time)) as duration_seconds,
  NOW() - jrd.start_time as time_since_last_run
FROM cron.job_run_details jrd
JOIN cron.job j ON jrd.jobid = j.jobid
WHERE j.jobname = 'auto-offline-drivers-by-location'
ORDER BY jrd.start_time DESC
LIMIT 20;

-- 2. Summary of execution status
SELECT 
  COUNT(*) as total_runs,
  COUNT(*) FILTER (WHERE status = 'succeeded') as successful_runs,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_runs,
  COUNT(*) FILTER (WHERE status = 'running') as running_runs,
  MAX(start_time) as last_run_time,
  NOW() - MAX(start_time) as time_since_last_run
FROM cron.job_run_details jrd
JOIN cron.job j ON jrd.jobid = j.jobid
WHERE j.jobname = 'auto-offline-drivers-by-location';

-- 3. Check if the function exists and can be called
SELECT 
  'Function Check' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'call_mark_drivers_offline_by_location') 
    THEN '✅ EXISTS' 
    ELSE '❌ NOT FOUND' 
  END as wrapper_function,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'mark_drivers_offline_by_location') 
    THEN '✅ EXISTS' 
    ELSE '❌ NOT FOUND' 
  END as main_function;

-- 4. Test the function manually to see if it works
DO $$
DECLARE
  v_test_result RECORD;
BEGIN
  RAISE NOTICE 'Testing call_mark_drivers_offline_by_location()...';
  
  BEGIN
    PERFORM call_mark_drivers_offline_by_location();
    RAISE NOTICE '✅ Function executed successfully (no errors)';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING '❌ Function failed: %', SQLERRM;
      RAISE WARNING 'Error details: %', SQLSTATE;
  END;
END $$;

-- 5. Check recent driver location updates to see if any drivers should be offline
SELECT 
  u.id,
  u.name,
  u.is_online,
  MAX(dl.created_at) as last_location_update,
  NOW() - MAX(dl.created_at) as time_since_update,
  CASE 
    WHEN MAX(dl.created_at) IS NULL THEN 'No location records - Should be offline'
    WHEN MAX(dl.created_at) < NOW() - INTERVAL '10 minutes' THEN 'Should be offline (>10 min)'
    ELSE 'OK'
  END as status
FROM users u
LEFT JOIN driver_locations dl ON u.id = dl.driver_id
WHERE u.role = 'driver' 
  AND u.is_online = TRUE
GROUP BY u.id, u.name, u.is_online
HAVING MAX(dl.created_at) IS NULL OR MAX(dl.created_at) < NOW() - INTERVAL '10 minutes'
ORDER BY last_location_update ASC NULLS FIRST;

-- 6. Count how many drivers should be offline but aren't
WITH driver_status AS (
  SELECT 
    u.id,
    u.name,
    u.is_online,
    MAX(dl.created_at) as last_location_update
  FROM users u
  LEFT JOIN driver_locations dl ON u.id = dl.driver_id
  WHERE u.role = 'driver' 
    AND u.is_online = TRUE
  GROUP BY u.id, u.name, u.is_online
  HAVING MAX(dl.created_at) IS NULL OR MAX(dl.created_at) < NOW() - INTERVAL '10 minutes'
)
SELECT 
  COUNT(*) as drivers_that_should_be_offline,
  COUNT(*) FILTER (WHERE last_location_update IS NULL) as drivers_with_no_location,
  COUNT(*) FILTER (WHERE last_location_update < NOW() - INTERVAL '10 minutes') as drivers_with_stale_location
FROM driver_status;

