-- =====================================================================================
-- CHECK WHATSAPP QUEUE CRON JOB STATUS
-- =====================================================================================
-- Run this in Supabase SQL Editor to diagnose issues
-- =====================================================================================

-- 1. Check if cron job exists and is active
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  CASE WHEN active THEN '✅ ACTIVE' ELSE '❌ INACTIVEå' END as status
FROM cron.job
WHERE jobname = 'process-whatsapp-queue';

-- 2. Check recent execution history
SELECT 
  start_time,
  end_time,
  status,
  return_message,
  NOW() - start_time as time_since_run
FROM cron.job_run_details jrd
JOIN cron.job j ON jrd.jobid = j.jobid
WHERE j.jobname = 'process-whatsapp-queue'
ORDER BY start_time DESC
LIMIT 10;

-- 3. Check pending messages
SELECT COUNT(*) as pen_messages FROM whatsapp_announcement_queue WHERE status = 'pending';

-- 4. Test function manually
SELECT trigger_whatsapp_queue_processor();
