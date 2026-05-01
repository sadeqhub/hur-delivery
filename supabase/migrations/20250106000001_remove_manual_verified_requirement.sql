-- Remove manual_verified requirement from driver assignment
-- This allows unverified drivers to receive orders

-- Update the auto_assign_driver function to not require manual_verified
CREATE OR REPLACE FUNCTION auto_assign_driver(p_order_id UUID)
RETURNS UUID AS $$
DECLARE
  v_order RECORD;
  v_driver_id UUID;
  v_distance FLOAT;
BEGIN
  -- Get order details
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;
  
  -- Find nearest available driver
  SELECT u.id, 
         ST_Distance(
           ST_SetSRID(ST_MakePoint(v_order.pickup_longitude, v_order.pickup_latitude), 4326)::geography,
           ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
         ) as distance
  INTO v_driver_id, v_distance
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Driver hasn't rejected this order before
    AND NOT EXISTS (
      SELECT 1 FROM order_rejections 
      WHERE driver_id = u.id AND order_id = p_order_id
    )
    -- Driver doesn't have active orders
    AND NOT EXISTS (
      SELECT 1 FROM orders 
      WHERE driver_id = u.id 
      AND status IN ('assigned', 'accepted', 'on_the_way')
    )
    -- Match vehicle type if specified
    AND (v_order.vehicle_type IS NULL OR v_order.vehicle_type = 'any' OR u.vehicle_type = v_order.vehicle_type)
  ORDER BY distance ASC
  LIMIT 1;
  
  RETURN v_driver_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update find_nearest_driver function
CREATE OR REPLACE FUNCTION find_nearest_driver(
  p_latitude DECIMAL(10,8),
  p_longitude DECIMAL(11,8),
  p_vehicle_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  distance_meters FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) as distance
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Driver doesn't have active orders
    AND NOT EXISTS (
      SELECT 1 FROM orders 
      WHERE driver_id = u.id 
      AND status IN ('assigned', 'accepted', 'on_the_way')
    )
    -- Match vehicle type if specified
    AND (p_vehicle_type IS NULL OR p_vehicle_type = 'any' OR u.vehicle_type = p_vehicle_type)
  ORDER BY distance ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_available_drivers function
CREATE OR REPLACE FUNCTION get_available_drivers(
  p_latitude DECIMAL(10,8),
  p_longitude DECIMAL(11,8),
  p_vehicle_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  driver_phone TEXT,
  distance_meters FLOAT,
  is_online BOOLEAN,
  vehicle_type TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    u.phone,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) as distance,
    u.is_online,
    u.vehicle_type
  FROM users u
  WHERE u.role = 'driver'
    -- REMOVED: AND u.manual_verified = true
    AND u.is_active = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Match vehicle type if specified
    AND (p_vehicle_type IS NULL OR p_vehicle_type = 'any' OR u.vehicle_type = p_vehicle_type)
  ORDER BY 
    u.is_online DESC,
    distance ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update check_vehicle_availability function
CREATE OR REPLACE FUNCTION check_vehicle_availability(p_vehicle_type TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_driver_count INTEGER;
BEGIN
  -- For 'any' vehicle type, check if ANY driver is online
  IF p_vehicle_type = 'any' OR p_vehicle_type IS NULL THEN
    SELECT COUNT(*) INTO v_driver_count
    FROM users
    WHERE role = 'driver'
      AND is_online = true;
      -- REMOVED: AND manual_verified = true;
    
    RAISE NOTICE 'Vehicle type "any" availability check: % drivers online', v_driver_count;
    RETURN v_driver_count > 0;
  END IF;
  
  -- For specific vehicle type
  SELECT COUNT(*) INTO v_driver_count
  FROM users
  WHERE role = 'driver'
    AND is_online = true
    -- REMOVED: AND manual_verified = true
    AND vehicle_type = p_vehicle_type;
  
  RAISE NOTICE 'Vehicle type "%" availability check: % drivers online', p_vehicle_type, v_driver_count;
  RETURN v_driver_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment
COMMENT ON FUNCTION auto_assign_driver(UUID) IS 'Auto-assigns nearest available driver to order (no verification required)';
COMMENT ON FUNCTION find_nearest_driver(DECIMAL, DECIMAL, TEXT) IS 'Finds nearest available drivers (no verification required)';
COMMENT ON FUNCTION get_available_drivers(DECIMAL, DECIMAL, TEXT) IS 'Gets all available drivers sorted by distance (no verification required)';
COMMENT ON FUNCTION check_vehicle_availability(TEXT) IS 'Checks if drivers with specific vehicle type are available (no verification required)';

