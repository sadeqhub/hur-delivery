-- =====================================================================================
-- LIST ALL CRON JOBS IN DATABASE
-- =====================================================================================
-- This script shows all scheduled cron jobs with their status, schedule, and details
-- =====================================================================================

-- List all cron jobs with their details
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
  END as status,
  jobid as job_id
FROM cron.job
ORDER BY jobname;

-- Count summary
SELECT 
  COUNT(*) as total_jobs,
  COUNT(*) FILTER (WHERE active = true) as active_jobs,
  COUNT(*) FILTER (WHERE active = false) as inactive_jobs
FROM cron.job;

-- Show execution history for all jobs (last 20 runs)
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

