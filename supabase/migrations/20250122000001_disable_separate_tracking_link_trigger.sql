-- =====================================================================================
-- DISABLE SEPARATE TRACKING LINK TRIGGER
-- =====================================================================================
-- Since tracking link is now included in the location request message,
-- we disable the separate tracking link trigger to avoid duplicate messages
-- =====================================================================================

-- Drop the separate tracking link trigger
DROP TRIGGER IF EXISTS trigger_send_tracking_link_on_accepted ON orders;

-- Drop the function (optional, but keeps things clean)
-- Note: We keep the function in case we need it later, but the trigger is disabled
-- DROP FUNCTION IF EXISTS send_tracking_link_on_accepted();

COMMENT ON FUNCTION send_tracking_link_on_accepted IS 
  'DISABLED: Tracking link is now included in location request message. Trigger has been dropped.';

