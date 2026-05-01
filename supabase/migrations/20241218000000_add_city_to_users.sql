-- =====================================================================================
-- ADD CITY FIELD TO USERS TABLE
-- =====================================================================================
-- This migration adds a city field to the users table to separate merchants and drivers
-- by city (Najaf or Mosul). This allows for city-based filtering and separation in
-- the admin panel and throughout the application.
-- =====================================================================================

-- Add city column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS city TEXT;

-- Add constraint for valid city values
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_city_check;
ALTER TABLE users ADD CONSTRAINT users_city_check 
CHECK (city IS NULL OR city IN ('najaf', 'mosul'));

-- Add comment
COMMENT ON COLUMN users.city IS 'City where the user operates (najaf or mosul). Required for merchants and drivers.';

-- Create index for faster city-based queries
CREATE INDEX IF NOT EXISTS idx_users_city ON users(city) WHERE city IS NOT NULL;

-- Add RLS policy to allow users to update their own city
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'users' 
    AND policyname = 'Users can update their own city'
  ) THEN
    CREATE POLICY "Users can update their own city"
    ON users
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);
  END IF;
END $$;

-- =====================================================================================

