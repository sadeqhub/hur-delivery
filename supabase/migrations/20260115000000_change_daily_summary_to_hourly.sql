-- =====================================================================================
-- CHANGE DAILY SUMMARY TO HOURLY SUMMARY
-- =====================================================================================
-- This migration changes the daily summary cron job to run every hour instead of daily
-- The summary will now show statistics for the past hour
-- =====================================================================================

-- Step 1: Remove existing daily summary cron job
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-summary-email') THEN
    BEGIN
      PERFORM cron.unschedule('daily-summary-email');
      RAISE NOTICE 'Removed existing daily-summary-email cron job';
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Could not unschedule existing job: %', SQLERRM;
    END;
  END IF;
END $$;

-- Step 2: Reschedule the cron job to run every hour
-- Cron format: minute hour day month weekday
-- '0 * * * *' means "at minute 0 of every hour"
DO $$
DECLARE
  v_cron_available BOOLEAN;
  v_job_id BIGINT;
BEGIN
  -- Check if pg_cron is available
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) INTO v_cron_available;
  
  IF NOT v_cron_available THEN
    RAISE WARNING 'Cannot schedule cron job: pg_cron extension is not available';
    RAISE WARNING 'Please enable pg_cron in Supabase Dashboard > Database > Extensions';
    RETURN;
  END IF;
  
  -- Schedule the job to run every hour
  BEGIN
    SELECT cron.schedule(
      'daily-summary-email',
      '0 * * * *',  -- Every hour at minute 0
      $cmd$SELECT call_daily_summary_email();$cmd$
    ) INTO v_job_id;
    
    RAISE NOTICE '✅ Successfully scheduled hourly summary cron job';
    RAISE NOTICE '   Job ID: %', v_job_id;
    RAISE NOTICE '   Schedule: Every hour at minute 0';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Failed to schedule cron job: %', SQLERRM;
      RAISE WARNING 'Error details: %', SQLSTATE;
  END;
END $$;

-- Step 3: Update function comment
COMMENT ON FUNCTION call_daily_summary_email() IS 
  'Calls the daily-summary-email Edge Function to send hourly statistics WhatsApp message to admin.
   Scheduled to run every hour at minute 0 via pg_cron.
   Requires: supabase_project_ref and supabase_service_role_key in system_settings table.
   Also requires: ADMIN_PHONE environment variable in Edge Function secrets.';

