-- =====================================================================================
-- STEP 1: DROP ALL FUNCTION VARIANTS
-- =====================================================================================
-- This migration drops all function variants that will be recreated without manual_verified checks
-- Run this first, then run the next migration to create the updated functions
-- =====================================================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  -- Drop all variants of find_next_available_driver
  FOR r IN 
    SELECT oid, proname, pg_get_function_identity_arguments(oid) as args
    FROM pg_proc 
    WHERE proname = 'find_next_available_driver'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %s(%s) CASCADE', r.proname, r.args);
  END LOOP;
  
  -- Drop all variants of get_ranked_available_drivers
  FOR r IN 
    SELECT oid, proname, pg_get_function_identity_arguments(oid) as args
    FROM pg_proc 
    WHERE proname = 'get_ranked_available_drivers'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %s(%s) CASCADE', r.proname, r.args);
  END LOOP;
  
  -- Drop other functions that might have conflicts
  DROP FUNCTION IF EXISTS find_next_available_driver_v2(UUID, DECIMAL, DECIMAL) CASCADE;
  DROP FUNCTION IF EXISTS get_ranked_available_drivers_v2(UUID, DECIMAL, DECIMAL, INTEGER) CASCADE;
  DROP FUNCTION IF EXISTS get_compatible_drivers(TEXT) CASCADE;
  DROP FUNCTION IF EXISTS find_driver_for_any_vehicle_type(UUID, DECIMAL, DECIMAL) CASCADE;
  DROP FUNCTION IF EXISTS can_repost_order(UUID) CASCADE;
  DROP FUNCTION IF EXISTS get_available_drivers_for_admin(DECIMAL, DECIMAL, TEXT) CASCADE;
  DROP FUNCTION IF EXISTS rotate_driver_assignment(UUID) CASCADE;
  DROP FUNCTION IF EXISTS check_vehicle_availability(TEXT) CASCADE;
END $$;

