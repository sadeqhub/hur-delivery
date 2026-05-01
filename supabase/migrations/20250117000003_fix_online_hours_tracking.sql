-- =====================================================================================
-- FIX ONLINE HOURS TRACKING - ADD PERIODIC UPDATES
-- =====================================================================================
-- The current system only tracks hours when drivers go offline.
-- This migration adds a periodic update mechanism to track hours for drivers
-- who are currently online, ensuring hours are recorded even if they don't
-- properly go offline.
-- =====================================================================================

-- Function to update online hours for currently online drivers
CREATE OR REPLACE FUNCTION update_online_drivers_hours()
RETURNS void AS $$
DECLARE
  v_driver RECORD;
  v_current_time TIMESTAMPTZ := NOW();
  v_last_seen TIMESTAMPTZ;
  v_hours_online DECIMAL := 0;
  
  -- Time window configuration (Baghdad Time)
  v_start_hour INTEGER := 8;  -- 8 AM
  v_end_hour INTEGER := 24;   -- 12 AM (midnight)
  
  -- Variables for time calculations
  v_start_window TIMESTAMPTZ;
  v_end_window TIMESTAMPTZ;
  v_valid_start TIMESTAMPTZ;
  v_valid_end TIMESTAMPTZ;
  v_today_baghdad DATE;
  v_timezone TEXT := 'Asia/Baghdad';
  v_updated_count INTEGER := 0;
BEGIN
  -- Process all currently online drivers
  FOR v_driver IN
    SELECT id, last_seen_at, updated_at
    FROM users
    WHERE role = 'driver'
      AND is_online = TRUE
      AND last_seen_at IS NOT NULL
  LOOP
    -- Get last seen time
    v_last_seen := COALESCE(v_driver.last_seen_at, v_driver.updated_at, NOW() - INTERVAL '1 hour');
    
    -- Only process if last_seen_at is more than 5 minutes ago (to avoid too frequent updates)
    IF EXTRACT(EPOCH FROM (v_current_time - v_last_seen)) < 300 THEN
      CONTINUE;
    END IF;
    
    -- Calculate "today" in Baghdad time
    v_today_baghdad := (v_current_time AT TIME ZONE v_timezone)::DATE;
    
    -- Construct window limits in UTC
    v_start_window := (v_today_baghdad || ' ' || v_start_hour || ':00:00')::TIMESTAMP AT TIME ZONE v_timezone;
    v_end_window := (v_today_baghdad || ' 23:59:59.999')::TIMESTAMP AT TIME ZONE v_timezone;

    -- Calculate intersection
    v_valid_start := GREATEST(v_last_seen, v_start_window);
    v_valid_end := LEAST(v_current_time, v_end_window);
    
    IF v_valid_end > v_valid_start THEN
      -- Valid overlap found
      v_hours_online := EXTRACT(EPOCH FROM (v_valid_end - v_valid_start)) / 3600.0;
      
      -- Only record if significant time has passed (at least 0.01 hours = 36 seconds)
      IF v_hours_online > 0.01 THEN
        -- Record the hours
        PERFORM record_driver_online_time(v_driver.id, v_hours_online);
        
        -- Update last_seen_at to current time
        UPDATE users
        SET last_seen_at = v_current_time,
            updated_at = v_current_time
        WHERE id = v_driver.id;
        
        v_updated_count := v_updated_count + 1;
      END IF;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Updated online hours for % drivers', v_updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a cron job to run this every 10 minutes
DO $$
BEGIN
  -- Check if pg_cron extension is available
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Remove existing job if it exists
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'update-online-drivers-hours') THEN
      PERFORM cron.unschedule('update-online-drivers-hours');
    END IF;
    
    -- Schedule the job to run every 10 minutes
    PERFORM cron.schedule(
      'update-online-drivers-hours',
      '*/10 * * * *',  -- Every 10 minutes
      'SELECT update_online_drivers_hours();'
    );
    
    RAISE NOTICE 'Scheduled online hours update job to run every 10 minutes';
  ELSE
    RAISE WARNING 'pg_cron extension not available. Online hours will only be updated when drivers go offline.';
  END IF;
END $$;

-- Also improve the trigger to handle edge cases better
CREATE OR REPLACE FUNCTION track_driver_online_status()
RETURNS TRIGGER AS $$
DECLARE
  v_current_time TIMESTAMPTZ := NOW();
  v_last_seen TIMESTAMPTZ;
  v_hours_online DECIMAL := 0;
  
  -- Time window configuration (Baghdad Time)
  v_start_hour INTEGER := 8;  -- 8 AM
  v_end_hour INTEGER := 24;   -- 12 AM (midnight)
  
  -- Variables for time calculations
  v_start_window TIMESTAMPTZ;
  v_end_window TIMESTAMPTZ;
  v_valid_start TIMESTAMPTZ;
  v_valid_end TIMESTAMPTZ;
  v_today_baghdad DATE;
  v_timezone TEXT := 'Asia/Baghdad';
BEGIN
  -- Only process for drivers
  IF NEW.role != 'driver' THEN
    RETURN NEW;
  END IF;
  
  -- When driver goes offline, calculate hours online since last seen
  IF OLD.is_online = TRUE AND NEW.is_online = FALSE THEN
    -- Get last seen time - use the most recent of last_seen_at, updated_at, or a fallback
    v_last_seen := COALESCE(
      OLD.last_seen_at, 
      OLD.updated_at, 
      NOW() - INTERVAL '1 hour'
    );
    
    -- Calculate "today" in Baghdad time
    v_today_baghdad := (v_current_time AT TIME ZONE v_timezone)::DATE;
    
    -- Construct window limits in UTC
    v_start_window := (v_today_baghdad || ' ' || v_start_hour || ':00:00')::TIMESTAMP AT TIME ZONE v_timezone;
    v_end_window := (v_today_baghdad || ' 23:59:59.999')::TIMESTAMP AT TIME ZONE v_timezone;

    -- Calculate intersection
    v_valid_start := GREATEST(v_last_seen, v_start_window);
    v_valid_end := LEAST(v_current_time, v_end_window);
    
    IF v_valid_end > v_valid_start THEN
      -- Valid overlap found
      v_hours_online := EXTRACT(EPOCH FROM (v_valid_end - v_valid_start)) / 3600.0;
      
      -- Enforce minimum precision and safeguards
      IF v_hours_online > 0.001 THEN
        PERFORM record_driver_online_time(NEW.id, v_hours_online);
      END IF;
    END IF;
    
    -- Update last_seen_at
    NEW.last_seen_at := v_current_time;
  END IF;
  
  -- When driver goes online, update last_seen_at
  IF NEW.is_online = TRUE THEN
    -- If going from offline to online, set last_seen_at to now
    IF OLD.is_online = FALSE OR OLD.is_online IS NULL THEN
      NEW.last_seen_at := v_current_time;
    END IF;
    -- If already online, don't update last_seen_at here (let periodic job handle it)
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_online_drivers_hours() TO postgres;

-- Add comments
COMMENT ON FUNCTION update_online_drivers_hours() IS 
  'Periodically updates online hours for drivers who are currently online.
   Should be called every 10 minutes via cron job to ensure hours are tracked
   even if drivers don''t properly go offline.';

COMMENT ON FUNCTION track_driver_online_status() IS 
  'Trigger function that tracks online hours when driver status changes.
   Records hours when driver goes offline, using time window filtering (8 AM - 12 AM GMT+3).';

