-- =====================================================================================
-- SETUP CRON JOB FOR WHATSAPP QUEUE PROCESSING
-- =====================================================================================
-- This migration sets up a cron job to automatically process the WhatsApp queue
-- every minute, ensuring messages are sent without relying on the frontend
-- =====================================================================================

-- Step 1: Check if pg_cron extension is available
DO $$
DECLARE
  v_cron_available BOOLEAN;
  v_net_available BOOLEAN;
BEGIN
  -- Check if pg_cron extension exists
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) INTO v_cron_available;
  
  -- Check if pg_net extension exists (for HTTP calls)
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
  ) INTO v_net_available;
  
  IF NOT v_cron_available THEN
    RAISE WARNING 'pg_cron extension is not available. WhatsApp queue cron will not be scheduled.';
    RAISE WARNING 'To enable pg_cron: Go to Supabase Dashboard > Database > Extensions > Enable pg_cron';
    RETURN;
  END IF;
  
  IF NOT v_net_available THEN
    RAISE WARNING 'pg_net extension is not available. Attempting to enable it...';
    BEGIN
      CREATE EXTENSION IF NOT EXISTS pg_net;
      RAISE NOTICE '✅ pg_net extension enabled';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Could not enable pg_net: %', SQLERRM;
      RAISE WARNING 'WhatsApp queue cron will not work without pg_net.';
      RETURN;
    END;
  END IF;
  
  RAISE NOTICE '✅ pg_cron and pg_net extensions are available';
END $$;

-- Step 2: Drop existing function if it exists (to allow changing return type)
DROP FUNCTION IF EXISTS trigger_whatsapp_queue_processor();

-- Step 3: Create a function to trigger the queue processor edge function
-- This function checks for pending messages and triggers the edge function via HTTP
CREATE OR REPLACE FUNCTION trigger_whatsapp_queue_processor()
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  pending_count INTEGER,
  request_id BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_ref TEXT;
  v_service_role_key TEXT;
  v_function_url TEXT;
  v_pending_count INTEGER;
  v_processing_stuck_count INTEGER;
  v_request_id BIGINT;
