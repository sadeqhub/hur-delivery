-- Add RLS policies for bulk_orders table
-- This allows drivers to view and update bulk orders assigned to them
-- Similar to the orders table RLS policies

-- Enable RLS on bulk_orders if not already enabled
ALTER TABLE bulk_orders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "bulk_orders_merchant_view_own" ON bulk_orders;
DROP POLICY IF EXISTS "bulk_orders_merchant_create" ON bulk_orders;
DROP POLICY IF EXISTS "bulk_orders_merchant_update_own" ON bulk_orders;
DROP POLICY IF EXISTS "bulk_orders_driver_view_assigned_or_pending" ON bulk_orders;
DROP POLICY IF EXISTS "bulk_orders_driver_update_assigned" ON bulk_orders;
DROP POLICY IF EXISTS "bulk_orders_admin_view_all" ON bulk_orders;
DROP POLICY IF EXISTS "bulk_orders_system_update" ON bulk_orders;

-- -----------------------------------------------------------------------------
-- Merchants can view their own bulk orders
-- -----------------------------------------------------------------------------
CREATE POLICY "bulk_orders_merchant_view_own" ON bulk_orders
  FOR SELECT
  USING (merchant_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Merchants can create bulk orders
-- -----------------------------------------------------------------------------
CREATE POLICY "bulk_orders_merchant_create" ON bulk_orders
  FOR INSERT
  WITH CHECK (merchant_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Merchants can update their own bulk orders (cancel, etc.)
-- -----------------------------------------------------------------------------
CREATE POLICY "bulk_orders_merchant_update_own" ON bulk_orders
  FOR UPDATE
  USING (merchant_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Drivers can view bulk orders assigned to them or pending bulk orders
-- -----------------------------------------------------------------------------
CREATE POLICY "bulk_orders_driver_view_assigned_or_pending" ON bulk_orders
  FOR SELECT
  USING (
    driver_id = auth.uid() OR
    (status = 'pending' AND EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'driver' AND is_online = TRUE AND manual_verified = TRUE
    ))
  );

-- -----------------------------------------------------------------------------
-- Drivers can update bulk orders assigned to them
-- This allows drivers to:
-- - Accept bulk orders (status: pending -> accepted)
-- - Mark as picked up (status: accepted -> picked_up)
-- - Mark as on the way (status: picked_up -> on_the_way)
-- - Mark as delivered (status: on_the_way -> delivered)
-- -----------------------------------------------------------------------------
CREATE POLICY "bulk_orders_driver_update_assigned" ON bulk_orders
  FOR UPDATE
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Admins can view all bulk orders
-- -----------------------------------------------------------------------------
CREATE POLICY "bulk_orders_admin_view_all" ON bulk_orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- -----------------------------------------------------------------------------
-- System functions can update bulk orders (for auto-assignment)
-- This is needed for the auto-assignment trigger to work
-- -----------------------------------------------------------------------------
CREATE POLICY "bulk_orders_system_update" ON bulk_orders
  FOR UPDATE
  TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON bulk_orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON bulk_orders TO service_role;

COMMENT ON POLICY "bulk_orders_driver_view_assigned_or_pending" ON bulk_orders IS 
  'Allows drivers to view bulk orders assigned to them or pending bulk orders (if they are online and verified)';

COMMENT ON POLICY "bulk_orders_driver_update_assigned" ON bulk_orders IS 
  'Allows drivers to update bulk orders assigned to them (accept, mark as picked up, on the way, or delivered)';

