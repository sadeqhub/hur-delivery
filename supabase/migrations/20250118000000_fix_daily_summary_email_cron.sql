-- =====================================================================================
-- FIX DAILY SUMMARY EMAIL CRON JOB
-- =====================================================================================
-- This migration diagnoses and fixes issues with the daily summary email cron job
-- It checks:
-- 1. If pg_cron extension is enabled
-- 2. If the cron job exists and is active
-- 3. If system_settings are properly configured
-- 4. Reschedules the job if needed
-- =====================================================================================

-- Step 1: Diagnostic - Check current status
DO $$
DECLARE
  v_cron_enabled BOOLEAN;
  v_pg_net_enabled BOOLEAN;
  v_job_exists BOOLEAN;
  v_job_active BOOLEAN;
  v_project_ref TEXT;
  v_service_key TEXT;
  v_job_id BIGINT;
  v_schedule TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DAILY SUMMARY EMAIL CRON - DIAGNOSTIC';
  RAISE NOTICE '========================================';
  
  -- Check pg_cron extension
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) INTO v_cron_enabled;
  
  IF NOT v_cron_enabled THEN
    RAISE WARNING '❌ pg_cron extension is NOT enabled';
    RAISE WARNING '   Go to Supabase Dashboard > Database > Extensions > Enable pg_cron';
  ELSE
    RAISE NOTICE '✅ pg_cron extension is enabled';
  END IF;
  
  -- Check pg_net extension
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
  ) INTO v_pg_net_enabled;
  
  IF NOT v_pg_net_enabled THEN
    RAISE WARNING '❌ pg_net extension is NOT enabled';
    RAISE WARNING '   This is required for HTTP requests to Edge Functions';
  ELSE
    RAISE NOTICE '✅ pg_net extension is enabled';
  END IF;
  
  -- Check if job exists
  SELECT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'daily-summary-email'
  ) INTO v_job_exists;
  
  IF v_job_exists THEN
    SELECT jobid, active, schedule INTO v_job_id, v_job_active, v_schedule
    FROM cron.job
    WHERE jobname = 'daily-summary-email'
    LIMIT 1;
    
    IF v_job_active THEN
      RAISE NOTICE '✅ Cron job exists and is ACTIVE';
      RAISE NOTICE '   Job ID: %', v_job_id;
      RAISE NOTICE '   Schedule: %', v_schedule;
    ELSE
      RAISE WARNING '⚠️  Cron job exists but is INACTIVE';
      RAISE WARNING '   Job ID: %', v_job_id;
    END IF;
  ELSE
    RAISE WARNING '❌ Cron job does NOT exist';
  END IF;
  
  -- Check system_settings configuration
  SELECT value INTO v_project_ref
  FROM system_settings
  WHERE key = 'supabase_project_ref'
  LIMIT 1;
  
  IF v_project_ref IS NULL OR v_project_ref = '' OR v_project_ref = 'YOUR_PROJECT_REF' THEN
    RAISE WARNING '❌ supabase_project_ref is NOT configured in system_settings';
    RAISE WARNING '   Run: INSERT INTO system_settings (key, value, value_type, description)';
    RAISE WARNING '        VALUES (''supabase_project_ref'', ''YOUR_PROJECT_REF'', ''string'', ''Supabase project reference'')';
    RAISE WARNING '        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;';
  ELSE
    RAISE NOTICE '✅ supabase_project_ref is configured: %', LEFT(v_project_ref, 10) || '...';
  END IF;
  
  SELECT value INTO v_service_key
  FROM system_settings
  WHERE key = 'supabase_service_role_key'
  LIMIT 1;
  
  IF v_service_key IS NULL OR v_service_key = '' OR v_service_key = 'YOUR_SERVICE_ROLE_KEY' THEN
    RAISE WARNING '❌ supabase_service_role_key is NOT configured in system_settings';
    RAISE WARNING '   Run: INSERT INTO system_settings (key, value, value_type, description, is_public)';
    RAISE WARNING '        VALUES (''supabase_service_role_key'', ''YOUR_SERVICE_ROLE_KEY'', ''string'', ''Service role key'', false)';
    RAISE WARNING '        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;';
  ELSE
    RAISE NOTICE '✅ supabase_service_role_key is configured';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

-- Step 2: Ensure extensions are enabled
DO $$
BEGIN
  -- Try to enable pg_cron
  BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
    RAISE NOTICE 'pg_cron extension check complete';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Could not enable pg_cron: %', SQLERRM;
      RAISE WARNING 'You may need to enable it manually in Supabase Dashboard';
  END;
  
  -- Try to enable pg_net
  BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net;
    RAISE NOTICE 'pg_net extension check complete';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Could not enable pg_net: %', SQLERRM;
      RAISE WARNING 'You may need to enable it manually in Supabase Dashboard';
  END;
END $$;

-- Step 3: Remove existing job if it exists (to reschedule with correct settings)
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

