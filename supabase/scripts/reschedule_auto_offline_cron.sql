-- =====================================================================================
-- RESCHEDULE AUTO-OFFLINE DRIVERS CRON JOB
-- =====================================================================================
-- Use this script to manually reschedule the auto-offline drivers cron job
-- Run this if the cron job is not running automatically
-- =====================================================================================

-- Step 1: Check if pg_cron is enabled
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE EXCEPTION 'pg_cron extension is not enabled. Please enable it first: Supabase Dashboard > Database > Extensions > Enable pg_cron';
  END IF;
  RAISE NOTICE '✅ pg_cron extension is enabled';
END $$;

-- Step 2: Remove existing job if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'auto-offline-drivers-by-location') THEN
    PERFORM cron.unschedule('auto-offline-drivers-by-location');
    RAISE NOTICE 'Removed existing auto-offline-drivers-by-location cron job';
  END IF;
END $$;

-- Step 3: Schedule the job (using SELECT to ensure it executes)
-- Using the wrapper function that returns void (better for cron)
SELECT cron.schedule(
  'auto-offline-drivers-by-location',
  '*/2 * * * *',  -- Every 2 minutes
  'SELECT call_mark_drivers_offline_by_location();'
) as job_id;

-- Step 4: Verify the job was created and is active
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  CASE 
    WHEN active THEN '✅ ACTIVE - Job will run automatically' 
    ELSE '❌ INACTIVE - Job exists but is not active' 
  END as status,
  command
FROM cron.job
WHERE jobname = 'auto-offline-drivers-by-location';

-- Step 5: Show instructions
DO $$
DECLARE
  v_job_active BOOLEAN;
BEGIN
  SELECT active INTO v_job_active
  FROM cron.job
  WHERE jobname = 'auto-offline-drivers-by-location'
  LIMIT 1;
  
  IF v_job_active THEN
    RAISE NOTICE '';
    RAISE NOTICE '✅ SUCCESS! The cron job is scheduled and active.';
    RAISE NOTICE '   It will run every 2 minutes automatically.';
    RAISE NOTICE '';
    RAISE NOTICE 'To test the function manually:';
    RAISE NOTICE '   SELECT call_mark_drivers_offline_by_location();';
    RAISE NOTICE '   -- OR to see results:';
    RAISE NOTICE '   SELECT * FROM mark_drivers_offline_by_location();';
    RAISE NOTICE '';
    RAISE NOTICE 'To view execution history:';
    RAISE NOTICE '   SELECT * FROM cron.job_run_details';
    RAISE NOTICE '   WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = ''auto-offline-drivers-by-location'')';
    RAISE NOTICE '   ORDER BY start_time DESC LIMIT 10;';
  ELSE
    RAISE WARNING '';
    RAISE WARNING '⚠️  WARNING: Job is scheduled but INACTIVE';
    RAISE WARNING '   You may need to check Supabase cron job permissions';
    RAISE WARNING '   or contact Supabase support if this persists.';
  END IF;
END $$;

