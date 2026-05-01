-- =====================================================================================
-- FILTER ONLINE HOURS TO 8AM - 12AM GMT+3
-- =====================================================================================
-- This migration updates the tracking logic to only count hours that occur
-- between 08:00 AM and 11:59:59 PM (Baghdad Time / GMT+3).
-- Hours outside this window (e.g., 2 AM) are ignored for ranking purposes.
-- =====================================================================================

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
    -- Get last seen time or use updated_at
    v_last_seen := COALESCE(OLD.last_seen_at, OLD.updated_at, NOW() - INTERVAL '1 hour');
    
    -- Calculate "today" in Baghdad time to define the window
    -- Note: If the session spans across midnight, this simple logic might capture only the "current day" window part.
    -- For simplicity/safety, we clamp to the window of the "end" time day.
    -- Ideally, we should split cross-day sessions, but for a delivery app, sessions likely don't span days often in this context.
    
    v_today_baghdad := (v_current_time AT TIME ZONE v_timezone)::DATE;
    
    -- Construct window limits in UTC
    -- Start: Today 08:00 Baghdad -> UTC
    v_start_window := (v_today_baghdad || ' ' || v_start_hour || ':00:00')::TIMESTAMP AT TIME ZONE v_timezone;
    
    -- End: Today 23:59:59 Baghdad -> UTC (approximated as next day 00:00)
    v_end_window := (v_today_baghdad || ' 23:59:59.999')::TIMESTAMP AT TIME ZONE v_timezone;

    -- Calculate intersection
    -- The valid session is [v_last_seen, v_current_time] INTERSECT [v_start_window, v_end_window]
    
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
    NEW.last_seen_at := v_current_time;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
