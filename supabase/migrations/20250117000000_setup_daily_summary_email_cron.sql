-- =====================================================================================
-- SETUP DAILY SUMMARY EMAIL CRON JOB
-- =====================================================================================
-- This migration sets up a cron job to send daily summary emails at 9PM GMT+3 (6PM UTC)
-- The email includes:
-- - Number of merchant accounts created in the past day
-- - Number of driver accounts created in the past day
-- - Number of wallet topups in the past day
-- - Number of orders delivered in the past day
-- =====================================================================================

-- Step 1: Ensure pg_cron extension is enabled
-- Handle gracefully if already exists or has permission issues
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
  ELSE
    RAISE NOTICE 'pg_cron extension already exists';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Could not create pg_cron extension: %', SQLERRM;
    RAISE WARNING 'pg_cron may already be installed. Continuing...';
END $$;

-- Step 2: Ensure pg_net extension is enabled (for HTTP requests to Edge Functions)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    CREATE EXTENSION IF NOT EXISTS pg_net;
  ELSE
    RAISE NOTICE 'pg_net extension already exists';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Could not create pg_net extension: %', SQLERRM;
    RAISE WARNING 'pg_net may already be installed. Continuing...';
END $$;

-- Step 3: Create a helper function to get the Supabase project reference
-- This extracts the project ref from the current database connection
CREATE OR REPLACE FUNCTION get_supabase_project_ref()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_ref TEXT;
BEGIN
  -- Try to get from database name (common pattern)
  -- Supabase project databases often have the project ref in their name
  SELECT current_database() INTO v_project_ref;
  
  -- If database name doesn't look like a project ref, try to extract from connection string
  -- For now, we'll use a placeholder that needs to be updated manually
  -- The actual project ref should be set via a config setting
  
  -- Check if we have a stored project ref in system_settings
  SELECT value INTO v_project_ref
  FROM system_settings
  WHERE key = 'supabase_project_ref'
  LIMIT 1;
  
  -- If still not found, try to construct from current_setting
  IF v_project_ref IS NULL OR v_project_ref = '' THEN
    v_project_ref := COALESCE(
      current_setting('app.settings.project_ref', true),
      'YOUR_PROJECT_REF'  -- Placeholder - will need manual update
    );
  END IF;
  
  RETURN v_project_ref;
END;
$$;

-- Step 4: Create a helper function to get the service role key
CREATE OR REPLACE FUNCTION get_service_role_key()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_service_key TEXT;
BEGIN
  -- Try to get from system_settings first
  SELECT value INTO v_service_key
  FROM system_settings
  WHERE key = 'supabase_service_role_key'
  LIMIT 1;
  
  -- If not found, try current_setting
  IF v_service_key IS NULL OR v_service_key = '' THEN
    v_service_key := COALESCE(
      current_setting('app.settings.service_role_key', true),
      'YOUR_SERVICE_ROLE_KEY'  -- Placeholder - will need manual update
    );
  END IF;
  
  RETURN v_service_key;
END;
$$;

-- Step 5: Create a function to call the daily summary email Edge Function
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
BEGIN
  -- Get project reference and service role key
  v_project_ref := get_supabase_project_ref();
  v_service_key := get_service_role_key();
  
  -- Check if placeholders are still present
  IF v_project_ref = 'YOUR_PROJECT_REF' OR v_service_key = 'YOUR_SERVICE_ROLE_KEY' THEN
    RAISE WARNING 'Daily summary email cron job not configured properly. Please set supabase_project_ref and supabase_service_role_key in system_settings table.';
    RETURN;
  END IF;
  
  -- Construct function URL
  v_function_url := format('https://%s.supabase.co/functions/v1/daily-summary-email', v_project_ref);
  
  -- Call the Edge Function via HTTP POST
  SELECT net.http_post(
    url := v_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', format('Bearer %s', v_service_key)
    ),
    body := '{}'::jsonb
  ) INTO v_request_id;
  
  RAISE NOTICE 'Daily summary email request sent. Request ID: %', v_request_id;
