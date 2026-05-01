-- =====================================================================================
-- ADD DELIVERY TIMER SYSTEM
-- =====================================================================================
-- This migration adds a timer system for drivers from pickup to dropoff:
-- 1. Drivers can only mark "picked up" if within 100m of merchant
-- 2. Timer is calculated using Mapbox route time * 1.5x
-- 3. Timer stops when driver is within 200m of dropoff location
-- =====================================================================================

-- Add timer fields to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_time_limit_seconds INTEGER;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_timer_started_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_timer_stopped_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_timer_expires_at TIMESTAMPTZ;

-- Add comments
COMMENT ON COLUMN orders.delivery_time_limit_seconds IS 'Calculated time limit in seconds (Mapbox route time * 1.5)';
COMMENT ON COLUMN orders.delivery_timer_started_at IS 'When driver marked order as picked up';
COMMENT ON COLUMN orders.delivery_timer_stopped_at IS 'When driver reached within 200m of dropoff (timer stopped)';
COMMENT ON COLUMN orders.delivery_timer_expires_at IS 'When the timer expires (started_at + time_limit)';

-- Create index for timer queries
CREATE INDEX IF NOT EXISTS idx_orders_delivery_timer_active 
  ON orders(delivery_timer_started_at) 
  WHERE delivery_timer_started_at IS NOT NULL 
    AND delivery_timer_stopped_at IS NULL 
    AND status = 'on_the_way';

-- =====================================================================================
-- FUNCTION: Calculate distance between two points (Haversine formula)
-- =====================================================================================
CREATE OR REPLACE FUNCTION calculate_distance_meters(
  lat1 DECIMAL,
  lon1 DECIMAL,
  lat2 DECIMAL,
  lon2 DECIMAL
)
RETURNS DECIMAL
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  R DECIMAL := 6371000; -- Earth radius in meters
  dlat DECIMAL;
  dlon DECIMAL;
  a DECIMAL;
  c DECIMAL;
BEGIN
  -- Convert to radians
  dlat := radians(lat2 - lat1);
  dlon := radians(lon2 - lon1);
  
  -- Haversine formula
  a := sin(dlat / 2) * sin(dlat / 2) +
       cos(radians(lat1)) * cos(radians(lat2)) *
       sin(dlon / 2) * sin(dlon / 2);
  c := 2 * atan2(sqrt(a), sqrt(1 - a));
  
  RETURN R * c;
END;
$$;

-- =====================================================================================
-- FUNCTION: Validate driver can mark pickup (must be within 100m of merchant)
-- =====================================================================================
CREATE OR REPLACE FUNCTION validate_pickup_location(
  p_order_id UUID,
  p_driver_id UUID,
  p_driver_latitude DECIMAL,
  p_driver_longitude DECIMAL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order orders%ROWTYPE;
  v_distance DECIMAL;
  v_pickup_radius_meters DECIMAL := 100; -- 100 meters
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_NOT_FOUND',
      'message', 'Order not found'
    );
  END IF;
  
  -- Verify driver is assigned to this order
  IF v_order.driver_id != p_driver_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'UNAUTHORIZED',
      'message', 'Order not assigned to this driver'
    );
  END IF;
  
  -- Check if order is in correct status
  IF v_order.status != 'accepted' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INVALID_STATUS',
      'message', 'Order must be in accepted status to mark as picked up',
      'current_status', v_order.status
    );
  END IF;
  
  -- Calculate distance from driver to pickup location
  v_distance := calculate_distance_meters(
    p_driver_latitude,
    p_driver_longitude,
    v_order.pickup_latitude,
    v_order.pickup_longitude
  );
  
  IF v_distance > v_pickup_radius_meters THEN
    RETURN json_build_object(
      'success', false,
      'error', 'TOO_FAR_FROM_PICKUP',
      'message', format('Driver must be within %s meters of pickup location. Current distance: %s meters', 
                       v_pickup_radius_meters, ROUND(v_distance, 1)),
      'distance_meters', ROUND(v_distance, 1),
      'required_radius_meters', v_pickup_radius_meters
    );
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'distance_meters', ROUND(v_distance, 1)
  );
