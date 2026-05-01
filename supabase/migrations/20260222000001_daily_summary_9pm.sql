-- =====================================================================================
-- CHANGE DAILY SUMMARY TO RUN ONCE AT 9 PM BAGHDAD TIME
-- =====================================================================================
-- Runs daily at 9 PM Iraq time (18:00 UTC = 6 PM UTC, Iraq is UTC+3)
-- =====================================================================================

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

-- Schedule to run once daily at 9 PM Baghdad (18:00 UTC)
-- Cron format: minute hour day month weekday
DO $$
DECLARE
  v_cron_available BOOLEAN;
  v_job_id BIGINT;
BEGIN
  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') INTO v_cron_available;

  IF NOT v_cron_available THEN
    RAISE WARNING 'pg_cron extension is not available';
    RETURN;
  END IF;

  BEGIN
    SELECT cron.schedule(
      'daily-summary-email',
      '0 18 * * *',  -- 18:00 UTC = 9 PM Baghdad (Asia/Baghdad UTC+3)
      $cmd$SELECT call_daily_summary_email();$cmd$
    ) INTO v_job_id;

    RAISE NOTICE '✅ Daily summary scheduled for 9 PM Baghdad time';
    RAISE NOTICE '   Job ID: %, Schedule: 0 18 * * * (18:00 UTC)', v_job_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Failed to schedule: %', SQLERRM;
  END;
END $$;

COMMENT ON FUNCTION call_daily_summary_email() IS
  'Calls the daily-summary-email Edge Function to send daily statistics WhatsApp message to admin.
   Scheduled to run once daily at 9 PM Baghdad time (18:00 UTC) via pg_cron.';
