-- =====================================================================================
-- FIX WHATSAPP QUEUE CRON JOB
-- =====================================================================================
-- Run this to fix common issues with the WhatsApp queue cron job
-- =====================================================================================

-- Step 1: Check current status
SELECT 
  'Current Status' as step,
  CASE 
    WHEN EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-whatsapp-queue' AND active = true)
    THEN '✅ Cron job is active'
    ELSE '❌ Cron job is NOT active'
  END as status;

-- Step 2: Check service role key
DO $$
DECLARE
  v_key TEXT;
BEGIN
  -- Check system_settings table first
  SELECT value INTO v_key
  FROM system_settings
  WHERE key = 'supabase_service_role_key'
  LIMIT 1;
  
  IF v_key IS NULL OR v_key = '' OR v_key = 'YOUR_SERVICE_ROLE_KEY_HERE' THEN
    RAISE NOTICE '❌ Service role key is NOT configured in system_settings';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  ACTION REQUIRED:';
    RAISE NOTICE '   1. Go to Supabase Dashboard > Settings > API';
    RAISE NOTICE '   2. Copy your "service_role" key (secret)';
    RAISE NOTICE '   3. Run the script: supabase/scripts/set_service_role_key.sql';
    RAISE NOTICE '      Or run this SQL (replace YOUR_KEY with the actual key):';
    RAISE NOTICE '';
    RAISE NOTICE '   INSERT INTO system_settings (key, value, value_type, description, updated_at)';
    RAISE NOTICE '   VALUES (''supabase_service_role_key'', ''YOUR_KEY'', ''string'', ''Service role key'', NOW())';
    RAISE NOTICE '   ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();';
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE '✅ Service role key is configured in system_settings (length: %)', LENGTH(v_key);
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '❌ Could not check service role key: %', SQLERRM;
END $$;

-- Step 3: Reschedule the cron job (in case it's not running)
DO $$
BEGIN
  -- Remove existing job
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-whatsapp-queue') THEN
    PERFORM cron.unschedule('process-whatsapp-queue');
    RAISE NOTICE 'Removed existing cron job';
  END IF;
  
  -- Schedule new job
  PERFORM cron.schedule(
    'process-whatsapp-queue',
    '* * * * *',
    'SELECT * FROM trigger_whatsapp_queue_processor();'
  );
  
  RAISE NOTICE '✅ Cron job rescheduled';
END $$;

-- Step 4: Verify the cron job is now active
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  CASE WHEN active THEN '✅ ACTIVE' ELSE '❌ INACTIVE' END as status
FROM cron.job
WHERE jobname = 'process-whatsapp-queue';

-- Step 5: Test the function manually
SELECT 
  'Manual Test' as step,
  success,
  message,
  pending_count,
  request_id
FROM trigger_whatsapp_queue_processor();

-- Step 6: Check queue status
SELECT 
  'Queue Status' as step,
  status,
  COUNT(*) as count
FROM whatsapp_announcement_queue
GROUP BY status
ORDER BY status;

-- Step 7: Instructions
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'NEXT STEPS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '1. If service role key is not configured, set it using the command above';
  RAISE NOTICE '2. Wait 1-2 minutes and check execution history:';
  RAISE NOTICE '   SELECT * FROM cron.job_run_details';
  RAISE NOTICE '   WHERE jobid IN (SELECT jobid FROM cron.job WHERE jobname = ''process-whatsapp-queue'')';
  RAISE NOTICE '   ORDER BY start_time DESC LIMIT 5;';
  RAISE NOTICE '';
  RAISE NOTICE '3. Check edge function logs in Supabase Dashboard > Edge Functions > process-whatsapp-queue';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

