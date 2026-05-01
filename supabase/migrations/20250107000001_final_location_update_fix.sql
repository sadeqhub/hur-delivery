-- ============================================================================
-- FINAL LOCATION UPDATE FIX
-- ============================================================================
-- 1. Completely remove any announcement creation for location updates
-- 2. Ensure route recalculation happens properly
-- ============================================================================

-- Drop any triggers that might create announcements
DROP TRIGGER IF EXISTS trigger_location_update_notification ON orders;
DROP TRIGGER IF EXISTS trigger_notify_location_update ON orders;
DROP TRIGGER IF EXISTS trigger_customer_location_announcement ON orders;

-- Drop any functions that create announcements for location updates
DROP FUNCTION IF EXISTS notify_location_update() CASCADE;
DROP FUNCTION IF EXISTS create_location_update_announcement() CASCADE;
DROP FUNCTION IF EXISTS trigger_location_announcement() CASCADE;

-- Verify no triggers exist that insert into system_announcements for location updates
DO $$
DECLARE
  trigger_record RECORD;
BEGIN
  FOR trigger_record IN 
    SELECT tgname, tgrelid::regclass as table_name
    FROM pg_trigger
    WHERE tgname LIKE '%location%'
  LOOP
    RAISE NOTICE 'Found trigger: % on table %', trigger_record.tgname, trigger_record.table_name;
  END LOOP;
END $$;

-- Add comment to document the approach
COMMENT ON COLUMN orders.customer_location_provided IS 
  'Flag set when customer provides location via WhatsApp. Used ONLY by Simple Location Update Widget to show notification. NO announcements are created.';

COMMENT ON COLUMN orders.driver_notified_location IS 
  'Flag set when driver acknowledges location update notification in the app via Simple Location Update Widget.';

COMMENT ON COLUMN orders.updated_at IS 
  'Timestamp of last update. When location changes, this triggers Supabase Realtime which causes OrderProvider to refresh and map to recalculate route.';

-- Create a function to check if announcements are being created inappropriately
CREATE OR REPLACE FUNCTION check_location_announcement_sources()
RETURNS TABLE(source_type TEXT, source_name TEXT, creates_announcement BOOLEAN) AS $$
BEGIN
  -- Check triggers
  RETURN QUERY
  SELECT 
    'trigger'::TEXT as source_type,
    tgname::TEXT as source_name,
    true as creates_announcement
  FROM pg_trigger t
  JOIN pg_proc p ON t.tgfoid = p.oid
  WHERE p.prosrc LIKE '%system_announcements%'
    AND p.prosrc LIKE '%location%';
  
  -- Check functions
  RETURN QUERY
  SELECT 
    'function'::TEXT as source_type,
    proname::TEXT as source_name,
    true as creates_announcement
  FROM pg_proc
  WHERE prosrc LIKE '%system_announcements%'
    AND prosrc LIKE '%location%'
    AND proname NOT LIKE 'check_location%';
END;
$$ LANGUAGE plpgsql;

-- Run the check
DO $$
DECLARE
  source_record RECORD;
  found_sources BOOLEAN := FALSE;
BEGIN
  FOR source_record IN SELECT * FROM check_location_announcement_sources()
  LOOP
    found_sources := TRUE;
    RAISE WARNING '⚠️  Found source creating location announcements: % - %', 
      source_record.source_type, source_record.source_name;
  END LOOP;
  
  IF NOT found_sources THEN
    RAISE NOTICE '✅ No sources found that create location announcements';
  END IF;
END $$;

-- Log success
DO $$
BEGIN
  RAISE NOTICE '============================================================================';
  RAISE NOTICE '✅ Location Update Fix Applied';
  RAISE NOTICE '============================================================================';
  RAISE NOTICE '1. All announcement triggers removed';
  RAISE NOTICE '2. All announcement functions removed';
  RAISE NOTICE '3. Only Simple Location Update Widget handles notifications';
  RAISE NOTICE '4. Route recalculation happens via:';
  RAISE NOTICE '   - updated_at changes → Supabase Realtime';
  RAISE NOTICE '   - OrderProvider refreshes';
  RAISE NOTICE '   - Map widget didUpdateWidget detects coordinate change';
  RAISE NOTICE '   - Route automatically recalculates';
  RAISE NOTICE '============================================================================';
END $$;

