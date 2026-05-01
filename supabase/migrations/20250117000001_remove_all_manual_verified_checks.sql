-- =====================================================================================
-- REMOVE ALL manual_verified CHECKS FROM AUTO-ASSIGNMENT FUNCTIONS
-- =====================================================================================
-- This migration removes all manual_verified checks from driver assignment functions
-- since manual_verified is now irrelevant for order assignment
-- =====================================================================================

-- =====================================================================================
-- STEP 2: CREATE UPDATED FUNCTIONS WITHOUT manual_verified CHECKS
-- =====================================================================================
-- NOTE: Run migration 20250117000002_drop_manual_verified_functions.sql first
-- This migration creates all the functions without manual_verified requirements
-- =====================================================================================

-- Now create the functions - each in its own DO block to avoid parsing conflicts
-- 1. Create 3-parameter version of find_next_available_driver
DO $$
BEGIN
  EXECUTE '
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
BEGIN
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  -- TIER 1: Try to find driver with NO active orders at all (completely free)
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
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
      -- REMOVED: AND u.manual_verified = true
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
  
  RETURN v_driver_id;
END;
$$';
END $$;

-- 1b. Create the 4-parameter version (with vehicle_type filter) - this is an overload
CREATE FUNCTION find_next_available_driver(
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
BEGIN
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
    -- REMOVED: AND u.manual_verified = true
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
      -- REMOVED: AND u.manual_verified = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Vehicle type compatibility check
      AND (
        v_required_vehicle IS NULL 
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
  
  RETURN v_driver_id;
END;
$$;

-- 2. Update get_ranked_available_drivers function (from 20250930000001_auto_driver_assignment.sql)
-- Create the 4-parameter version (backward compatible)
CREATE OR REPLACE FUNCTION get_ranked_available_drivers(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  vehicle_type TEXT,
  distance_meters DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_online BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pickup_point GEOGRAPHY;
BEGIN
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  RETURN QUERY
  SELECT 
    u.id as driver_id,
    u.name as driver_name,
    u.vehicle_type,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) as distance_meters,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) / 1000.0 as distance_km,
    u.latitude,
    u.longitude,
    u.is_online
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Driver hasn't rejected this order before
    AND u.id NOT IN (
      SELECT driver_id 
      FROM order_rejected_drivers 
      WHERE order_id = p_order_id
    )
    -- Driver doesn't have an active order
    AND u.id NOT IN (
      SELECT driver_id 
      FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('accepted', 'on_the_way')
    )
  ORDER BY distance_meters ASC
  LIMIT p_limit;
END;
$$;

-- Create the 5-parameter version (with vehicle_type filter) - this is the main implementation
CREATE OR REPLACE FUNCTION get_ranked_available_drivers(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION,
  p_limit INTEGER DEFAULT 10,
  p_vehicle_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  vehicle_type TEXT,
  distance_meters DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_online BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pickup_point GEOGRAPHY;
  v_required_vehicle TEXT;
BEGIN
  -- Normalize vehicle type
  v_required_vehicle := CASE 
    WHEN p_vehicle_type = 'motorbike' THEN 'motorcycle'
    ELSE p_vehicle_type
  END;
  
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  RETURN QUERY
  SELECT 
    u.id as driver_id,
    u.name as driver_name,
    u.vehicle_type,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) as distance_meters,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) / 1000.0 as distance_km,
    u.latitude,
    u.longitude,
    u.is_online
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
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
    -- Driver doesn't have an active order
    AND u.id NOT IN (
      SELECT driver_id 
      FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('accepted', 'on_the_way')
    )
  ORDER BY distance_meters ASC
  LIMIT p_limit;
END;
$$;

-- 3. Update find_next_available_driver function (from 20250930120000_complete_delivery_system.sql)
-- This is a different version that also needs updating
-- Drop existing function first
DROP FUNCTION IF EXISTS find_next_available_driver_v2(UUID, DECIMAL, DECIMAL);

CREATE OR REPLACE FUNCTION find_next_available_driver_v2(
  p_order_id UUID,
  p_pickup_lat DECIMAL,
  p_pickup_lng DECIMAL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_point GEOGRAPHY;
BEGIN
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  -- TIER 1: Try to find driver with NO active orders at all (completely free)
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = TRUE
    -- REMOVED: AND u.manual_verified = TRUE
    AND u.is_active = TRUE
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Driver hasn't rejected this order
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
      AND u.is_online = TRUE
      -- REMOVED: AND u.manual_verified = TRUE
      AND u.is_active = TRUE
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Driver hasn't rejected this order
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
  
  RETURN v_driver_id;
END;
$$;

-- 4. Update get_ranked_available_drivers function (from 20250930120000_complete_delivery_system.sql)
-- Drop existing function first to avoid return type conflicts
DROP FUNCTION IF EXISTS get_ranked_available_drivers_v2(UUID, DECIMAL, DECIMAL, INTEGER);

CREATE OR REPLACE FUNCTION get_ranked_available_drivers_v2(
  p_order_id UUID,
  p_pickup_lat DECIMAL,
  p_pickup_lng DECIMAL,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  distance_meters DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  latitude DECIMAL,
  longitude DECIMAL,
  is_online BOOLEAN,
  has_rejected BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pickup_point GEOGRAPHY;
BEGIN
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) as dist_meters,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) / 1000.0 as dist_km,
    u.latitude,
    u.longitude,
    u.is_online,
    EXISTS(
      SELECT 1 FROM order_rejected_drivers 
      WHERE order_id = p_order_id AND driver_id = u.id
    ) as rejected
  FROM users u
  WHERE u.role = 'driver'
    -- REMOVED: AND u.manual_verified = TRUE
    AND u.is_active = TRUE
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
  ORDER BY dist_meters ASC
  LIMIT p_limit;
