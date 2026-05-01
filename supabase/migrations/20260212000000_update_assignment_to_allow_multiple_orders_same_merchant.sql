-- 20260212000000_update_assignment_to_allow_multiple_orders_same_merchant.sql
-- Update find_next_available_driver to allow drivers to receive multiple orders
-- from the same merchant, while still preferring free drivers

BEGIN;

-- Update the 3-parameter version (without vehicle_type)
CREATE OR REPLACE FUNCTION find_next_available_driver(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_point GEOGRAPHY;
  v_merchant_id UUID;
BEGIN
  -- Get merchant_id for the order
  SELECT merchant_id INTO v_merchant_id
  FROM orders
  WHERE id = p_order_id;
  
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  -- TIER 1: Try to find driver with NO active orders at all (completely free)
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Driver hasn't rejected this order before
    AND u.id NOT IN (
      SELECT driver_id 
      FROM order_rejected_drivers 
      WHERE order_id = p_order_id
    )
    -- Driver has NO active orders at all (completely free)
    AND u.id NOT IN (
      SELECT driver_id 
      FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('pending', 'accepted', 'on_the_way')
    )
  ORDER BY ST_Distance(
    v_pickup_point,
    ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
  ) ASC
  LIMIT 1;
  
  -- TIER 2: If no completely free driver found, try drivers with only pending orders
  IF v_driver_id IS NULL THEN
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Driver hasn't rejected this order before
      AND u.id NOT IN (
        SELECT driver_id 
        FROM order_rejected_drivers 
        WHERE order_id = p_order_id
      )
      -- Driver doesn't have accepted/on_the_way orders (but may have pending)
      AND u.id NOT IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('accepted', 'on_the_way')
      )
    ORDER BY ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) ASC
    LIMIT 1;
  END IF;
  
  -- TIER 3: If still no driver found, allow drivers who already have orders from the SAME merchant
  -- This allows a single driver to handle multiple orders from the same merchant
  IF v_driver_id IS NULL AND v_merchant_id IS NOT NULL THEN
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Driver hasn't rejected this order before
      AND u.id NOT IN (
        SELECT driver_id 
        FROM order_rejected_drivers 
        WHERE order_id = p_order_id
      )
      -- Driver has active orders, but ONLY from the same merchant
      AND u.id IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('pending', 'accepted', 'on_the_way')
          AND merchant_id = v_merchant_id
      )
      -- Driver does NOT have active orders from other merchants
      AND u.id NOT IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('pending', 'accepted', 'on_the_way')
          AND merchant_id != v_merchant_id
      )
    ORDER BY ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) ASC
    LIMIT 1;
  END IF;
  
  RETURN v_driver_id;
END;
$$;

-- Update the 4-parameter version (with vehicle_type filter)
CREATE OR REPLACE FUNCTION find_next_available_driver(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION,
  p_vehicle_type TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_point GEOGRAPHY;
  v_required_vehicle TEXT;
  v_merchant_id UUID;
BEGIN
  -- Get merchant_id for the order
  SELECT merchant_id INTO v_merchant_id
  FROM orders
  WHERE id = p_order_id;
  
  -- Normalize vehicle type (motorbike -> motorcycle)
  v_required_vehicle := CASE 
    WHEN p_vehicle_type = 'motorbike' THEN 'motorcycle'
    ELSE p_vehicle_type
  END;
  
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  -- TIER 1: Try to find driver with NO active orders at all (completely free)
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Vehicle type compatibility check
    AND (
      v_required_vehicle IS NULL 
      OR v_required_vehicle = 'any'
      OR u.vehicle_type IS NULL 
      OR u.vehicle_type = v_required_vehicle
      OR u.vehicle_type = 'motorbike' AND v_required_vehicle = 'motorcycle'
      OR u.vehicle_type = 'motorcycle' AND v_required_vehicle = 'motorbike'
    )
    -- Driver hasn't rejected this order before
    AND u.id NOT IN (
      SELECT driver_id 
      FROM order_rejected_drivers 
      WHERE order_id = p_order_id
    )
    -- Driver has NO active orders at all (completely free)
    AND u.id NOT IN (
      SELECT driver_id 
      FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('pending', 'accepted', 'on_the_way')
    )
  ORDER BY ST_Distance(
    v_pickup_point,
    ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
  ) ASC
  LIMIT 1;
  
  -- TIER 2: If no completely free driver found, try drivers with only pending orders
  IF v_driver_id IS NULL THEN
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Vehicle type compatibility check
      AND (
        v_required_vehicle IS NULL 
        OR v_required_vehicle = 'any'
        OR u.vehicle_type IS NULL 
        OR u.vehicle_type = v_required_vehicle
        OR u.vehicle_type = 'motorbike' AND v_required_vehicle = 'motorcycle'
        OR u.vehicle_type = 'motorcycle' AND v_required_vehicle = 'motorbike'
      )
      -- Driver hasn't rejected this order before
      AND u.id NOT IN (
        SELECT driver_id 
        FROM order_rejected_drivers 
        WHERE order_id = p_order_id
      )
      -- Driver doesn't have accepted/on_the_way orders (but may have pending)
      AND u.id NOT IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('accepted', 'on_the_way')
      )
    ORDER BY ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) ASC
    LIMIT 1;
  END IF;
  
  -- TIER 3: If still no driver found, allow drivers who already have orders from the SAME merchant
  -- This allows a single driver to handle multiple orders from the same merchant
  IF v_driver_id IS NULL AND v_merchant_id IS NOT NULL THEN
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Vehicle type compatibility check
      AND (
        v_required_vehicle IS NULL 
        OR v_required_vehicle = 'any'
        OR u.vehicle_type IS NULL 
        OR u.vehicle_type = v_required_vehicle
        OR u.vehicle_type = 'motorbike' AND v_required_vehicle = 'motorcycle'
        OR u.vehicle_type = 'motorcycle' AND v_required_vehicle = 'motorbike'
      )
      -- Driver hasn't rejected this order before
      AND u.id NOT IN (
        SELECT driver_id 
        FROM order_rejected_drivers 
        WHERE order_id = p_order_id
      )
      -- Driver has active orders, but ONLY from the same merchant
      AND u.id IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('pending', 'accepted', 'on_the_way')
          AND merchant_id = v_merchant_id
      )
      -- Driver does NOT have active orders from other merchants
      AND u.id NOT IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('pending', 'accepted', 'on_the_way')
          AND merchant_id != v_merchant_id
      )
    ORDER BY ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) ASC
    LIMIT 1;
  END IF;
  
  RETURN v_driver_id;
END;
$$;

COMMIT;

