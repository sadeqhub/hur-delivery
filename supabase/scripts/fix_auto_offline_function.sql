-- =====================================================================================
-- FIX AUTO-OFFLINE FUNCTION - Remove Ambiguity
-- =====================================================================================
-- This script fixes the ambiguous column reference error
-- =====================================================================================

-- Drop and recreate the function with a cleaner structure
DROP FUNCTION IF EXISTS mark_drivers_offline_by_location();
DROP FUNCTION IF EXISTS call_mark_drivers_offline_by_location();

-- Create the function with explicit column references to avoid ambiguity
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
  v_driver_id_var UUID;
BEGIN
  -- Update drivers who haven't had a location update in the last 10 minutes
  -- Using a subquery approach to avoid ambiguity
  UPDATE users u
  SET 
    is_online = FALSE,
    updated_at = NOW()
  WHERE u.role = 'driver'
    AND u.is_online = TRUE
    AND EXISTS (
      SELECT 1
      FROM (
        SELECT DISTINCT ON (dl.driver_id)
          dl.driver_id as loc_driver_id,
          dl.created_at as loc_created_at
        FROM driver_locations dl
        ORDER BY dl.driver_id, dl.created_at DESC
      ) latest
      WHERE latest.loc_driver_id = u.id
        AND latest.loc_created_at < NOW() - INTERVAL '10 minutes'
    );
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  -- Handle drivers with NO location records at all
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
  SELECT 
    u.id as driver_id,
    u.name as driver_name,
    COALESCE(
      (SELECT MAX(dl2.created_at) 
       FROM driver_locations dl2 
       WHERE dl2.driver_id = u.id),
      u.created_at
    ) as last_location_update,
    EXTRACT(EPOCH FROM (
      NOW() - COALESCE(
        (SELECT MAX(dl2.created_at) 
         FROM driver_locations dl2 
         WHERE dl2.driver_id = u.id),
        u.created_at
      )
    )) / 60.0 as minutes_since_update,
    TRUE as was_online,
    TRUE as marked_offline
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = FALSE
    AND u.updated_at > NOW() - INTERVAL '1 minute'
    AND (
      NOT EXISTS (
        SELECT 1 FROM driver_locations dl3 WHERE dl3.driver_id = u.id
      )
      OR (
        SELECT MAX(dl4.created_at) 
        FROM driver_locations dl4 
        WHERE dl4.driver_id = u.id
      ) < NOW() - INTERVAL '10 minutes'
    );
  
  -- Log the results
  RAISE NOTICE 'Marked % driver(s) offline due to stale location updates (>10 min)', v_updated_count;
  RAISE NOTICE 'Marked % driver(s) offline due to no location records', v_no_location_count;
  
END;
$$;

-- Create the wrapper function for cron
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION mark_drivers_offline_by_location() TO authenticated;
GRANT EXECUTE ON FUNCTION mark_drivers_offline_by_location() TO service_role;
GRANT EXECUTE ON FUNCTION call_mark_drivers_offline_by_location() TO authenticated;
GRANT EXECUTE ON FUNCTION call_mark_drivers_offline_by_location() TO service_role;

-- Add comments
COMMENT ON FUNCTION mark_drivers_offline_by_location() IS 
  'Automatically marks drivers as offline if their location hasn''t been updated in driver_locations table for 10 minutes. Returns information about drivers that were marked offline.';

COMMENT ON FUNCTION call_mark_drivers_offline_by_location() IS 
  'Wrapper function for cron jobs. Calls mark_drivers_offline_by_location() but returns void. Use this for scheduled cron jobs.';

-- Test the function
SELECT 'Function created successfully. Testing...' as status;

-- Test it (uncomment to run)
-- SELECT * FROM mark_drivers_offline_by_location();















