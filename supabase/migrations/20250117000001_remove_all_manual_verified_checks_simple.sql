-- =====================================================================================
-- CREATE UPDATED FUNCTIONS WITHOUT manual_verified CHECKS (SIMPLE VERSION)
-- =====================================================================================
-- NOTE: Run migration 20250117000002_drop_manual_verified_functions.sql FIRST
-- This creates functions one at a time with unique dollar-quote tags
-- =====================================================================================

-- 1. Create 3-parameter version of find_next_available_driver
CREATE FUNCTION find_next_available_driver(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn1$
DECLARE
  v_driver_id UUID;
  v_pickup_point GEOGRAPHY;
BEGIN
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    AND u.id NOT IN (
      SELECT driver_id FROM order_rejected_drivers WHERE order_id = p_order_id
    )
    AND u.id NOT IN (
      SELECT driver_id FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('pending', 'accepted', 'on_the_way')
    )
  ORDER BY ST_Distance(
    v_pickup_point,
    ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
  ) ASC
  LIMIT 1;
  
  IF v_driver_id IS NULL THEN
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      AND u.id NOT IN (
        SELECT driver_id FROM order_rejected_drivers WHERE order_id = p_order_id
      )
      AND u.id NOT IN (
        SELECT driver_id FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('accepted', 'on_the_way')
      )
    ORDER BY ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) ASC
    LIMIT 1;
  END IF;
  
  RETURN v_driver_id;
END;
$fn1$;

-- 2. Create 4-parameter version of find_next_available_driver (overload)
CREATE FUNCTION find_next_available_driver(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION,
  p_vehicle_type TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn2$
DECLARE
  v_driver_id UUID;
  v_pickup_point GEOGRAPHY;
  v_required_vehicle TEXT;
BEGIN
  v_required_vehicle := CASE 
    WHEN p_vehicle_type = 'motorbike' THEN 'motorcycle'
    ELSE p_vehicle_type
  END;
  
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    AND (
      v_required_vehicle IS NULL 
      OR v_required_vehicle = 'any'
      OR u.vehicle_type IS NULL 
      OR u.vehicle_type = v_required_vehicle
      OR u.vehicle_type = 'motorbike' AND v_required_vehicle = 'motorcycle'
      OR u.vehicle_type = 'motorcycle' AND v_required_vehicle = 'motorbike'
    )
    AND u.id NOT IN (
      SELECT driver_id FROM order_rejected_drivers WHERE order_id = p_order_id
    )
    AND u.id NOT IN (
      SELECT driver_id FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('pending', 'accepted', 'on_the_way')
    )
  ORDER BY ST_Distance(
    v_pickup_point,
    ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
  ) ASC
  LIMIT 1;
  
  IF v_driver_id IS NULL THEN
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      AND (
        v_required_vehicle IS NULL 
        OR u.vehicle_type IS NULL 
        OR u.vehicle_type = v_required_vehicle
        OR u.vehicle_type = 'motorbike' AND v_required_vehicle = 'motorcycle'
        OR u.vehicle_type = 'motorcycle' AND v_required_vehicle = 'motorbike'
      )
      AND u.id NOT IN (
        SELECT driver_id FROM order_rejected_drivers WHERE order_id = p_order_id
      )
      AND u.id NOT IN (
        SELECT driver_id FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('accepted', 'on_the_way')
      )
    ORDER BY ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) ASC
    LIMIT 1;
  END IF;
  
  RETURN v_driver_id;
END;
$fn2$;

