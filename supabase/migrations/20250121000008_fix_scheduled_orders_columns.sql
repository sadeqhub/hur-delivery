-- =====================================================================================
-- FIX SCHEDULED_ORDERS TABLE COLUMNS
-- =====================================================================================
-- This migration fixes the scheduled_orders table to match what the Flutter app is sending.
-- 
-- Problem:
-- The Flutter app is trying to insert columns that don't exist:
-- - scheduled_date and scheduled_time (table has scheduled_at instead)
-- - is_recurring, recurrence_pattern, recurrence_end_date (don't exist)
-- 
-- Also, the table requires scheduled_at NOT NULL, but the app isn't sending it.
-- 
-- Solution:
-- Add the missing columns to match what the app is sending, OR modify the table
-- to accept the app's format. We'll add the columns the app needs.
-- =====================================================================================

BEGIN;

-- =====================================================================================
-- 1. ADD MISSING COLUMNS FOR RECURRENCE SUPPORT
-- =====================================================================================
-- Add columns for recurring orders that the app is trying to insert

DO $$
BEGIN
  -- Add is_recurring column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'scheduled_orders' AND column_name = 'is_recurring'
  ) THEN
    ALTER TABLE scheduled_orders ADD COLUMN is_recurring BOOLEAN NOT NULL DEFAULT FALSE;
    RAISE NOTICE 'Added is_recurring column';
  END IF;
  
  -- Add recurrence_pattern column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'scheduled_orders' AND column_name = 'recurrence_pattern'
  ) THEN
    ALTER TABLE scheduled_orders ADD COLUMN recurrence_pattern TEXT CHECK (recurrence_pattern IN ('daily', 'weekly', 'monthly'));
    RAISE NOTICE 'Added recurrence_pattern column';
  END IF;
  
  -- Add recurrence_end_date column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'scheduled_orders' AND column_name = 'recurrence_end_date'
  ) THEN
    ALTER TABLE scheduled_orders ADD COLUMN recurrence_end_date DATE;
    RAISE NOTICE 'Added recurrence_end_date column';
  END IF;
END $$;

-- =====================================================================================
-- 2. ADD scheduled_date AND scheduled_time COLUMNS (FOR APP COMPATIBILITY)
-- =====================================================================================
-- The app sends scheduled_date and scheduled_time separately
-- We can either:
-- A) Add these columns and make scheduled_at nullable/computed
-- B) Keep scheduled_at and handle conversion in a trigger
-- 
-- Option B is better - keep scheduled_at, add computed columns for compatibility
-- But actually, since the app needs to INSERT with date/time, let's make scheduled_at nullable
-- and add date/time columns, then use a trigger to compute scheduled_at

DO $$
BEGIN
  -- Add scheduled_date column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'scheduled_orders' AND column_name = 'scheduled_date'
  ) THEN
    ALTER TABLE scheduled_orders ADD COLUMN scheduled_date DATE;
    RAISE NOTICE 'Added scheduled_date column';
  END IF;
  
  -- Add scheduled_time column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'scheduled_orders' AND column_name = 'scheduled_time'
  ) THEN
    ALTER TABLE scheduled_orders ADD COLUMN scheduled_time TIME;
    RAISE NOTICE 'Added scheduled_time column';
  END IF;
END $$;

-- =====================================================================================
-- 3. MAKE scheduled_at COMPUTED OR NULLABLE
-- =====================================================================================
-- Make scheduled_at nullable so inserts can work without it
-- Then compute it from scheduled_date + scheduled_time if they exist

DO $$
BEGIN
  -- Check if scheduled_at is NOT NULL
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'scheduled_orders' 
      AND column_name = 'scheduled_at'
      AND is_nullable = 'NO'
  ) THEN
    -- Make it nullable
    ALTER TABLE scheduled_orders ALTER COLUMN scheduled_at DROP NOT NULL;
    RAISE NOTICE 'Made scheduled_at nullable';
  END IF;
END $$;

-- =====================================================================================
-- 4. CREATE TRIGGER TO COMPUTE scheduled_at FROM scheduled_date + scheduled_time
-- =====================================================================================
-- When scheduled_date and scheduled_time are provided, compute scheduled_at
-- If scheduled_at is provided directly, use it

CREATE OR REPLACE FUNCTION compute_scheduled_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  -- If scheduled_date and scheduled_time are provided, compute scheduled_at
  IF NEW.scheduled_date IS NOT NULL AND NEW.scheduled_time IS NOT NULL THEN
    -- Combine date and time into timestamp
    NEW.scheduled_at := (NEW.scheduled_date::text || ' ' || NEW.scheduled_time::text)::timestamp with time zone;
  ELSIF NEW.scheduled_at IS NULL THEN
    -- If neither is provided, we can't compute it - but this shouldn't happen
    -- Keep existing scheduled_at if it exists
    IF TG_OP = 'UPDATE' AND OLD.scheduled_at IS NOT NULL THEN
      NEW.scheduled_at := OLD.scheduled_at;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS trigger_compute_scheduled_at ON scheduled_orders;

-- Create trigger
CREATE TRIGGER trigger_compute_scheduled_at
  BEFORE INSERT OR UPDATE ON scheduled_orders
  FOR EACH ROW
  EXECUTE FUNCTION compute_scheduled_at();

COMMENT ON FUNCTION compute_scheduled_at IS 
  'Computes scheduled_at from scheduled_date + scheduled_time when they are provided';

-- =====================================================================================
-- 5. UPDATE EXISTING RECORDS (IF ANY) TO POPULATE scheduled_date AND scheduled_time
-- =====================================================================================
-- For existing records that have scheduled_at but not scheduled_date/scheduled_time,
-- extract them

DO $$
DECLARE
  row_count INT;
BEGIN
  UPDATE scheduled_orders
  SET 
    scheduled_date = scheduled_at::date,
    scheduled_time = scheduled_at::time
  WHERE scheduled_at IS NOT NULL
    AND (scheduled_date IS NULL OR scheduled_time IS NULL);
  
  GET DIAGNOSTICS row_count = ROW_COUNT;
  IF row_count > 0 THEN
    RAISE NOTICE 'Updated % existing records with scheduled_date and scheduled_time', row_count;
  END IF;
END $$;

COMMIT;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- 1. ADDED COLUMNS:
--    - scheduled_date: DATE (for app compatibility)
--    - scheduled_time: TIME (for app compatibility)
--    - is_recurring: BOOLEAN (for recurring orders)
--    - recurrence_pattern: TEXT (daily, weekly, monthly)
--    - recurrence_end_date: DATE (when recurrence ends)
-- 
-- 2. scheduled_at COLUMN:
--    - Made nullable (was NOT NULL)
--    - Computed automatically from scheduled_date + scheduled_time via trigger
--    - Can also be set directly if needed
-- 
-- 3. TRIGGER:
--    - trigger_compute_scheduled_at computes scheduled_at from scheduled_date + scheduled_time
--    - Runs BEFORE INSERT OR UPDATE
--    - Ensures scheduled_at is always populated when date/time are provided
-- 
-- 4. BACKWARDS COMPATIBILITY:
--    - Existing code that uses scheduled_at directly will still work
--    - App code that uses scheduled_date/scheduled_time will now work
--    - Both approaches are supported
-- =====================================================================================

