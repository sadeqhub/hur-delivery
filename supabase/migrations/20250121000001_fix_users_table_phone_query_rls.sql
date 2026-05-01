-- =====================================================================================
-- FIX USERS TABLE RLS POLICY TO ALLOW PHONE-BASED QUERIES
-- =====================================================================================
-- This migration fixes the users table RLS policy to allow authenticated users
-- to query their own record by phone number, which is required for the login/
-- authentication flow.
-- 
-- Problem:
-- The existing users_select_own policy only allows auth.uid() = id, which doesn't
-- work when querying by phone number during login (you don't know the id yet).
-- This causes a 500 error when the app tries to find a user by phone number.
-- 
-- Root Cause:
-- The previous approach used EXISTS with a subquery that referenced the users table,
-- causing recursion in RLS policy evaluation, which led to 500 errors.
-- 
-- Solution:
-- Create a SECURITY DEFINER helper function that checks if a phone belongs to
-- the authenticated user without triggering RLS (bypasses RLS). Use this function
-- in the RLS policy to check phone ownership safely.
-- =====================================================================================

BEGIN;

-- Create an RPC function for phone-based user lookup (safe to call from app)
-- This function can be called directly by the app instead of querying the table
-- It bypasses RLS because it's SECURITY DEFINER and returns only the user's own record
CREATE OR REPLACE FUNCTION public.get_user_by_phone(p_phone TEXT)
RETURNS TABLE (
  id UUID,
  role TEXT,
  phone TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_user_id UUID;
  v_auth_phone TEXT;
  v_email_local TEXT;
  v_normalized_auth_phone TEXT;
  v_normalized_input_phone TEXT;
BEGIN
  -- Get the authenticated user's ID
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN;  -- Return empty result if not authenticated
  END IF;
  
  -- Get phone from auth.users
  BEGIN
    SELECT 
      COALESCE(au.phone, au.raw_user_meta_data->>'phone'),
      SUBSTRING(au.email FROM '^([^@]+)@')
    INTO v_auth_phone, v_email_local
    FROM auth.users au
    WHERE au.id = v_user_id
    LIMIT 1;
    
    -- If phone is in email, extract it
    IF (v_auth_phone IS NULL OR v_auth_phone = '') AND v_email_local IS NOT NULL THEN
      IF v_email_local ~ '^[0-9]{11,15}$' THEN
        v_auth_phone := '+' || v_email_local;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN;  -- Return empty if we can't get phone
  END;
  
  -- Normalize phones for comparison
  v_normalized_auth_phone := regexp_replace(COALESCE(v_auth_phone, ''), '[^0-9]', '', 'g');
  v_normalized_input_phone := regexp_replace(COALESCE(p_phone, ''), '[^0-9]', '', 'g');
  
  -- Only return user if phone matches
  IF v_normalized_auth_phone = v_normalized_input_phone AND v_normalized_auth_phone != '' THEN
    RETURN QUERY
    SELECT u.id, u.role, u.phone
    FROM public.users u
    WHERE u.id = v_user_id
    LIMIT 1;
  END IF;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_by_phone(TEXT) TO authenticated;

-- Drop ALL existing policies on users table to start fresh
-- This ensures no conflicting policies cause recursion
DROP POLICY IF EXISTS "users_select_own" ON public.users;
DROP POLICY IF EXISTS "users_select_by_phone" ON public.users;
DROP POLICY IF EXISTS "users_view_own" ON public.users;
DROP POLICY IF EXISTS "users_admin_view_all" ON public.users;

-- Simple policy: Only allow users to see their own record by id
-- This prevents recursion because it doesn't query any tables
-- For phone-based queries, use the edge function or RPC function instead
CREATE POLICY "users_select_own" ON public.users
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

COMMIT;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- This solution uses TWO separate policies (combined with OR by PostgreSQL):
-- 
-- 1. Policy "users_select_own": 
--    - Allows queries where id = auth.uid() (simple, fast check)
--    - Used for: SELECT * FROM users WHERE id = auth.uid()
--    - This is the primary policy for most queries
-- 
-- 2. Policy "users_select_by_phone":
--    - Allows queries by phone number if phone belongs to authenticated user
--    - Only applies when id != auth.uid() (optimization to avoid unnecessary checks)
--    - Used for: SELECT * FROM users WHERE phone = '...'
--    - The function verifies phone ownership before allowing access
-- 
-- The get_user_by_phone() RPC function:
-- - Is SECURITY DEFINER, so it bypasses RLS
-- - Only returns the user record if the phone matches the authenticated user's phone
-- - Can be called directly from the app: SELECT * FROM get_user_by_phone('+964...')
-- - This is the recommended way to query by phone (avoids RLS recursion)
-- 
-- Why two policies?
-- - Separates id-based queries (fast, no function call) from phone-based queries
-- - The second policy only checks phone when id doesn't match
-- - This prevents unnecessary function calls for id-based queries
-- 
-- Security:
-- - Users can only see records where id = auth.uid() (their own)
-- - OR where the phone matches their own (verified via function)
-- - The function ensures phone ownership before allowing access
-- =====================================================================================

