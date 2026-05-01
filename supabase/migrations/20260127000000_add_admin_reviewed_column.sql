-- =====================================================================================
-- ADD ADMIN_REVIEWED COLUMN TO USERS TABLE
-- =====================================================================================
-- This migration adds an admin_reviewed column to track which users have been
-- reviewed by admins in the verification page. When an admin approves a user,
-- admin_reviewed is set to true and the user is hidden from the verification page.
-- This is for internal tracking only and does not affect the user's ability to use the app.
-- =====================================================================================

-- Add admin_reviewed column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_reviewed BOOLEAN DEFAULT FALSE;

-- Add comment
COMMENT ON COLUMN users.admin_reviewed IS 'Internal flag: true if admin has reviewed this user in verification page. Does not affect user access.';

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_users_admin_reviewed ON users(admin_reviewed) WHERE admin_reviewed = FALSE;

-- =====================================================================================

