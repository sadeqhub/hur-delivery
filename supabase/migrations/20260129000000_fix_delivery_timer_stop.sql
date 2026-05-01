-- =====================================================================================
-- FIX: Stop delivery timer when order is marked as delivered or cancelled
-- =====================================================================================

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
    'timer_stopped', CASE WHEN p_new_status IN ('delivered', 'cancelled') THEN true ELSE false END,
    'timer_expires_at', CASE 
      WHEN p_new_status = 'on_the_way' AND p_delivery_time_limit_seconds IS NOT NULL
      THEN (NOW() + (p_delivery_time_limit_seconds || ' seconds')::INTERVAL)::TEXT
      ELSE NULL
    END
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_order_status_with_timer(UUID, TEXT, UUID, INTEGER) TO authenticated, anon;