BEGIN
  -- Reset messages stuck in 'processing' status (older than 5 minutes) back to 'pending'
  -- This handles cases where the edge function timed out or crashed
  UPDATE whatsapp_announcement_queue
  SET status = 'pending'
  WHERE status = 'processing'
    AND (last_attempt_at IS NULL OR last_attempt_at < NOW() - INTERVAL '5 minutes');
  
  GET DIAGNOSTICS v_processing_stuck_count = ROW_COUNT;
  
  -- Check if there are any pending messages in the queue
  SELECT COUNT(*) INTO v_pending_count
  FROM whatsapp_announcement_queue
  WHERE status = 'pending';
  
  -- Only trigger if there are pending messages
  IF v_pending_count = 0 THEN
    IF v_processing_stuck_count > 0 THEN
      RETURN QUERY SELECT 
        TRUE, 
        format('Reset %s stuck processing messages back to pending, but queue is now empty', v_processing_stuck_count)::TEXT,
        0::INTEGER, 
        NULL::BIGINT;
    ELSE
      RETURN QUERY SELECT FALSE, 'No pending messages in queue', 0::INTEGER, NULL::BIGINT;
    END IF;
    RETURN;
  END IF;
  
  -- Log if we reset any stuck messages
  IF v_processing_stuck_count > 0 THEN
    RAISE NOTICE 'Reset % stuck processing messages back to pending', v_processing_stuck_count;
  END IF;
  
  -- Get project reference
  -- Try from system_settings first (if it exists)
  BEGIN
    SELECT value INTO v_project_ref
    FROM system_settings
    WHERE key = 'supabase_project_ref'
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    -- Table might not exist, continue
    NULL;
  END;
  
  -- If not found, try current_setting
  IF v_project_ref IS NULL OR v_project_ref = '' THEN
    BEGIN
      v_project_ref := current_setting('app.settings.project_ref', true);
    EXCEPTION WHEN OTHERS THEN
      v_project_ref := NULL;
    END;
  END IF;
  
  -- If still not found, use placeholder (needs manual update)
  IF v_project_ref IS NULL OR v_project_ref = '' OR v_project_ref = 'YOUR_PROJECT_REF' THEN
    -- Try to extract from database name (Supabase pattern: postgres.[ref])
    SELECT COALESCE(
      NULLIF(REPLACE(current_database(), 'postgres.', ''), current_database()),
      'bvtoxmmiitznagsbubhg'  -- Default to your project ref
    ) INTO v_project_ref;
  END IF;
  
  -- Get service role key
  BEGIN
    SELECT value INTO v_service_role_key
    FROM system_settings
    WHERE key = 'supabase_service_role_key'
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  
  IF v_service_role_key IS NULL OR v_service_role_key = '' THEN
    BEGIN
      v_service_role_key := current_setting('app.settings.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
      v_service_role_key := NULL;
    END;
  END IF;
  
  -- If still not found, we can't proceed
  IF v_service_role_key IS NULL OR v_service_role_key = '' OR v_service_role_key = 'YOUR_SERVICE_ROLE_KEY' THEN
    RETURN QUERY SELECT 
      FALSE, 
      'Service role key not configured. Set it via: ALTER FUNCTION trigger_whatsapp_queue_processor() SET app.settings.service_role_key = ''YOUR_KEY'';'::TEXT,
      v_pending_count,
      NULL::BIGINT;
    RETURN;
  END IF;
  
  -- Construct function URL
  v_function_url := format('https://%s.supabase.co/functions/v1/process-whatsapp-queue', v_project_ref);
  
  -- Make HTTP POST request to trigger the edge function
  BEGIN
    SELECT net.http_post(
      url := v_function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', format('Bearer %s', v_service_role_key),
        'apikey', v_service_role_key
      ),
      body := '{}'::jsonb
    ) INTO v_request_id;
    
    -- Return success
    RETURN QUERY SELECT 
      TRUE, 
      format('Successfully triggered queue processor. URL: %s', v_function_url)::TEXT,
      v_pending_count,
      v_request_id;
    
  EXCEPTION WHEN OTHERS THEN
    -- Return error
    RETURN QUERY SELECT 
      FALSE, 
      format('Error making HTTP request: %s. URL: %s, Service key length: %s', SQLERRM, v_function_url, LENGTH(v_service_role_key))::TEXT,
      v_pending_count,
      NULL::BIGINT;
  END;
  
EXCEPTION WHEN OTHERS THEN
  -- Return error
  RETURN QUERY SELECT 
    FALSE, 
    format('Error in trigger_whatsapp_queue_processor: %s (SQLSTATE: %s)', SQLERRM, SQLSTATE)::TEXT,
    COALESCE(v_pending_count, 0),
    NULL::BIGINT;
END;
$$;

