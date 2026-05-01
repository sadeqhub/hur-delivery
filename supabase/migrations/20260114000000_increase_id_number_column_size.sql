-- =====================================================================================
-- INCREASE ID_NUMBER COLUMN SIZE
-- =====================================================================================
-- This migration increases the id_number column size from VARCHAR(12) to TEXT
-- to accommodate ID numbers of varying lengths. The original constraint requiring
-- exactly 12 digits was removed in a previous migration, but the column size
-- was not updated, causing "value too long" errors.
-- =====================================================================================

begin;

-- Drop the format constraint if it still exists (should have been removed in migration 20251115000003)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_id_number_format;

-- Alter the column to TEXT to allow any length
ALTER TABLE users 
  ALTER COLUMN id_number TYPE TEXT USING id_number::TEXT;

-- Update the comment to reflect the change
COMMENT ON COLUMN users.id_number IS 'National ID number - must be unique (variable length, no format enforced)';

commit;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- The id_number column was originally VARCHAR(12) expecting exactly 12 digits.
-- A format constraint (users_id_number_format) was supposed to be removed in 
-- migration 20251115000003, but it appears to still exist in some databases.
-- This migration:
-- 1. Explicitly drops the format constraint if it exists
-- 2. Increases the column size to TEXT to prevent "value too long" errors
-- 3. Allows ID numbers of any length while maintaining uniqueness
-- 
-- The unique index (idx_users_id_number_unique) remains in place to prevent
-- duplicate ID numbers.
-- =====================================================================================