END;
$$;

-- 5. Update check_vehicle_availability function (from 20251011060000_check_vehicle_availability.sql)
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

-- 6. Update functions from other migrations that check manual_verified
-- These may be called by auto-assignment logic

-- From 20251011040000_add_vehicle_type_compatibility.sql
-- Drop existing function first
DROP FUNCTION IF EXISTS get_compatible_drivers(TEXT);

CREATE OR REPLACE FUNCTION get_compatible_drivers(p_vehicle_type TEXT)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  vehicle_type TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    u.vehicle_type
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
    AND (
      p_vehicle_type IS NULL 
      OR p_vehicle_type = 'any'
      OR u.vehicle_type = p_vehicle_type
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- From 20251021030000_add_any_vehicle_type.sql
-- Drop existing function first
DROP FUNCTION IF EXISTS find_driver_for_any_vehicle_type(UUID, DECIMAL, DECIMAL);

CREATE OR REPLACE FUNCTION find_driver_for_any_vehicle_type(
  p_order_id UUID,
  p_pickup_lat DECIMAL,
  p_pickup_lng DECIMAL
)
RETURNS UUID AS $$
DECLARE
  v_driver_id UUID;
BEGIN
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM order_rejected_drivers 
      WHERE order_id = p_order_id AND driver_id = u.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM orders 
      WHERE driver_id = u.id 
      AND status IN ('assigned', 'accepted', 'on_the_way')
    )
  ORDER BY ST_Distance(
    ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography,
    ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
  ) ASC
  LIMIT 1;
  
  RETURN v_driver_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- From 20251011080000_add_vehicle_check_to_repost.sql
-- Drop existing function first
DROP FUNCTION IF EXISTS can_repost_order(UUID);

CREATE OR REPLACE FUNCTION can_repost_order(p_order_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_vehicle_type TEXT;
  v_available BOOLEAN;
BEGIN
  -- Get order vehicle type
  SELECT vehicle_type INTO v_vehicle_type
  FROM orders
  WHERE id = p_order_id;
  
  -- Check if drivers are available
  SELECT check_vehicle_availability(v_vehicle_type) INTO v_available;
  
  RETURN v_available;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- From 20251021050000_admin_order_management.sql
-- Drop existing function first
DROP FUNCTION IF EXISTS get_available_drivers_for_admin(DECIMAL, DECIMAL, TEXT);

CREATE OR REPLACE FUNCTION get_available_drivers_for_admin(
  p_latitude DECIMAL,
  p_longitude DECIMAL,
  p_vehicle_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  distance_meters DOUBLE PRECISION,
  vehicle_type TEXT
) AS $$
DECLARE
  v_point GEOGRAPHY;
BEGIN
  v_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;
  
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    ST_Distance(
      v_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) as distance,
    u.vehicle_type
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    AND (p_vehicle_type IS NULL OR p_vehicle_type = 'any' OR u.vehicle_type = p_vehicle_type)
  ORDER BY distance ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- From 20251105000010_fix_rotation_logic.sql
-- Update any rotation logic that checks manual_verified
-- Drop existing function first
DROP FUNCTION IF EXISTS rotate_driver_assignment(UUID);

CREATE OR REPLACE FUNCTION rotate_driver_assignment(p_order_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_driver_id UUID;
  v_order RECORD;
BEGIN
  -- Get order details
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Find next available driver (excluding current driver)
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    -- REMOVED: AND u.manual_verified = true
    AND u.id != v_order.driver_id
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM order_rejected_drivers 
      WHERE order_id = p_order_id AND driver_id = u.id
    )
  ORDER BY ST_Distance(
    ST_SetSRID(ST_MakePoint(v_order.pickup_longitude, v_order.pickup_latitude), 4326)::geography,
    ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
  ) ASC
  LIMIT 1;
  
  IF v_driver_id IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Update order with new driver
  UPDATE orders
  SET driver_id = v_driver_id, updated_at = NOW()
  WHERE id = p_order_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update comments
COMMENT ON FUNCTION find_next_available_driver IS 
  'Finds the nearest online driver who has not rejected the order (no verification required)';

COMMENT ON FUNCTION get_ranked_available_drivers IS 
  'Returns list of available drivers ranked by distance (no verification required)';

COMMENT ON FUNCTION check_vehicle_availability IS 
  'Checks if drivers with specific vehicle type are available (no verification required)';

