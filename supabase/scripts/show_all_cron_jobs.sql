-- =====================================================================================
-- SHOW ALL CRON JOBS
-- =====================================================================================
-- This script shows all scheduled cron jobs with their status, schedule, and details
-- =====================================================================================

-- 1. Check if pg_cron extension is enabled
SELECT 
  'pg_cron Extension' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') 
    THEN '✅ ENABLED' 
    ELSE '❌ NOT ENABLED' 
  END as status;

-- 2. List ALL cron jobs with full details
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active,
  CASE 
    WHEN active THEN '✅ ACTIVE' 
    ELSE '❌ INACTIVE' 
  END as status
FROM cron.job
ORDER BY jobname;

-- 3. Count summary
SELECT 
  COUNT(*) as total_jobs,
  COUNT(*) FILTER (WHERE active = true) as active_jobs,
  COUNT(*) FILTER (WHERE active = false) as inactive_jobs
FROM cron.job;

-- 4. Show execution history for ALL jobs (last 20 runs)
SELECT 
  j.jobname,
  jrd.jobid,
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
ORDER BY jrd.start_time DESC
LIMIT 20;

-- 5. Specifically check for auto-offline-drivers-by-location job
SELECT 
  'auto-offline-drivers-by-location Job' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'auto-offline-drivers-by-location') 
    THEN '✅ EXISTS' 
    ELSE '❌ NOT FOUND' 
  END as status;

-- 6. Detailed info for auto-offline-drivers-by-location job (if it exists)
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  active,
  CASE 
    WHEN active THEN '✅ ACTIVE - Should run every 2 minutes' 
    ELSE '❌ INACTIVE - Job exists but is not running' 
  END as status,
  nodename,
  nodeport,
  database,
  username
FROM cron.job
WHERE jobname = 'auto-offline-drivers-by-location';

-- 7. Execution history for auto-offline-drivers-by-location (if it exists)
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
  END as status_display,
  EXTRACT(EPOCH FROM (jrd.end_time - jrd.start_time)) as duration_seconds
FROM cron.job_run_details jrd
JOIN cron.job j ON jrd.jobid = j.jobid
WHERE j.jobname = 'auto-offline-drivers-by-location'
ORDER BY jrd.start_time DESC
LIMIT 10;

-- 8. Check if the function exists
SELECT 
  'Function Exists' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'call_mark_drivers_offline_by_location') 
    THEN '✅ call_mark_drivers_offline_by_location() EXISTS' 
    ELSE '❌ call_mark_drivers_offline_by_location() NOT FOUND' 
  END as status,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'mark_drivers_offline_by_location') 
    THEN '✅ mark_drivers_offline_by_location() EXISTS' 
    ELSE '❌ mark_drivers_offline_by_location() NOT FOUND' 
  END as main_function_status;

