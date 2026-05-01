-- =====================================================================================
-- FIX ORDERS TABLE MERCHANT INSERT POLICY
-- =====================================================================================
-- This migration ensures merchants can create orders by verifying/recreating
-- the orders_merchant_create RLS policy and fixing order_items policies.
-- 
-- Problem:
-- Merchants are getting 403 errors when trying to POST (create) orders.
-- Possible causes:
-- 1. The orders_merchant_create policy might be missing
-- 2. The order_items_merchant_create policy might have recursion issues
-- 3. Policies might have been dropped accidentally
-- 
-- Solution:
-- Drop and recreate all necessary policies to ensure they exist and work correctly.
-- =====================================================================================

BEGIN;

-- =====================================================================================
-- 1. FIX ORDERS TABLE INSERT POLICY
-- =====================================================================================

-- Drop and recreate the merchant insert policy
DROP POLICY IF EXISTS "orders_merchant_create" ON public.orders;

-- Allow merchants to create orders where merchant_id matches their auth.uid()
-- This is safe because merchants can only create orders for themselves
CREATE POLICY "orders_merchant_create" ON public.orders
  FOR INSERT
  TO authenticated
  WITH CHECK (merchant_id = auth.uid());

-- =====================================================================================
-- 2. FIX ORDER_ITEMS TABLE INSERT POLICY (might have recursion issues)
-- =====================================================================================

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "order_items_merchant_create" ON public.order_items;

-- Recreate the policy - this checks if the order exists and belongs to the merchant
-- Note: This uses EXISTS which queries orders table, but it's safe because:
-- 1. The order must already exist (inserted in same transaction)
-- 2. We're only checking ownership, not creating a recursive loop
-- 3. The check happens AFTER the order is inserted, so it should work
CREATE POLICY "order_items_merchant_create" ON public.order_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders 
      WHERE id = order_items.order_id 
      AND merchant_id = auth.uid()
    )
  );

-- =====================================================================================
-- 3. VERIFY POLICIES WERE CREATED
-- =====================================================================================

DO $$
DECLARE
  orders_policy_exists BOOLEAN;
  items_policy_exists BOOLEAN;
BEGIN
  -- Check orders policy
  SELECT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename = 'orders'
    AND policyname = 'orders_merchant_create'
  ) INTO orders_policy_exists;
  
  -- Check order_items policy
  SELECT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename = 'order_items'
    AND policyname = 'order_items_merchant_create'
  ) INTO items_policy_exists;
  
  IF NOT orders_policy_exists THEN
    RAISE EXCEPTION 'Failed to create orders_merchant_create policy';
  ELSE
    RAISE NOTICE '✅ orders_merchant_create policy created successfully';
  END IF;
  
  IF NOT items_policy_exists THEN
    RAISE EXCEPTION 'Failed to create order_items_merchant_create policy';
  ELSE
    RAISE NOTICE '✅ order_items_merchant_create policy created successfully';
  END IF;
END $$;

-- =====================================================================================
-- 4. FIX AUDIT_LOG TRIGGER FUNCTION
-- =====================================================================================
-- The trigger_audit_log() function needs to be SECURITY DEFINER to bypass RLS
-- when inserting into audit_log. Currently it runs as the current user, which causes
-- RLS violations when merchants create orders.
-- =====================================================================================

-- Make trigger_audit_log SECURITY DEFINER so it can bypass RLS
CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  INSERT INTO audit_log (
    user_id, action, entity_type, entity_id, old_data, new_data
  )
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE NULL END,
    CASE WHEN TG_OP != 'DELETE' THEN row_to_json(NEW) ELSE NULL END
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- =====================================================================================
-- 5. ADD AUDIT_LOG INSERT POLICY FOR AUTHENTICATED USERS (backup if SECURITY DEFINER fails)
-- =====================================================================================
-- Even though trigger_audit_log is now SECURITY DEFINER, we should also have a policy
-- that allows authenticated users to insert audit log entries (via triggers)
-- This is safe because triggers control what gets inserted
-- =====================================================================================

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "audit_log_authenticated_insert" ON public.audit_log;

-- Allow authenticated users to insert audit log entries (via triggers)
-- This is safe because the trigger function controls what gets inserted
CREATE POLICY "audit_log_authenticated_insert" ON public.audit_log
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- =====================================================================================
-- 6. FIX validate_driver_availability_for_merchant FUNCTION (if it has issues)
-- =====================================================================================
-- Ensure the function is correctly defined with SECURITY DEFINER if it queries users table
-- This might not be the source of the error, but let's make sure it's correct
-- =====================================================================================

