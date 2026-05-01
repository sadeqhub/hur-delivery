-- =====================================================================================
-- ADMIN AUTHORITY SYSTEM
-- =====================================================================================
-- This migration adds an admin authority system with different permission levels.
-- Authority levels (from highest to lowest):
-- 1. super_admin - Full access to everything
-- 2. admin - Full access except system settings
-- 3. manager - Can manage orders, users, drivers, merchants, view reports
-- 4. support - Can view orders, update order status, send messages, view users
-- 5. viewer - Read-only access to orders and basic information
-- =====================================================================================

-- Add admin_authority column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_authority TEXT 
  CHECK (admin_authority IS NULL OR admin_authority IN ('super_admin', 'admin', 'manager', 'support', 'viewer'));

-- Add comment
COMMENT ON COLUMN users.admin_authority IS 'Admin authority level: super_admin (full access), admin (full except system settings), manager (manage orders/users/drivers/merchants), support (view/update orders, messages), viewer (read-only)';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_admin_authority ON users(admin_authority) WHERE admin_authority IS NOT NULL;

-- Update existing admin users to have admin authority (default to 'viewer' level)
-- Note: This will be overridden by the later migration 20250116000000 to set default to 'viewer'
UPDATE users 
SET admin_authority = 'viewer' 
WHERE role = 'admin' AND admin_authority IS NULL;

-- Function to check if user has required authority level
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

-- Function to get user admin authority level
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION has_admin_authority(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_admin_authority(UUID) TO authenticated, anon;

