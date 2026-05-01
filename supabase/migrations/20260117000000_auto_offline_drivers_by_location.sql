-- =====================================================================================
-- AUTO-OFFLINE DRIVERS BASED ON LOCATION UPDATES
-- =====================================================================================
-- This migration creates a function that automatically sets drivers as offline
-- if their location hasn't been updated in the driver_locations table for 10 minutes
-- =====================================================================================

-- Function to mark drivers offline based on location update time
CREATE OR REPLACE FUNCTION mark_drivers_offline_by_location()
RETURNS TABLE(
  driver_id UUID,
  driver_name TEXT,
  last_location_update TIMESTAMPTZ,
  minutes_since_update NUMERIC,
  was_online BOOLEAN,
  marked_offline BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_updated_count INTEGER := 0;
  v_no_location_count INTEGER := 0;
BEGIN
  -- Update drivers who haven't had a location update in the last 10 minutes
  -- Only update drivers who are currently marked as online
  WITH latest_locations AS (
    -- Get the most recent location update for each driver
    SELECT DISTINCT ON (dl.driver_id)
      dl.driver_id,
      dl.created_at as last_location_update
    FROM driver_locations dl
    ORDER BY dl.driver_id, dl.created_at DESC
  )
  UPDATE users u
  SET 
    is_online = FALSE,
    updated_at = NOW()
  FROM latest_locations ll
  WHERE u.id = ll.driver_id
    AND u.role = 'driver'
    AND u.is_online = TRUE
    AND ll.last_location_update < NOW() - INTERVAL '10 minutes';
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  -- Also handle drivers who have NO location records at all
  -- If they're online but have never had a location update, mark them offline
  UPDATE users u
  SET 
    is_online = FALSE,
    updated_at = NOW()
  WHERE u.role = 'driver'
    AND u.is_online = TRUE
    AND NOT EXISTS (
      SELECT 1 
      FROM driver_locations dl 
      WHERE dl.driver_id = u.id
    );
  
  GET DIAGNOSTICS v_no_location_count = ROW_COUNT;
  
  -- Return information about drivers that were marked offline
  RETURN QUERY
  WITH latest_locations AS (
    SELECT DISTINCT ON (dl.driver_id)
      dl.driver_id,
      dl.created_at as last_location_update
    FROM driver_locations dl
    ORDER BY dl.driver_id, dl.created_at DESC
  )
  SELECT 
    u.id as driver_id,
    u.name as driver_name,
    COALESCE(ll.last_location_update, u.created_at) as last_location_update,
    EXTRACT(EPOCH FROM (NOW() - COALESCE(ll.last_location_update, u.created_at))) / 60.0 as minutes_since_update,
    TRUE as was_online,  -- They were online before this function ran
    TRUE as marked_offline
  FROM users u
  LEFT JOIN latest_locations ll ON u.id = ll.driver_id
  WHERE u.role = 'driver'
    AND u.is_online = FALSE  -- Now offline (just updated)
    AND u.updated_at > NOW() - INTERVAL '1 minute'  -- Only drivers just updated by this function
    AND (
      -- Either no location records, or last update was > 10 minutes ago
      ll.last_location_update IS NULL 
      OR ll.last_location_update < NOW() - INTERVAL '10 minutes'
    );
  
  -- Log the results
  RAISE NOTICE 'Marked % driver(s) offline due to stale location updates (>10 min)', v_updated_count;
  RAISE NOTICE 'Marked % driver(s) offline due to no location records', v_no_location_count;
  
END;
$$;

-- Wrapper function for cron (returns void, better for cron jobs)
CREATE OR REPLACE FUNCTION call_mark_drivers_offline_by_location()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  -- Call the main function but don't return the results
  PERFORM mark_drivers_offline_by_location();
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION mark_drivers_offline_by_location() TO authenticated;
GRANT EXECUTE ON FUNCTION mark_drivers_offline_by_location() TO service_role;
GRANT EXECUTE ON FUNCTION call_mark_drivers_offline_by_location() TO authenticated;
GRANT EXECUTE ON FUNCTION call_mark_drivers_offline_by_location() TO service_role;

-- Add comments
COMMENT ON FUNCTION mark_drivers_offline_by_location() IS 
  'Automatically marks drivers as offline if their location hasn''t been updated in driver_locations table for 10 minutes. Returns information about drivers that were marked offline.';

COMMENT ON FUNCTION call_mark_drivers_offline_by_location() IS 
  'Wrapper function for cron jobs. Calls mark_drivers_offline_by_location() but returns void. Use this for scheduled cron jobs.';

-- =====================================================================================
-- SCHEDULE CRON JOB (if pg_cron is available)
-- =====================================================================================

DO $$
DECLARE
  v_cron_available BOOLEAN;
  v_job_id BIGINT;
  v_job_count INTEGER;
  v_job_info RECORD;
BEGIN
  -- Check if pg_cron extension is available
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) INTO v_cron_available;
  
  IF NOT v_cron_available THEN
    RAISE WARNING 'pg_cron extension is not available. Auto-offline will not be scheduled.';
    RAISE WARNING 'To enable: Go to Supabase Dashboard > Database > Extensions > Enable pg_cron';
    RAISE WARNING 'You can manually call: SELECT mark_drivers_offline_by_location();';
    RETURN;
  END IF;
  
  -- Remove any existing cron job with this name
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'auto-offline-drivers-by-location') THEN
    PERFORM cron.unschedule('auto-offline-drivers-by-location');
    RAISE NOTICE 'Removed existing auto-offline-drivers-by-location cron job';
  END IF;
  
  -- Schedule the job to run every 2 minutes
  -- This ensures drivers are marked offline within 10-12 minutes of their last location update
  -- Using the wrapper function that returns void (better for cron)
  SELECT cron.schedule(
    'auto-offline-drivers-by-location',
    '*/2 * * * *',  -- Every 2 minutes (cron format: minute hour day month weekday)
    'SELECT call_mark_drivers_offline_by_location();'
  ) INTO v_job_id;
  
  -- Verify the job was created
  SELECT COUNT(*) INTO v_job_count
  FROM cron.job
  WHERE jobname = 'auto-offline-drivers-by-location';
  
  IF v_job_count > 0 THEN
    SELECT * INTO v_job_info
    FROM cron.job
    WHERE jobname = 'auto-offline-drivers-by-location'
    LIMIT 1;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'AUTO-OFFLINE CRON JOB SETUP COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Job ID: %', v_job_id;
    RAISE NOTICE 'Job Name: %', v_job_info.jobname;
    RAISE NOTICE 'Schedule: %', v_job_info.schedule;
    RAISE NOTICE 'Active: %', CASE WHEN v_job_info.active THEN 'YES ✅' ELSE 'NO ❌' END;
    RAISE NOTICE '';
    RAISE NOTICE 'The function call_mark_drivers_offline_by_location() will run every 2 minutes';
    RAISE NOTICE 'and mark drivers offline if their location hasn''t been updated for 10+ minutes.';
    RAISE NOTICE '';
    RAISE NOTICE 'View cron job details:';
    RAISE NOTICE '  SELECT * FROM cron.job WHERE jobname = ''auto-offline-drivers-by-location'';';
    RAISE NOTICE '';
    RAISE NOTICE 'View execution history:';
    RAISE NOTICE '  SELECT * FROM cron.job_run_details';
    RAISE NOTICE '  WHERE jobid = %', v_job_id;
    RAISE NOTICE '  ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '========================================';
    
    IF NOT v_job_info.active THEN
      RAISE WARNING '⚠️  WARNING: Job is scheduled but INACTIVE';
      RAISE WARNING '   You may need to activate it manually';
    END IF;
  ELSE
    RAISE WARNING '❌ Cron job was not scheduled successfully';
    RAISE WARNING '   Please check for errors above';
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error setting up cron job: %', SQLERRM;
    RAISE WARNING 'You can manually call the function: SELECT mark_drivers_offline_by_location();';
END $$;

-- =====================================================================================
-- VERIFICATION QUERIES (for testing)
-- =====================================================================================

-- To test the function manually:
-- SELECT * FROM mark_drivers_offline_by_location();

-- To check which drivers would be affected (before running):
-- SELECT 
--   u.id,
--   u.name,
--   u.is_online,
--   MAX(dl.created_at) as last_location_update,
--   NOW() - MAX(dl.created_at) as time_since_update,
--   CASE 
--     WHEN MAX(dl.created_at) < NOW() - INTERVAL '10 minutes' THEN 'Should be offline'
--     ELSE 'OK'
--   END as status
-- FROM users u
-- LEFT JOIN driver_locations dl ON u.id = dl.driver_id
-- WHERE u.role = 'driver' AND u.is_online = TRUE
-- GROUP BY u.id, u.name, u.is_online
-- ORDER BY last_location_update ASC NULLS FIRST;

