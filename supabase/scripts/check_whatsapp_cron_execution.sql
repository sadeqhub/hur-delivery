-- =====================================================================================
-- CHECK WHATSAPP CRON EXECUTION DETAILS
-- =====================================================================================
-- This shows what the cron job is actually returning
-- =====================================================================================

-- 1. Check recent execution results
SELECT 
  start_time,
  end_time,
  status,
  return_message,
  EXTRACT(EPOCH FROM (end_time - start_time)) * 1000 as duration_ms
FROM cron.job_run_details
WHERE jobid IN (SELECT jobid FROM cron.job WHERE jobname = 'process-whatsapp-queue')
ORDER BY start_time DESC
LIMIT 10;

-- 2. Test the function manually to see what it returns
SELECT * FROM trigger_whatsapp_queue_processor();

-- 3. Check if there are pending messages
SELECT 
  status,
  COUNT(*) as count
FROM whatsapp_announcement_queue
GROUP BY status;

-- 4. Check edge function logs (you need to check in Supabase Dashboard)
-- Go to: Edge Functions > process-whatsapp-queue > Logs
-- Look for recent invocations in the last few minutes
-- If you see logs, the edge function IS being triggered!

-- 5. Summary: What to check
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICATION STEPS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '1. Check the function result above - look for:';
  RAISE NOTICE '   - success: should be TRUE if HTTP request worked';
  RAISE NOTICE '   - message: should say "Successfully triggered..."';
  RAISE NOTICE '   - request_id: should have a number if successful';
  RAISE NOTICE '';
  RAISE NOTICE '2. Check Edge Function Logs:';
  RAISE NOTICE '   Supabase Dashboard > Edge Functions > process-whatsapp-queue > Logs';
  RAISE NOTICE '   Look for recent invocations (should see logs every minute)';
  RAISE NOTICE '';
  RAISE NOTICE '3. If success=FALSE, check the message for error details';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