END;
$$;

-- Step 6: Remove any existing cron job with this name (if it exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-summary-email') THEN
    PERFORM cron.unschedule('daily-summary-email');
    RAISE NOTICE 'Removed existing daily-summary-email cron job';
  END IF;
END $$;

-- Step 7: Schedule the cron job to run at 9PM GMT+3 (6PM UTC = 18:00 UTC)
-- Cron format: minute hour day month weekday
-- 18:00 UTC = 9PM GMT+3 (Iraq timezone)
SELECT cron.schedule(
  'daily-summary-email',
  '0 18 * * *',  -- Every day at 18:00 UTC (9PM GMT+3)
  $$SELECT call_daily_summary_email();$$
);

-- Step 8: Grant necessary permissions
GRANT EXECUTE ON FUNCTION call_daily_summary_email() TO postgres;
GRANT EXECUTE ON FUNCTION get_supabase_project_ref() TO postgres;
GRANT EXECUTE ON FUNCTION get_service_role_key() TO postgres;

-- Step 9: Verify the job is scheduled
DO $$
DECLARE
  v_job_count INTEGER;
  v_jobs TEXT;
BEGIN
  SELECT COUNT(*) INTO v_job_count
  FROM cron.job
  WHERE jobname = 'daily-summary-email';
  
  IF v_job_count > 0 THEN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DAILY SUMMARY EMAIL CRON JOB SETUP';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Cron job scheduled successfully!';
    RAISE NOTICE '';
    RAISE NOTICE 'Schedule: Every day at 18:00 UTC (9PM GMT+3)';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT: Configure the following settings:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Set Supabase project reference:';
    RAISE NOTICE '   INSERT INTO system_settings (key, value, value_type, description)';
    RAISE NOTICE '   VALUES (''supabase_project_ref'', ''YOUR_PROJECT_REF'', ''string'', ''Supabase project reference for Edge Function URLs'')';
    RAISE NOTICE '   ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;';
    RAISE NOTICE '';
    RAISE NOTICE '2. Set service role key:';
    RAISE NOTICE '   INSERT INTO system_settings (key, value, value_type, description, is_public)';
    RAISE NOTICE '   VALUES (''supabase_service_role_key'', ''YOUR_SERVICE_ROLE_KEY'', ''string'', ''Supabase service role key for Edge Function authentication'', false)';
    RAISE NOTICE '   ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;';
    RAISE NOTICE '';
    RAISE NOTICE '3. Set Edge Function secrets:';
    RAISE NOTICE '   supabase secrets set RESEND_API_KEY=your_resend_api_key';
    RAISE NOTICE '   supabase secrets set ADMIN_EMAIL=admin@example.com';
    RAISE NOTICE '   supabase secrets set RESEND_FROM_EMAIL="Hur Delivery <noreply@hur.delivery>"';
    RAISE NOTICE '';
    RAISE NOTICE 'View scheduled job:';
    RAISE NOTICE '  SELECT * FROM cron.job WHERE jobname = ''daily-summary-email'';';
    RAISE NOTICE '';
    RAISE NOTICE 'View execution history:';
    RAISE NOTICE '  SELECT * FROM cron.job_run_details';
    RAISE NOTICE '  WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = ''daily-summary-email'')';
    RAISE NOTICE '  ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '========================================';
  ELSE
    RAISE WARNING '❌ Failed to schedule daily-summary-email cron job';
  END IF;
END $$;

-- Add comments
COMMENT ON FUNCTION call_daily_summary_email() IS 
  'Calls the daily-summary-email Edge Function to send daily statistics email to admin.
   Scheduled to run every day at 9PM GMT+3 (6PM UTC) via pg_cron.';

COMMENT ON FUNCTION get_supabase_project_ref() IS 
  'Gets the Supabase project reference from system_settings table or environment.';

COMMENT ON FUNCTION get_service_role_key() IS 
  'Gets the Supabase service role key from system_settings table or environment.
   This key is used to authenticate Edge Function calls.';

