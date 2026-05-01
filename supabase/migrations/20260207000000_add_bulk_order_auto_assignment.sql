-- Migration: Add auto-assignment for bulk orders
-- Automatically assigns drivers to bulk orders when they are created, similar to regular orders

-- =====================================================================================
-- 1. FUNCTION: Auto-Assign Bulk Order to Driver
-- Automatically assigns bulk order to next available driver
-- =====================================================================================
CREATE OR REPLACE FUNCTION auto_assign_bulk_order(p_bulk_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_lat DOUBLE PRECISION;
  v_pickup_lng DOUBLE PRECISION;
  v_bulk_order_status TEXT;
  v_vehicle_type TEXT;
BEGIN
  -- Get bulk order details
  SELECT status, pickup_latitude, pickup_longitude, vehicle_type
  INTO v_bulk_order_status, v_pickup_lat, v_pickup_lng, v_vehicle_type
  FROM bulk_orders
  WHERE id = p_bulk_order_id;
  
  -- Only assign if bulk order is pending and has no driver
  IF v_bulk_order_status != 'pending' THEN
    RAISE NOTICE 'Bulk order % is not pending (status: %)', p_bulk_order_id, v_bulk_order_status;
    RETURN FALSE;
  END IF;
  
  -- Check if bulk order already has a driver assigned
  IF EXISTS (
    SELECT 1 FROM bulk_orders 
    WHERE id = p_bulk_order_id AND driver_id IS NOT NULL
  ) THEN
    RAISE NOTICE 'Bulk order % already has a driver assigned', p_bulk_order_id;
    RETURN FALSE;
  END IF;
  
  -- Find next available driver using the same logic as regular orders
  -- Use find_next_available_driver function (it returns UUID directly)
  IF EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'find_next_available_driver'
  ) THEN
    -- Use existing function (check if it supports vehicle_type parameter)
    BEGIN
      -- Try with vehicle type parameter first (4 parameters)
      v_driver_id := find_next_available_driver(
        p_bulk_order_id, 
        v_pickup_lat, 
        v_pickup_lng,
        v_vehicle_type
      );
    EXCEPTION WHEN OTHERS THEN
      -- Fallback: try without vehicle type (3 parameters)
      BEGIN
        v_driver_id := find_next_available_driver(
          p_bulk_order_id, 
          v_pickup_lat, 
          v_pickup_lng
        );
      EXCEPTION WHEN OTHERS THEN
        -- If both fail, use manual selection below
        v_driver_id := NULL;
      END;
    END;
  ELSE
    -- Manual driver selection (fallback if function doesn't exist)
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Driver doesn't have an active order
      AND u.id NOT IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('accepted', 'on_the_way', 'picked_up')
      )
      -- Driver doesn't have an active bulk order
      AND u.id NOT IN (
        SELECT driver_id 
        FROM bulk_orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('assigned', 'accepted', 'active')
      )
      -- Match vehicle type if specified (allow 'any' or NULL)
      AND (
        v_vehicle_type IS NULL 
        OR v_vehicle_type = 'any' 
        OR u.vehicle_type = v_vehicle_type
        OR u.vehicle_type IS NULL
      )
    ORDER BY 
      ST_Distance(
        ST_SetSRID(ST_MakePoint(v_pickup_lng, v_pickup_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
      ) ASC
    LIMIT 1;
  END IF;
  
  IF v_driver_id IS NULL THEN
    -- No available drivers - keep bulk order as pending (don't reject like regular orders)
    RAISE NOTICE 'No available drivers found for bulk order % (vehicle type: %)', 
      p_bulk_order_id, v_vehicle_type;
    RETURN FALSE;
  END IF;
  
  -- Assign bulk order to driver using the existing RPC function
  BEGIN
    PERFORM assign_driver_to_bulk_order(p_bulk_order_id, v_driver_id);
    
    RAISE NOTICE 'Assigned bulk order % (vehicle: %) to driver % at %', 
      p_bulk_order_id, v_vehicle_type, v_driver_id, NOW();
    RETURN TRUE;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error assigning bulk order % to driver %: %', 
      p_bulk_order_id, v_driver_id, SQLERRM;
    RETURN FALSE;
  END;
END;
$$;

COMMENT ON FUNCTION auto_assign_bulk_order(UUID) IS 
  'Automatically assigns a bulk order to the nearest available driver. Returns TRUE if assignment was successful, FALSE otherwise.';

-- =====================================================================================
-- 2. TRIGGER: Auto-Assign on Bulk Order Creation
-- Automatically assigns driver when bulk order is created
-- =====================================================================================
CREATE OR REPLACE FUNCTION trigger_auto_assign_bulk_order_on_create()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only auto-assign if bulk order is pending and has no driver
  IF NEW.status = 'pending' AND NEW.driver_id IS NULL THEN
    -- Call auto-assignment function
    PERFORM auto_assign_bulk_order(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger on bulk order insert
DROP TRIGGER IF EXISTS auto_assign_new_bulk_orders ON bulk_orders;
CREATE TRIGGER auto_assign_new_bulk_orders
  AFTER INSERT ON bulk_orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_auto_assign_bulk_order_on_create();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION auto_assign_bulk_order(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION trigger_auto_assign_bulk_order_on_create() TO authenticated, service_role;