-- Recreate the function to ensure it's correct and has SECURITY DEFINER
-- This function is used by the order creation flow to check driver availability
-- FIX: The CTEs must be used in a single statement - CTEs are only visible to the next statement
CREATE OR REPLACE FUNCTION public.validate_driver_availability_for_merchant(
  p_vehicle_type text,
  p_merchant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_vehicle_type text := nullif(trim(coalesce(p_vehicle_type, '')), '');
  v_free_count int := 0;
  v_same_merchant_count int := 0;
BEGIN
  -- Use CTEs in a single statement so both counts can be calculated
  WITH online_drivers AS (
    SELECT u.id
    FROM public.users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND (v_vehicle_type IS NULL OR u.vehicle_type = v_vehicle_type)
  ),
  active_orders AS (
    SELECT o.driver_id, o.merchant_id
    FROM public.orders o
    WHERE o.driver_id IS NOT NULL
      AND o.status IN ('pending', 'assigned', 'accepted', 'on_the_way')
  ),
  free_driver_candidates AS (
    SELECT d.id
    FROM online_drivers d
    LEFT JOIN active_orders ao ON ao.driver_id = d.id
    WHERE ao.driver_id IS NULL
  ),
  same_merchant_drivers AS (
    SELECT ao.driver_id
    FROM active_orders ao
    JOIN online_drivers d ON d.id = ao.driver_id
    GROUP BY ao.driver_id
    HAVING count(*) FILTER (WHERE ao.merchant_id = p_merchant_id) > 0
       AND count(*) = count(*) FILTER (WHERE ao.merchant_id = p_merchant_id)
  )
  SELECT 
    (SELECT count(*) FROM free_driver_candidates),
    (SELECT count(*) FROM same_merchant_drivers)
  INTO v_free_count, v_same_merchant_count;

  IF v_free_count > 0 THEN
    RETURN jsonb_build_object(
      'available', true,
      'reason', 'free_driver_available',
      'free_driver_count', v_free_count,
      'same_merchant_driver_count', v_same_merchant_count
    );
  ELSIF v_same_merchant_count > 0 THEN
    RETURN jsonb_build_object(
      'available', true,
      'reason', 'same_merchant_driver_available',
      'free_driver_count', v_free_count,
      'same_merchant_driver_count', v_same_merchant_count
    );
  ELSE
    RETURN jsonb_build_object(
      'available', false,
      'reason', 'no_driver_available',
      'free_driver_count', v_free_count,
      'same_merchant_driver_count', v_same_merchant_count
    );
  END IF;
END;
$$;

COMMENT ON FUNCTION public.validate_driver_availability_for_merchant(text, uuid) IS 
  'Checks driver availability considering vehicle type, free drivers, and multi-assignment rules for the same merchant.';

COMMIT;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- This migration fixes multiple issues:
-- 
-- 1. ORDERS INSERT POLICY:
--    - Allows authenticated users to insert orders where merchant_id = auth.uid()
--    - Merchants can only create orders for themselves
-- 
-- 2. ORDER_ITEMS INSERT POLICY:
--    - Allows authenticated users to insert order items for their own orders
--    - Uses EXISTS to verify order ownership (safe, non-recursive)
-- 
-- 3. AUDIT_LOG TRIGGER FUNCTION:
--    - Made SECURITY DEFINER so it can bypass RLS when inserting audit log entries
--    - Added search_path security setting to prevent injection attacks
--    - This fixes the "new row violates row-level security policy for table audit_log" error
-- 
-- 4. AUDIT_LOG INSERT POLICY:
--    - Added backup policy for authenticated users (even though SECURITY DEFINER should work)
--    - Only allows users to insert audit entries with their own user_id
-- 
-- IMPORTANT: When an order is inserted, triggers may fire:
-- - trigger_audit_log() (AFTER INSERT) - now SECURITY DEFINER, bypasses RLS
-- - trigger_auto_assign_on_create() (AFTER INSERT) - SECURITY DEFINER, bypasses RLS
-- - track_driver_assignment_on_insert_trigger (BEFORE INSERT) -  just sets timestamps
-- 
-- If merchants still get 403 errors after this migration:
-- 1. Verify the policy exists: SELECT * FROM pg_policies WHERE tablename = 'orders' AND policyname = 'orders_merchant_create';
-- 2. Check if RLS is enabled: SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'orders';
-- 3. Verify the user is authenticated and merchant_id matches auth.uid() in the INSERT
-- 4. Check if audit_log trigger is working: Look for audit_log RLS errors in logs
-- =====================================================================================

