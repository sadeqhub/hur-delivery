-- =====================================================================================
-- CHECK DAILY SUMMARY EMAIL CRON JOB STATUS
-- =====================================================================================
-- Run this script in Supabase SQL Editor to diagnose issues with the daily summary email
-- =====================================================================================

-- 1. Check if extensions are enabled
SELECT 
  'Extensions Status' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') 
    THEN '✅ pg_cron enabled' 
    ELSE '❌ pg_cron NOT enabled' 
  END as pg_cron_status,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
    THEN '✅ pg_net enabled' 
    ELSE '❌ pg_net NOT enabled' 
  END as pg_net_status;

-- 2. Check if cron job exists and is active
SELECT 
  'Cron Job Status' as check_type,
  jobid,
  jobname,
  schedule,
  active,
  CASE 
    WHEN active THEN '✅ ACTIVE' 
    ELSE '❌ INACTIVE' 
  END as status,
  command
FROM cron.job
WHERE jobname = 'daily-summary-email';

-- 3. Check system_settings configuration
SELECT 
  'System Settings' as check_type,
  key,
  CASE 
    WHEN value IS NULL OR value = '' OR value = 'YOUR_PROJECT_REF' OR value = 'YOUR_SERVICE_ROLE_KEY'
    THEN '❌ NOT CONFIGURED'
    ELSE '✅ CONFIGURED'
  END as status,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN '***HIDDEN***'
    ELSE LEFT(value, 20) || '...'
  END as value_preview
FROM system_settings
WHERE key IN ('supabase_project_ref', 'supabase_service_role_key');

-- 4. View recent execution history (last 10 runs)
SELECT 
  'Execution History' as check_type,
  job_run_details.jobid,
  job_run_details.start_time,
  job_run_details.end_time,
  job_run_details.job_pid,
  job_run_details.database,
  job_run_details.status,
  job_run_details.return_message,
  CASE 
    WHEN job_run_details.status = 'succeeded' THEN '✅ SUCCESS'
    WHEN job_run_details.status = 'failed' THEN '❌ FAILED'
    ELSE '⚠️ ' || job_run_details.status
  END as status_display
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'daily-summary-email' LIMIT 1)
ORDER BY start_time DESC
LIMIT 10;

-- 5. Test the helper functions
SELECT 
  'Function Test' as check_type,
  get_supabase_project_ref() as project_ref,
  CASE 
    WHEN get_supabase_project_ref() = 'YOUR_PROJECT_REF' OR get_supabase_project_ref() IS NULL
    THEN '❌ NOT CONFIGURED'
    ELSE '✅ CONFIGURED: ' || LEFT(get_supabase_project_ref(), 10) || '...'
  END as project_ref_status,
  CASE 
    WHEN get_service_role_key() = 'YOUR_SERVICE_ROLE_KEY' OR get_service_role_key() IS NULL
    THEN '❌ NOT CONFIGURED'
    ELSE '✅ CONFIGURED'
  END as service_key_status;

-- 6. Manual test (uncomment to test the function immediately)
-- WARNING: This will send an email if everything is configured correctly
-- SELECT call_daily_summary_email();

-- =====================================================================================
-- FIX COMMANDS (if needed)
-- =====================================================================================

-- If supabase_project_ref is not configured, run:
-- INSERT INTO system_settings (key, value, value_type, description)
-- VALUES ('supabase_project_ref', 'YOUR_PROJECT_REF_HERE', 'string', 'Supabase project reference for Edge Function URLs')
-- ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- If supabase_service_role_key is not configured, run:
-- INSERT INTO system_settings (key, value, value_type, description, is_public)
-- VALUES ('supabase_service_role_key', 'YOUR_SERVICE_ROLE_KEY_HERE', 'string', 'Supabase service role key for Edge Function authentication', false)
-- ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- If cron job is inactive, try to reschedule:
-- SELECT cron.unschedule('daily-summary-email');
-- SELECT cron.schedule(
--   'daily-summary-email',
--   '0 18 * * *',  -- Every day at 18:00 UTC (9PM GMT+3)
--   $$SELECT call_daily_summary_email();$$
-- );