-- Step 4: Create a simpler version that processes queue directly (alternative approach)
-- This avoids HTTP calls and processes messages directly in the database
CREATE OR REPLACE FUNCTION process_whatsapp_queue_direct()
RETURNS TABLE(
  processed INTEGER,
  successful INTEGER,
  failed INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_batch_size INTEGER := 15;
  v_processed INTEGER := 0;
  v_successful INTEGER := 0;
  v_failed INTEGER := 0;
  v_item RECORD;
  v_start_time TIMESTAMP := NOW();
  v_max_execution_time INTERVAL := '50 seconds';
BEGIN
  -- Process messages in batches until time limit or queue is empty
  WHILE (NOW() - v_start_time) < v_max_execution_time LOOP
    -- Get next batch of pending messages
    FOR v_item IN
      SELECT id, user_id, phone, message_hash, message_content
      FROM whatsapp_announcement_queue
      WHERE status = 'pending'
      ORDER BY created_at ASC
      LIMIT v_batch_size
      FOR UPDATE SKIP LOCKED
    LOOP
      -- Check time limit
      IF (NOW() - v_start_time) >= v_max_execution_time THEN
        EXIT;
      END IF;
      
      -- Mark as processing
      UPDATE whatsapp_announcement_queue
      SET 
        status = 'processing',
        last_attempt_at = NOW(),
        attempts = attempts + 1
      WHERE id = v_item.id;
      
      -- Note: Actual message sending must be done via edge function
      -- This function just marks messages for processing
      -- The edge function will handle the actual Wasso API calls
      
      v_processed := v_processed + 1;
    END LOOP;
    
    -- If we didn't get a full batch, we're done
    EXIT WHEN NOT FOUND;
  END LOOP;
  
  RETURN QUERY SELECT v_processed, v_successful, v_failed;
END;
$$;

-- Step 5: Remove any existing cron jobs with this name
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-whatsapp-queue') THEN
    PERFORM cron.unschedule('process-whatsapp-queue');
    RAISE NOTICE 'Removed existing process-whatsapp-queue cron job';
  END IF;
END $$;

-- Step 6: Schedule the cron job to run every minute
-- Note: We'll use the HTTP-based approach to call the edge function
DO $$
DECLARE
  v_cron_available BOOLEAN;
BEGIN
  -- Check if pg_cron is available
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) INTO v_cron_available;
  
  IF v_cron_available THEN
    PERFORM cron.schedule(
      'process-whatsapp-queue',
      '* * * * *',
      'SELECT * FROM trigger_whatsapp_queue_processor();'
    );
    
    RAISE NOTICE '✅ Successfully scheduled process-whatsapp-queue cron job';
    RAISE NOTICE '   The function will run every minute and process pending messages';
  ELSE
    RAISE WARNING 'pg_cron is not available. Cron job not scheduled.';
  END IF;
END $$;

-- Step 7: Grant execute permissions
GRANT EXECUTE ON FUNCTION trigger_whatsapp_queue_processor() TO postgres;
GRANT EXECUTE ON FUNCTION process_whatsapp_queue_direct() TO postgres;

-- Step 8: Add comments
COMMENT ON FUNCTION trigger_whatsapp_queue_processor() IS 
  'Triggers the process-whatsapp-queue edge function via HTTP to process pending WhatsApp messages.
   Scheduled to run every minute via pg_cron.';

COMMENT ON FUNCTION process_whatsapp_queue_direct() IS 
  'Alternative function to process queue directly in database (marks messages as processing).
   Note: Actual message sending is handled by the edge function.';

-- Step 9: Instructions for manual setup
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'WHATSAPP QUEUE CRON SETUP';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  Configuration Check';
  RAISE NOTICE '';
  RAISE NOTICE 'The cron job has been scheduled.';
  RAISE NOTICE 'If the service role key is not configured, set it via:';
  RAISE NOTICE '';
  RAISE NOTICE '  ALTER FUNCTION trigger_whatsapp_queue_processor()';
  RAISE NOTICE '  SET app.settings.service_role_key = ''YOUR_SERVICE_ROLE_KEY'';';
  RAISE NOTICE '';
  RAISE NOTICE 'Find your service role key:';
  RAISE NOTICE '  - Go to Supabase Dashboard > Settings > API';
  RAISE NOTICE '  - Copy the "service_role" key (secret)';
  RAISE NOTICE '';
  RAISE NOTICE 'View scheduled jobs:';
  RAISE NOTICE '  SELECT * FROM cron.job WHERE jobname = ''process-whatsapp-queue'';';
  RAISE NOTICE '';
  RAISE NOTICE 'View execution history:';
  RAISE NOTICE '  SELECT * FROM cron.job_run_details';
  RAISE NOTICE '  WHERE jobid IN (SELECT jobid FROM cron.job WHERE jobname = ''process-whatsapp-queue'')';
  RAISE NOTICE '  ORDER BY start_time DESC LIMIT 10;';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

