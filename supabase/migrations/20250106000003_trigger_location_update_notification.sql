-- ============================================================================
-- LOCATION UPDATE NOTIFICATION SYSTEM (Using Existing Infrastructure)
-- ============================================================================
-- This migration integrates WhatsApp location updates with the existing
-- notification system that uses customer_location_provided flag
--
-- Flow:
-- 1. Customer sends location → Webhook updates coordinates and sets flags
-- 2. location_update_notification_widget polls every 30 seconds
-- 3. Calls get_orders_with_location_updates() function
-- 4. Returns orders where customer_location_provided=true and driver_notified_location=false
-- 5. Widget shows notification popup to driver
-- 6. Driver acknowledges → calls mark_driver_notified_location()
-- 7. Map automatically updates via OrderProvider realtime subscription
-- ============================================================================

-- Function to get orders with location updates that drivers haven't been notified about
CREATE OR REPLACE FUNCTION get_orders_with_location_updates()
RETURNS TABLE (
  order_id UUID,
  customer_name TEXT,
  customer_phone TEXT,
  delivery_address TEXT,
  delivery_latitude NUMERIC,
  delivery_longitude NUMERIC,
  merchant_name TEXT,
  status TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id AS order_id,
    o.customer_name,
    o.customer_phone,
    o.delivery_address,
    o.delivery_latitude,
    o.delivery_longitude,
    m.name AS merchant_name,
    o.status,
    o.created_at,
    o.updated_at
  FROM orders o
  LEFT JOIN users m ON o.merchant_id = m.id
  WHERE 
    -- Customer has provided location
    o.customer_location_provided = true
    -- Driver hasn't been notified yet
    AND (o.driver_notified_location = false OR o.driver_notified_location IS NULL)
    -- Not an auto-updated location (real customer location)
    AND (o.coordinates_auto_updated = false OR o.coordinates_auto_updated IS NULL)
    -- Order has a driver assigned
    AND o.driver_id IS NOT NULL
    -- Order is active
    AND o.status IN ('pending', 'accepted', 'on_the_way', 'picked_up')
  ORDER BY o.updated_at DESC;
END;
$$;

-- Function to mark driver as notified about location update
CREATE OR REPLACE FUNCTION mark_driver_notified_location(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE orders
  SET 
    driver_notified_location = true,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  RETURN FOUND;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_orders_with_location_updates() TO authenticated;
GRANT EXECUTE ON FUNCTION get_orders_with_location_updates() TO anon;
GRANT EXECUTE ON FUNCTION get_orders_with_location_updates() TO service_role;

GRANT EXECUTE ON FUNCTION mark_driver_notified_location(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_driver_notified_location(UUID) TO anon;
GRANT EXECUTE ON FUNCTION mark_driver_notified_location(UUID) TO service_role;

-- Add comments
COMMENT ON FUNCTION get_orders_with_location_updates() IS 
  'Returns orders where customers have provided location but drivers have not been notified yet';

COMMENT ON FUNCTION mark_driver_notified_location(UUID) IS
  'Marks that driver has been notified about customer location update';

-- Test the functions (optional)
DO $$
DECLARE
  test_count INT;
BEGIN
  -- Test get_orders_with_location_updates
  SELECT COUNT(*) INTO test_count
  FROM get_orders_with_location_updates();
  
  RAISE NOTICE '✅ Location update notification system installed';
  RAISE NOTICE '   - Function: get_orders_with_location_updates()';
  RAISE NOTICE '   - Function: mark_driver_notified_location(UUID)';
  RAISE NOTICE '   - Current pending notifications: %', test_count;
  RAISE NOTICE '   - Check interval: 30 seconds (via location_update_notification_widget)';
END $$;