-- Step 4: Reschedule the cron job
-- Schedule: 9PM GMT+3 = 6PM UTC (18:00 UTC)
-- Cron format: minute hour day month weekday
-- Note: GMT+3 is 3 hours ahead of UTC, so 9PM GMT+3 = 6PM UTC
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
  
  -- Schedule the job
  BEGIN
    SELECT cron.schedule(
      'daily-summary-email',
      '0 18 * * *',  -- Every day at 18:00 UTC (9PM GMT+3)
      $cmd$SELECT call_daily_summary_email();$cmd$
    ) INTO v_job_id;
    
    RAISE NOTICE '✅ Successfully scheduled daily-summary-email cron job';
    RAISE NOTICE '   Job ID: %', v_job_id;
    RAISE NOTICE '   Schedule: Every day at 18:00 UTC (9PM GMT+3)';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Failed to schedule cron job: %', SQLERRM;
      RAISE WARNING 'Error details: %', SQLSTATE;
  END;
END $$;

-- Step 5: Verify the job is scheduled and active
DO $$
DECLARE
  v_job_count INTEGER;
  v_job_id BIGINT;
  v_job_active BOOLEAN;
  v_schedule TEXT;
  v_command TEXT;
BEGIN
  SELECT COUNT(*) INTO v_job_count
  FROM cron.job
  WHERE jobname = 'daily-summary-email';
  
  IF v_job_count > 0 THEN
    SELECT jobid, active, schedule, command
    INTO v_job_id, v_job_active, v_schedule, v_command
    FROM cron.job
    WHERE jobname = 'daily-summary-email'
    LIMIT 1;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CRON JOB VERIFICATION';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Job Name: daily-summary-email';
    RAISE NOTICE 'Job ID: %', v_job_id;
    RAISE NOTICE 'Active: %', CASE WHEN v_job_active THEN 'YES ✅' ELSE 'NO ❌' END;
    RAISE NOTICE 'Schedule: %', v_schedule;
    RAISE NOTICE 'Command: %', LEFT(v_command, 50) || '...';
    RAISE NOTICE '';
    
    IF NOT v_job_active THEN
      RAISE WARNING '⚠️  WARNING: Job is scheduled but INACTIVE';
      RAISE WARNING '   You may need to activate it manually or check permissions';
    END IF;
    
    RAISE NOTICE 'To view execution history, run:';
    RAISE NOTICE '  SELECT * FROM cron.job_run_details';
    RAISE NOTICE '  WHERE jobid = %', v_job_id;
    RAISE NOTICE '  ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '========================================';
  ELSE
    RAISE WARNING '❌ Cron job was not scheduled successfully';
    RAISE WARNING '   Please check the errors above and ensure:';
    RAISE WARNING '   1. pg_cron extension is enabled';
    RAISE WARNING '   2. You have proper permissions';
    RAISE WARNING '   3. system_settings are configured';
  END IF;
END $$;

-- Step 6: Improve the call_daily_summary_email function with better error handling
CREATE OR REPLACE FUNCTION call_daily_summary_email()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_ref TEXT;
  v_service_key TEXT;
  v_function_url TEXT;
  v_request_id BIGINT;
  v_error_message TEXT;
BEGIN
  -- Log start
  RAISE NOTICE '[%] Starting daily summary email function', NOW();
  
  -- Get project reference and service role key
  BEGIN
    v_project_ref := get_supabase_project_ref();
    v_service_key := get_service_role_key();
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING '[%] Error getting configuration: %', NOW(), SQLERRM;
      RETURN;
  END;
  
  -- Check if placeholders are still present
  IF v_project_ref IS NULL OR v_project_ref = '' OR v_project_ref = 'YOUR_PROJECT_REF' THEN
    RAISE WARNING '[%] Daily summary email cron job not configured: supabase_project_ref is missing or invalid', NOW();
    RETURN;
  END IF;
  
  IF v_service_key IS NULL OR v_service_key = '' OR v_service_key = 'YOUR_SERVICE_ROLE_KEY' THEN
    RAISE WARNING '[%] Daily summary email cron job not configured: supabase_service_role_key is missing or invalid', NOW();
    RETURN;
  END IF;
  
  -- Construct function URL
  v_function_url := format('https://%s.supabase.co/functions/v1/daily-summary-email', v_project_ref);
  
  RAISE NOTICE '[%] Calling Edge Function: %', NOW(), v_function_url;
  
  -- Call the Edge Function via HTTP POST
  BEGIN
    SELECT net.http_post(
      url := v_function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', format('Bearer %s', v_service_key)
      ),
      body := '{}'::jsonb
    ) INTO v_request_id;
    
    RAISE NOTICE '[%] Daily summary email request sent successfully. Request ID: %', NOW(), v_request_id;
  EXCEPTION
    WHEN OTHERS THEN
      v_error_message := SQLERRM;
      RAISE WARNING '[%] Failed to send daily summary email request: %', NOW(), v_error_message;
      RAISE WARNING '[%] Error details: SQLSTATE = %', NOW(), SQLSTATE;
      -- Don't re-raise - allow cron job to continue
  END;
END;
$$;

-- Step 7: Test the function (optional - can be commented out)
-- Uncomment the line below to test the function immediately
-- SELECT call_daily_summary_email();

COMMENT ON FUNCTION call_daily_summary_email() IS 
  'Calls the daily-summary-email Edge Function to send daily statistics email to admin.
   Scheduled to run every day at 9PM GMT+3 (6PM UTC) via pg_cron.
   Requires: supabase_project_ref and supabase_service_role_key in system_settings table.
   Improved error handling and logging for better diagnostics.';

