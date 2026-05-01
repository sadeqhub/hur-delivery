-- =====================================================================================
-- FIX HOURLY SUMMARY CRON JOB
-- =====================================================================================
-- This script manually reschedules the daily-summary-email cron job to run hourly
-- Run this in Supabase SQL Editor if the migration didn't work or cron job isn't running
-- =====================================================================================

-- Step 1: Check current status
DO $$
DECLARE
  v_job_exists BOOLEAN;
  v_job_id BIGINT;
  v_schedule TEXT;
  v_active BOOLEAN;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CHECKING CURRENT CRON JOB STATUS';
  RAISE NOTICE '========================================';
  
  SELECT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'daily-summary-email'
  ) INTO v_job_exists;
  
  IF v_job_exists THEN
    SELECT jobid, schedule, active INTO v_job_id, v_schedule, v_active
    FROM cron.job
    WHERE jobname = 'daily-summary-email'
    LIMIT 1;
    
    RAISE NOTICE 'Current Job ID: %', v_job_id;
    RAISE NOTICE 'Current Schedule: %', v_schedule;
    RAISE NOTICE 'Active: %', CASE WHEN v_active THEN 'YES' ELSE 'NO' END;
  ELSE
    RAISE NOTICE 'Cron job does not exist';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

-- Step 2: Remove existing job
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-summary-email') THEN
    BEGIN
      PERFORM cron.unschedule('daily-summary-email');
      RAISE NOTICE '✅ Removed existing cron job';
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Could not unschedule: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'No existing job to remove';
  END IF;
END $$;

-- Step 3: Schedule the job to run every hour
-- Cron format: minute hour day month weekday
-- '0 * * * *' means "at minute 0 of every hour"
DO $$
DECLARE
  v_job_id BIGINT;
BEGIN
  BEGIN
    SELECT cron.schedule(
      'daily-summary-email',
      '0 * * * *',  -- Every hour at minute 0
      $cmd$SELECT call_daily_summary_email();$cmd$
    ) INTO v_job_id;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SUCCESSFULLY SCHEDULED HOURLY CRON JOB';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Job ID: %', v_job_id;
    RAISE NOTICE 'Schedule: 0 * * * * (Every hour at minute 0)';
    RAISE NOTICE 'Job Name: daily-summary-email';
    RAISE NOTICE '========================================';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING '❌ Failed to schedule cron job: %', SQLERRM;
      RAISE WARNING 'Error details: SQLSTATE = %', SQLSTATE;
  END;
END $$;

-- Step 4: Verify the job was scheduled
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  command,
  CASE 
    WHEN active THEN '✅ ACTIVE' 
    ELSE '❌ INACTIVE' 
  END as status
FROM cron.job
WHERE jobname = 'daily-summary-email';

-- Step 5: View execution history (last 5 runs)
SELECT 
  jobid,
  start_time,
  end_time,
  status,
  return_message,
  CASE 
    WHEN status = 'succeeded' THEN '✅ SUCCESS'
    WHEN status = 'failed' THEN '❌ FAILED'
    ELSE '⚠️ ' || status
  END as status_display
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'daily-summary-email' LIMIT 1)
ORDER BY start_time DESC
LIMIT 5;