END;
$$;

-- =====================================================================================
-- FUNCTION: Check if driver reached dropoff and stop timer
-- =====================================================================================
CREATE OR REPLACE FUNCTION check_dropoff_proximity(
  p_order_id UUID,
  p_driver_id UUID,
  p_driver_latitude DECIMAL,
  p_driver_longitude DECIMAL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order orders%ROWTYPE;
  v_distance DECIMAL;
  v_dropoff_radius_meters DECIMAL := 200; -- 200 meters
  v_timer_stopped BOOLEAN := false;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_NOT_FOUND',
      'message', 'Order not found'
    );
  END IF;
  
  -- Only check if order is on_the_way and timer is active
  IF v_order.status != 'on_the_way' OR v_order.delivery_timer_started_at IS NULL THEN
    RETURN json_build_object(
      'success', true,
      'timer_active', false,
      'message', 'Timer not active for this order'
    );
  END IF;
  
  -- If timer already stopped, return
  IF v_order.delivery_timer_stopped_at IS NOT NULL THEN
    RETURN json_build_object(
      'success', true,
      'timer_active', false,
      'timer_stopped_at', v_order.delivery_timer_stopped_at,
      'message', 'Timer already stopped'
    );
  END IF;
  
  -- Calculate distance from driver to dropoff location
  v_distance := calculate_distance_meters(
    p_driver_latitude,
    p_driver_longitude,
    v_order.delivery_latitude,
    v_order.delivery_longitude
  );
  
  -- If driver is within dropoff radius, stop the timer
  IF v_distance <= v_dropoff_radius_meters THEN
    UPDATE orders
    SET delivery_timer_stopped_at = NOW()
    WHERE id = p_order_id;
    
    v_timer_stopped := true;
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'timer_active', NOT v_timer_stopped,
    'timer_stopped', v_timer_stopped,
    'distance_meters', ROUND(v_distance, 1),
    'dropoff_radius_meters', v_dropoff_radius_meters,
    'within_radius', v_distance <= v_dropoff_radius_meters
  );
END;
$$;

