-- Update bulk order status flow to match regular orders
-- Status flow: pending -> accepted -> picked_up -> on_the_way -> delivered
-- Remove: assigned, active (replace with regular order statuses)

-- Update status constraint to match regular orders
ALTER TABLE bulk_orders
DROP CONSTRAINT IF EXISTS bulk_orders_status_check;

ALTER TABLE bulk_orders
ADD CONSTRAINT bulk_orders_status_check
CHECK (
  status IN ('draft', 'pending', 'accepted', 'picked_up', 'on_the_way', 'delivered', 'cancelled', 'rejected', 'posting')
);

-- Update assign_driver_to_bulk_order function to set status to 'pending' (not 'assigned')
CREATE OR REPLACE FUNCTION assign_driver_to_bulk_order(
  p_bulk_order_id UUID,
  p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_bulk_order RECORD;
BEGIN
  -- Get bulk order
  SELECT * INTO v_bulk_order
  FROM bulk_orders
  WHERE id = p_bulk_order_id;
  
  IF v_bulk_order IS NULL THEN
    RAISE EXCEPTION 'Bulk order not found: %', p_bulk_order_id;
  END IF;
  
  -- Check if driver exists and is a driver
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = p_driver_id
    AND role = 'driver'
    AND is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'Invalid driver: %', p_driver_id;
  END IF;
  
  -- Check if bulk order is in valid state for assignment
  IF v_bulk_order.status NOT IN ('pending', 'draft') THEN
    RAISE EXCEPTION 'Bulk order is not in a state that allows assignment. Current status: %', v_bulk_order.status;
  END IF;
  
  -- Assign driver but keep status as 'pending' (driver needs to accept)
  UPDATE bulk_orders
  SET driver_id = p_driver_id,
      status = 'pending', -- Keep as pending until driver accepts
      assigned_at = NOW(),
      updated_at = NOW()
  WHERE id = p_bulk_order_id;
  
  RETURN TRUE;
END;
$$;

-- Update accept_bulk_order function to set status to 'accepted' (not 'active')
CREATE OR REPLACE FUNCTION accept_bulk_order(
  p_bulk_order_id UUID,
  p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_bulk_order RECORD;
BEGIN
  -- Get bulk order
  SELECT * INTO v_bulk_order
  FROM bulk_orders
  WHERE id = p_bulk_order_id;
  
  IF v_bulk_order IS NULL THEN
    RAISE EXCEPTION 'Bulk order not found: %', p_bulk_order_id;
  END IF;
  
  -- Verify driver is assigned to this bulk order
  IF v_bulk_order.driver_id != p_driver_id THEN
    RAISE EXCEPTION 'Driver % is not assigned to bulk order %', p_driver_id, p_bulk_order_id;
  END IF;
  
  -- Check if bulk order is in valid state for acceptance
  IF v_bulk_order.status != 'pending' THEN
    RAISE EXCEPTION 'Bulk order is not in pending state. Current status: %', v_bulk_order.status;
  END IF;
  
  -- Accept bulk order - set status to 'accepted'
  UPDATE bulk_orders
  SET status = 'accepted',
      accepted_at = NOW(),
      updated_at = NOW()
  WHERE id = p_bulk_order_id;
  
  RETURN TRUE;
END;
$$;

-- Add columns for picked_up_at and delivered_at if they don't exist
ALTER TABLE bulk_orders
ADD COLUMN IF NOT EXISTS picked_up_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

-- Add comments
COMMENT ON COLUMN bulk_orders.status IS 'Status: pending (assigned to driver), accepted (driver accepted), picked_up (driver picked up), on_the_way (delivering), delivered (completed)';
COMMENT ON COLUMN bulk_orders.picked_up_at IS 'Timestamp when driver marked bulk order as picked up';
COMMENT ON COLUMN bulk_orders.delivered_at IS 'Timestamp when bulk order was completed/delivered';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION assign_driver_to_bulk_order(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION accept_bulk_order(UUID, UUID) TO authenticated, service_role;

