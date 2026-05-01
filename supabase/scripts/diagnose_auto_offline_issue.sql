-- =====================================================================================
-- DIAGNOSE WHY AUTO-OFFLINE ISN'T WORKING
-- =====================================================================================
-- This script helps diagnose why drivers aren't being marked offline
-- =====================================================================================

-- 1. Check if the cron job is actually running (execution history)
SELECT 
  jrd.start_time,
  jrd.end_time,
  jrd.status,
  jrd.return_message,
  NOW() - jrd.start_time as time_since_run
FROM cron.job_run_details jrd
JOIN cron.job j ON jrd.jobid = j.jobid
WHERE j.jobname = 'auto-offline-drivers-by-location'
ORDER BY jrd.start_time DESC
LIMIT 5;

-- 2. Show the specific drivers that should be offline
SELECT 
  u.id,
  u.name,
  u.is_online,
  u.role,
  MAX(dl.created_at) as last_location_update,
  NOW() - MAX(dl.created_at) as time_since_update,
  EXTRACT(EPOCH FROM (NOW() - MAX(dl.created_at))) / 60.0 as minutes_since_update,
  CASE 
    WHEN MAX(dl.created_at) IS NULL THEN 'No location records'
    WHEN MAX(dl.created_at) < NOW() - INTERVAL '10 minutes' THEN 'Stale location (>10 min)'
    ELSE 'OK'
  END as status
FROM users u
LEFT JOIN driver_locations dl ON u.id = dl.driver_id
WHERE u.role = 'driver' 
  AND u.is_online = TRUE
GROUP BY u.id, u.name, u.is_online, u.role
HAVING MAX(dl.created_at) IS NULL OR MAX(dl.created_at) < NOW() - INTERVAL '10 minutes'
ORDER BY last_location_update ASC NULLS FIRST;

-- 3. Test the function manually and see what it returns
SELECT * FROM mark_drivers_offline_by_location();

-- 4. Check if the function actually updated anything
-- Run this AFTER running the function above
SELECT 
  u.id,
  u.name,
  u.is_online,
  u.updated_at,
  MAX(dl.created_at) as last_location_update
FROM users u
LEFT JOIN driver_locations dl ON u.id = dl.driver_id
WHERE u.role = 'driver'
  AND u.id IN (
    SELECT id FROM users 
    WHERE role = 'driver' 
    AND is_online = TRUE
    GROUP BY id
    HAVING MAX((SELECT created_at FROM driver_locations WHERE driver_id = users.id)) IS NULL 
       OR MAX((SELECT created_at FROM driver_locations WHERE driver_id = users.id)) < NOW() - INTERVAL '10 minutes'
  )
GROUP BY u.id, u.name, u.is_online, u.updated_at;

-- 5. Check the function definition to see if there's an issue
SELECT 
  p.proname as function_name,
  pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
WHERE p.proname IN ('mark_drivers_offline_by_location', 'call_mark_drivers_offline_by_location')
ORDER BY p.proname;

-- 6. Manually test the UPDATE logic that the function should be doing
WITH latest_locations AS (
  SELECT DISTINCT ON (dl.driver_id)
    dl.driver_id,
    dl.created_at as last_location_update
  FROM driver_locations dl
  ORDER BY dl.driver_id, dl.created_at DESC
)
SELECT 
  u.id,
  u.name,
  u.is_online,
  ll.last_location_update,
  CASE 
    WHEN ll.last_location_update < NOW() - INTERVAL '10 minutes' THEN 'Should be updated'
    ELSE 'OK'
  END as should_update
FROM users u
LEFT JOIN latest_locations ll ON u.id = ll.driver_id
WHERE u.role = 'driver'
  AND u.is_online = TRUE
  AND (ll.last_location_update IS NULL OR ll.last_location_update < NOW() - INTERVAL '10 minutes');

-- 7. Try manually updating one driver to see if it works
-- (Uncomment to test)
/*
WITH latest_locations AS (
  SELECT DISTINCT ON (dl.driver_id)
    dl.driver_id,
    dl.created_at as last_location_update
  FROM driver_locations dl
  ORDER BY dl.driver_id, dl.created_at DESC
)
UPDATE users u
SET 
  is_online = FALSE,
  updated_at = NOW()
FROM latest_locations ll
WHERE u.id = ll.driver_id
  AND u.role = 'driver'
  AND u.is_online = TRUE
  AND ll.last_location_update < NOW() - INTERVAL '10 minutes'
RETURNING u.id, u.name, u.is_online;
*/