-- =====================================================================================
-- MODIFY: Update order status function to handle timer setup
-- =====================================================================================
-- This function will be called with additional parameters for timer setup
CREATE OR REPLACE FUNCTION update_order_status_with_timer(
  p_order_id UUID,
  p_new_status TEXT,
  p_user_id UUID,
  p_delivery_time_limit_seconds INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_status TEXT;
  v_driver_id UUID;
  v_merchant_id UUID;
  v_user_role TEXT;
  v_delivery_fee DECIMAL;
  v_order_exists BOOLEAN;
  v_user_exists BOOLEAN;
BEGIN
  -- Log the attempt
  RAISE NOTICE 'Attempting to update order % to status % by user %', p_order_id, p_new_status, p_user_id;
  
  -- Check if order exists
  SELECT EXISTS(SELECT 1 FROM orders WHERE id = p_order_id) INTO v_order_exists;
  IF NOT v_order_exists THEN
    RAISE NOTICE 'Order % not found', p_order_id;
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_NOT_FOUND',
      'message', 'Order not found'
    );
  END IF;
  
  -- Check if user exists
  SELECT EXISTS(SELECT 1 FROM users WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RAISE NOTICE 'User % not found', p_user_id;
    RETURN json_build_object(
      'success', false,
      'error', 'USER_NOT_FOUND',
      'message', 'User not found'
    );
  END IF;
  
  -- Get order details
  SELECT status, driver_id, merchant_id, delivery_fee
  INTO v_current_status, v_driver_id, v_merchant_id, v_delivery_fee
  FROM orders
  WHERE id = p_order_id;
  
  -- Get user role
  SELECT role INTO v_user_role FROM users WHERE id = p_user_id;
  
  RAISE NOTICE 'Order status: %, Driver: %, Merchant: %, User role: %', 
    v_current_status, v_driver_id, v_merchant_id, v_user_role;
  
  -- Validate status transition
  IF v_current_status IN ('delivered', 'cancelled') THEN
    RAISE NOTICE 'Cannot update completed order with status %', v_current_status;
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_COMPLETED',
      'message', 'Cannot update completed order',
      'current_status', v_current_status
    );
  END IF;
  
  -- Validate permissions for drivers
  IF v_user_role = 'driver' THEN
    IF v_driver_id IS NULL THEN
      RAISE NOTICE 'Order % not assigned to any driver', p_order_id;
      RETURN json_build_object(
        'success', false,
        'error', 'NOT_ASSIGNED',
        'message', 'Order is not assigned to any driver',
        'driver_id', v_driver_id
      );
    END IF;
    
    IF v_driver_id != p_user_id THEN
      RAISE NOTICE 'Order assigned to % but user is %', v_driver_id, p_user_id;
      RETURN json_build_object(
        'success', false,
        'error', 'UNAUTHORIZED',
        'message', 'Order not assigned to this driver',
        'expected_driver', v_driver_id,
        'actual_driver', p_user_id
      );
    END IF;
  END IF;
  
  -- Validate permissions for merchants
  IF v_user_role = 'merchant' AND v_merchant_id != p_user_id THEN
    RAISE NOTICE 'Merchant mismatch: expected %, got %', v_merchant_id, p_user_id;
    RETURN json_build_object(
      'success', false,
      'error', 'UNAUTHORIZED',
      'message', 'Order does not belong to this merchant'
    );
  END IF;
  
  -- Update order status with timer setup if transitioning to on_the_way
  UPDATE orders
  SET 
    status = p_new_status,
    updated_at = NOW(),
    picked_up_at = CASE WHEN p_new_status = 'on_the_way' THEN NOW() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE delivered_at END,
    cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN NOW() ELSE cancelled_at END,
    -- Set timer fields when marking as picked up
    delivery_time_limit_seconds = CASE 
      WHEN p_new_status = 'on_the_way' AND p_delivery_time_limit_seconds IS NOT NULL 
      THEN p_delivery_time_limit_seconds 
      ELSE delivery_time_limit_seconds 
    END,
    delivery_timer_started_at = CASE 
      WHEN p_new_status = 'on_the_way' AND delivery_timer_started_at IS NULL 
      THEN NOW() 
      ELSE delivery_timer_started_at 
    END,
    delivery_timer_expires_at = CASE 
      WHEN p_new_status = 'on_the_way' AND p_delivery_time_limit_seconds IS NOT NULL AND delivery_timer_started_at IS NULL
      THEN NOW() + (p_delivery_time_limit_seconds || ' seconds')::INTERVAL
      ELSE delivery_timer_expires_at
    END,
    -- Stop timer when order is delivered or cancelled
    delivery_timer_stopped_at = CASE 
      WHEN p_new_status IN ('delivered', 'cancelled') AND delivery_timer_stopped_at IS NULL
      THEN NOW()
      ELSE delivery_timer_stopped_at
    END
  WHERE id = p_order_id;
  
  RAISE NOTICE 'Order % updated to status %', p_order_id, p_new_status;
  
  -- Create earnings with rank-based commission when order is delivered
  IF p_new_status = 'delivered' AND v_current_status != 'delivered' AND v_driver_id IS NOT NULL THEN
    PERFORM create_driver_earning_with_rank(
      v_driver_id,
      p_order_id,
      v_delivery_fee
    );
    RAISE NOTICE 'Earnings record created with rank-based commission for driver %', v_driver_id;
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', p_new_status,
    'timer_started', CASE WHEN p_new_status = 'on_the_way' THEN true ELSE false END,
    'timer_expires_at', CASE 
      WHEN p_new_status = 'on_the_way' AND p_delivery_time_limit_seconds IS NOT NULL
      THEN (NOW() + (p_delivery_time_limit_seconds || ' seconds')::INTERVAL)::TEXT
      ELSE NULL
    END
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION calculate_distance_meters(DECIMAL, DECIMAL, DECIMAL, DECIMAL) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION validate_pickup_location(UUID, UUID, DECIMAL, DECIMAL) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION check_dropoff_proximity(UUID, UUID, DECIMAL, DECIMAL) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION update_order_status_with_timer(UUID, TEXT, UUID, INTEGER) TO authenticated, anon;

-- =====================================================================================

