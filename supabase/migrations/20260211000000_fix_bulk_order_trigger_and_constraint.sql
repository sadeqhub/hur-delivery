-- Fix bulk order status constraint and remove conflicting triggers
-- The old trigger was setting status to 'active' which is no longer valid

-- Drop the old trigger that sets status to 'active'
DROP TRIGGER IF EXISTS trigger_activate_bulk_order ON bulk_orders;
DROP FUNCTION IF EXISTS check_and_activate_bulk_order();

-- Also drop the function that activates bulk orders for today (no longer needed)
DROP FUNCTION IF EXISTS activate_bulk_orders_for_today();

-- Ensure the status constraint includes all valid statuses (double-check)
ALTER TABLE bulk_orders
DROP CONSTRAINT IF EXISTS bulk_orders_status_check;

ALTER TABLE bulk_orders
ADD CONSTRAINT bulk_orders_status_check
CHECK (
  status IN ('draft', 'pending', 'accepted', 'picked_up', 'on_the_way', 'delivered', 'cancelled', 'rejected', 'posting')
);

-- Verify that 'active' is NOT in the constraint (it should fail if we try to add it)
-- The constraint above explicitly excludes 'active' to match the new status flow

COMMENT ON CONSTRAINT bulk_orders_status_check ON bulk_orders IS 
  'Status flow: pending -> accepted -> picked_up -> on_the_way -> delivered. Old statuses (assigned, active) are no longer valid.';

