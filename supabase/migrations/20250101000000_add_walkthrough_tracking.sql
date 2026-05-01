-- Add walkthrough completion tracking fields to users table
-- This migration adds columns to track whether merchants and drivers have completed their walkthroughs

-- Add merchant walkthrough completion field
ALTER TABLE users ADD COLUMN IF NOT EXISTS merchant_walkthrough_completed BOOLEAN DEFAULT FALSE;

-- Add driver walkthrough completion field
ALTER TABLE users ADD COLUMN IF NOT EXISTS driver_walkthrough_completed BOOLEAN DEFAULT FALSE;

-- Add timestamps for when walkthroughs were completed
ALTER TABLE users ADD COLUMN IF NOT EXISTS merchant_walkthrough_completed_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS driver_walkthrough_completed_at TIMESTAMPTZ;

-- Create index for quick lookups of users who haven't completed walkthroughs
CREATE INDEX IF NOT EXISTS idx_users_merchant_walkthrough 
  ON users(merchant_walkthrough_completed) 
  WHERE role = 'merchant';

CREATE INDEX IF NOT EXISTS idx_users_driver_walkthrough 
  ON users(driver_walkthrough_completed) 
  WHERE role = 'driver';

-- Add comments for documentation
COMMENT ON COLUMN users.merchant_walkthrough_completed IS 'Tracks if merchant has completed the mandatory walkthrough explaining how delivery works';
COMMENT ON COLUMN users.driver_walkthrough_completed IS 'Tracks if driver has completed the mandatory walkthrough explaining how delivery works';
COMMENT ON COLUMN users.merchant_walkthrough_completed_at IS 'Timestamp when merchant completed the walkthrough';
COMMENT ON COLUMN users.driver_walkthrough_completed_at IS 'Timestamp when driver completed the walkthrough';

