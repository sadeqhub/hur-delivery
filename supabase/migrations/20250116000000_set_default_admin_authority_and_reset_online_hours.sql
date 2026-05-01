-- =====================================================================================
-- SET DEFAULT ADMIN AUTHORITY TO VIEWER AND RESET ONLINE HOURS MONTHLY
-- =====================================================================================
-- 1. Change default admin authority from 'admin' to 'viewer' for new admin users
-- 2. Create function to reset online hours at the start of each month
-- =====================================================================================

-- Update existing admin users without authority to 'viewer' instead of 'admin'
UPDATE users 
SET admin_authority = 'viewer' 
WHERE role = 'admin' AND admin_authority IS NULL;

-- Update the get_admin_authority function to default to 'viewer' (already does this, but ensure it's clear)
CREATE OR REPLACE FUNCTION get_admin_authority(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_user_role TEXT;
  v_user_authority TEXT;
BEGIN
  SELECT role, admin_authority INTO v_user_role, v_user_authority
  FROM users
  WHERE id = p_user_id;
  
  -- Must be admin role
  IF v_user_role != 'admin' THEN
    RETURN NULL;
  END IF;
  
  -- Return authority or default to viewer
  RETURN COALESCE(v_user_authority, 'viewer');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update has_admin_authority function to default to 'viewer' (already does this, but ensure it's clear)
CREATE OR REPLACE FUNCTION has_admin_authority(
  p_user_id UUID,
  p_required_level TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_role TEXT;
  v_user_authority TEXT;
  v_authority_hierarchy TEXT[] := ARRAY['viewer', 'support', 'manager', 'admin', 'super_admin'];
  v_required_index INTEGER;
  v_user_index INTEGER;
BEGIN
  -- Get user role and authority
  SELECT role, admin_authority INTO v_user_role, v_user_authority
  FROM users
  WHERE id = p_user_id;
  
  -- Must be admin role
  IF v_user_role != 'admin' THEN
    RETURN FALSE;
  END IF;
  
  -- If no authority set, default to lowest level (viewer)
  IF v_user_authority IS NULL THEN
    v_user_authority := 'viewer';
  END IF;
  
  -- Find index of required and user authority levels
  v_required_index := array_position(v_authority_hierarchy, p_required_level);
  v_user_index := array_position(v_authority_hierarchy, v_user_authority);
  
  -- User must have equal or higher authority
  RETURN v_user_index >= v_required_index;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- FUNCTION TO RESET ONLINE HOURS AT START OF NEW MONTH
-- =====================================================================================

-- Function to reset online hours for the previous month
-- This should be called at the start of each new month
CREATE OR REPLACE FUNCTION reset_monthly_online_hours()
RETURNS void AS $$
DECLARE
  v_last_month_start DATE;
  v_last_month_end DATE;
  v_current_month_start DATE;
  v_deleted_count INTEGER;
BEGIN
  -- Calculate current month's start date
  v_current_month_start := DATE_TRUNC('month', CURRENT_DATE);
  
  -- Delete all online hours records from previous months
  -- This effectively "resets" the hours for the new month
  DELETE FROM driver_online_hours
  WHERE date < v_current_month_start;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RAISE NOTICE 'Reset online hours: Deleted % records from before %', v_deleted_count, v_current_month_start;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- SCHEDULED JOB TO AUTO-RESET ONLINE HOURS (if pg_cron extension is available)
-- =====================================================================================

-- Create a function that can be called by pg_cron to reset hours monthly
-- This runs at 00:00:00 on the 1st of each month
DO $do$
DECLARE
  v_job_exists BOOLEAN;
BEGIN
  -- Check if pg_cron extension exists
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Check if the job already exists
    SELECT EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'reset-monthly-online-hours'
    ) INTO v_job_exists;
    
    -- Unschedule if it already exists
    IF v_job_exists THEN
      PERFORM cron.unschedule('reset-monthly-online-hours');
      RAISE NOTICE 'Unscheduled existing monthly online hours reset job';
    END IF;
    
    -- Schedule monthly reset at midnight on the 1st of each month
    PERFORM cron.schedule(
      'reset-monthly-online-hours',
      '0 0 1 * *', -- At 00:00 on day 1 of every month
      'SELECT reset_monthly_online_hours();'
    );
    RAISE NOTICE 'Scheduled monthly online hours reset job';
  ELSE
    RAISE NOTICE 'pg_cron extension not available. Please manually call reset_monthly_online_hours() at the start of each month.';
  END IF;
END $do$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION reset_monthly_online_hours() TO authenticated, anon;

-- Add comment
COMMENT ON FUNCTION reset_monthly_online_hours() IS 'Resets driver online hours by deleting records from previous months. Should be called at the start of each new month. Automatically scheduled via pg_cron if available.';
