-- ============================================================================
-- DISABLE LOCATION UPDATE ANNOUNCEMENTS (Prevent Duplicates)
-- ============================================================================
-- The Simple Location Update Widget now handles all location update notifications.
-- This migration disables the automatic announcement creation to prevent duplicates.
-- ============================================================================

-- Drop the trigger that creates announcements for location updates
DROP TRIGGER IF EXISTS trigger_location_update_notification ON orders;

-- Drop the function that creates announcements
DROP FUNCTION IF EXISTS notify_location_update();

-- Note: The Simple Location Update Widget (simple_location_update_widget.dart)
-- now handles all location update notifications by:
-- 1. Polling every 3 seconds for customer_location_provided = true
-- 2. Showing a beautiful popup dialog
-- 3. Marking driver_notified_location = true when acknowledged
--
-- This provides a better UX with a single, clean notification instead of
-- having both an announcement popup and the widget popup.

COMMENT ON COLUMN orders.customer_location_provided IS 
  'Flag set when customer provides location via WhatsApp. Used by Simple Location Update Widget to show notification.';

COMMENT ON COLUMN orders.driver_notified_location IS 
  'Flag set when driver acknowledges location update notification in the app.';

-- Log success message
DO $$
BEGIN
  RAISE NOTICE '✅ Location update announcements disabled to prevent duplicates';
  RAISE NOTICE '   - Simple Location Update Widget now handles all notifications';
  RAISE NOTICE '   - No more duplicate popups';
END $$;

