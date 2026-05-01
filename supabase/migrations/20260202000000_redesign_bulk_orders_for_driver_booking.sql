-- Redesign bulk orders to be "driver booking" for the entire day
-- Instead of multiple individual orders, merchants book a driver for the day
-- with specified neighborhoods and per-delivery fee

-- Add new columns to bulk_orders table
ALTER TABLE bulk_orders
ADD COLUMN IF NOT EXISTS neighborhoods TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS per_delivery_fee DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS bulk_order_fee DECIMAL(10,2) DEFAULT 1500.00,
ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS order_date DATE DEFAULT CURRENT_DATE;

-- Add constraint to ensure at least 3 neighborhoods
ALTER TABLE bulk_orders
DROP CONSTRAINT IF EXISTS bulk_orders_min_neighborhoods;

ALTER TABLE bulk_orders
ADD CONSTRAINT bulk_orders_min_neighborhoods
CHECK (array_length(neighborhoods, 1) >= 3);

-- Add index for driver queries
CREATE INDEX IF NOT EXISTS idx_bulk_orders_driver ON bulk_orders(driver_id) WHERE driver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bulk_orders_status ON bulk_orders(status);
CREATE INDEX IF NOT EXISTS idx_bulk_orders_date ON bulk_orders(order_date);

-- Update status to include new states
-- Status can be: 'draft', 'pending', 'assigned', 'accepted', 'active', 'completed', 'cancelled'
-- Note: We'll need to update the constraint if it exists, but for now we'll just document it

-- Add comment explaining the new structure
COMMENT ON COLUMN bulk_orders.neighborhoods IS 'Array of at least 3 neighborhood names where the driver will make deliveries';
COMMENT ON COLUMN bulk_orders.per_delivery_fee IS 'Fixed fee for each delivery made by the driver';
COMMENT ON COLUMN bulk_orders.bulk_order_fee IS 'Fixed fee (1500 IQD) for booking the driver for the day';
COMMENT ON COLUMN bulk_orders.driver_id IS 'Driver assigned to this bulk order';
COMMENT ON COLUMN bulk_orders.order_date IS 'Date for which the driver is booked';

-- Create function to assign driver to bulk order
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
  
  -- Assign driver
  UPDATE bulk_orders
  SET driver_id = p_driver_id,
      status = 'assigned',
      assigned_at = NOW(),
      updated_at = NOW()
  WHERE id = p_bulk_order_id;
  
  RETURN TRUE;
END;
$$;

-- Create function for driver to accept bulk order
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
  IF v_bulk_order.status != 'assigned' THEN
    RAISE EXCEPTION 'Bulk order is not in assigned state. Current status: %', v_bulk_order.status;
  END IF;
  
  -- Accept bulk order
  -- If order_date is today or in the past, set status to 'active' immediately
  -- Otherwise, set status to 'accepted' (will be activated on order_date)
  UPDATE bulk_orders
  SET status = CASE 
      WHEN order_date <= CURRENT_DATE THEN 'active'
      ELSE 'accepted'
    END,
      accepted_at = NOW(),
      updated_at = NOW()
  WHERE id = p_bulk_order_id;
  
  RETURN TRUE;
END;
$$;

-- Create function to automatically activate bulk orders on their order_date
-- This function should be called daily (via pg_cron or similar) to transition
-- accepted bulk orders to active status when their order_date arrives
CREATE OR REPLACE FUNCTION activate_bulk_orders_for_today()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated_count INTEGER;
BEGIN
  -- Update bulk orders from 'accepted' to 'active' where order_date is today
  UPDATE bulk_orders
  SET status = 'active',
      updated_at = NOW()
  WHERE status = 'accepted'
    AND order_date = CURRENT_DATE
    AND driver_id IS NOT NULL; -- Only activate if driver is assigned
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  RAISE NOTICE 'Activated % bulk order(s) for today', v_updated_count;
  
  RETURN v_updated_count;
END;
$$;

COMMENT ON FUNCTION activate_bulk_orders_for_today() IS 
  'Automatically transitions accepted bulk orders to active status when their order_date arrives. Should be called daily.';

-- Create a trigger function that automatically activates bulk orders when order_date is reached
-- This provides immediate activation without waiting for a scheduled job
CREATE OR REPLACE FUNCTION check_and_activate_bulk_order()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- If bulk order is accepted and order_date is today or in the past, activate it
  IF NEW.status = 'accepted' 
     AND NEW.order_date <= CURRENT_DATE 
     AND NEW.driver_id IS NOT NULL THEN
    NEW.status := 'active';
    NEW.updated_at := NOW();
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to check on insert/update
DROP TRIGGER IF EXISTS trigger_activate_bulk_order ON bulk_orders;
CREATE TRIGGER trigger_activate_bulk_order
  BEFORE INSERT OR UPDATE ON bulk_orders
  FOR EACH ROW
  EXECUTE FUNCTION check_and_activate_bulk_order();

