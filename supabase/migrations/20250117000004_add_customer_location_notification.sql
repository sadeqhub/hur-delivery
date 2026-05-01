-- =====================================================================================
-- ADD PUSH NOTIFICATION TO DRIVER WHEN CUSTOMER LOCATION UPDATES
-- =====================================================================================
-- This migration updates the update_customer_location function to send a push
-- notification to the driver when customer provides their location via WhatsApp
-- =====================================================================================

-- Drop existing function variants first
DROP FUNCTION IF EXISTS update_customer_location(UUID, DECIMAL, DECIMAL);
DROP FUNCTION IF EXISTS update_customer_location(UUID, DECIMAL, DECIMAL, BOOLEAN);

CREATE OR REPLACE FUNCTION update_customer_location(
  p_order_id UUID,
  p_latitude DECIMAL(10,8),
  p_longitude DECIMAL(11,8),
  p_is_auto_update BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN AS $$
DECLARE
  order_exists BOOLEAN;
  v_driver_id UUID;
  v_order_status TEXT;
  v_old_lat DECIMAL(10,8);
  v_old_lng DECIMAL(11,8);
  v_location_changed BOOLEAN := FALSE;
BEGIN
  -- Check if order exists and get driver_id
  SELECT EXISTS(SELECT 1 FROM orders WHERE id = p_order_id),
         driver_id,
         status,
         delivery_latitude,
         delivery_longitude
  INTO order_exists, v_driver_id, v_order_status, v_old_lat, v_old_lng
  FROM orders
  WHERE id = p_order_id;
  
  IF NOT order_exists THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;
  
  -- Check if location actually changed (with threshold to avoid false positives)
  IF v_old_lat IS NULL OR v_old_lng IS NULL OR
     ABS(v_old_lat - p_latitude) > 0.0001 OR
     ABS(v_old_lng - p_longitude) > 0.0001 THEN
    v_location_changed := TRUE;
  END IF;
  
  -- Update the order with new customer location
  UPDATE orders 
  SET 
    delivery_latitude = p_latitude,
    delivery_longitude = p_longitude,
    customer_location_provided = CASE 
      WHEN NOT p_is_auto_update THEN TRUE 
      ELSE customer_location_provided 
    END,
    coordinates_auto_updated = CASE 
      WHEN p_is_auto_update THEN TRUE 
      ELSE FALSE 
    END,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Update the WhatsApp request record
  UPDATE whatsapp_location_requests 
  SET 
    status = 'location_received',
    customer_latitude = p_latitude,
    customer_longitude = p_longitude,
    location_received_at = NOW(),
    updated_at = NOW()
  WHERE order_id = p_order_id;
  
  -- Create notification for driver if:
  -- 1. Location actually changed
  -- 2. Driver is assigned
  -- 3. Order is in a state where driver needs the location (assigned, accepted, on_the_way)
  -- 4. This is NOT an auto-update (only notify for real customer location)
  IF v_location_changed 
     AND v_driver_id IS NOT NULL 
     AND v_order_status IN ('assigned', 'accepted', 'on_the_way')
     AND NOT p_is_auto_update THEN
    
    -- Insert notification which will trigger push notification via existing trigger
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      v_driver_id,
      'تم تحديث موقع العميل',
      'تم تحديث موقع العميل للطلب. اضغط لعرض الموقع الجديد.',
      'customer_location_updated',
      jsonb_build_object(
        'order_id', p_order_id,
        'latitude', p_latitude,
        'longitude', p_longitude
      )
    )
    ON CONFLICT DO NOTHING; -- Prevent duplicate notifications
    
    RAISE NOTICE 'Created notification for driver % for order % location update', v_driver_id, p_order_id;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update comment
COMMENT ON FUNCTION update_customer_location(UUID, DECIMAL, DECIMAL, BOOLEAN) IS 
  'Updates order with customer location coordinates received via WhatsApp. 
   Sends push notification to driver when location is updated (only for real customer locations, not auto-updates).';

-- =====================================================================================
-- TRIGGER TO NOTIFY DRIVER WHEN DELIVERY COORDINATES CHANGE
-- =====================================================================================
-- This trigger handles cases where delivery coordinates are updated directly
-- (e.g., via otpiq-webhook that updates the table directly)
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_driver_on_location_update()
RETURNS TRIGGER AS $$
DECLARE
  v_location_changed BOOLEAN := FALSE;
BEGIN
  -- Only process if this is an order with a driver assigned
  IF NEW.driver_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Check if delivery coordinates changed (with threshold)
  IF (OLD.delivery_latitude IS NULL AND NEW.delivery_latitude IS NOT NULL) OR
     (OLD.delivery_longitude IS NULL AND NEW.delivery_longitude IS NOT NULL) OR
     (OLD.delivery_latitude IS NOT NULL AND NEW.delivery_latitude IS NOT NULL AND
      ABS(OLD.delivery_latitude - NEW.delivery_latitude) > 0.0001) OR
     (OLD.delivery_longitude IS NOT NULL AND NEW.delivery_longitude IS NOT NULL AND
      ABS(OLD.delivery_longitude - NEW.delivery_longitude) > 0.0001) THEN
    v_location_changed := TRUE;
  END IF;
  
  -- Send notification if:
  -- 1. Location changed
  -- 2. Order is in a state where driver needs the location
  -- 3. This is NOT an auto-update (check coordinates_auto_updated flag)
  IF v_location_changed 
     AND NEW.status IN ('assigned', 'accepted', 'on_the_way')
     AND (NEW.coordinates_auto_updated IS NULL OR NEW.coordinates_auto_updated = FALSE) THEN
    
    -- Insert notification (trigger will send push notification)
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.driver_id,
      'تم تحديث موقع العميل',
      'تم تحديث موقع العميل للطلب. اضغط لعرض الموقع الجديد.',
      'customer_location_updated',
      jsonb_build_object(
        'order_id', NEW.id,
        'latitude', NEW.delivery_latitude,
        'longitude', NEW.delivery_longitude
      )
    )
    ON CONFLICT DO NOTHING; -- Prevent duplicate notifications
    
    RAISE NOTICE 'Created notification for driver % for order % location update (via trigger)', NEW.driver_id, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on orders table
DROP TRIGGER IF EXISTS trigger_notify_driver_location_update ON orders;
CREATE TRIGGER trigger_notify_driver_location_update
  AFTER UPDATE OF delivery_latitude, delivery_longitude ON orders
  FOR EACH ROW
  WHEN (
    (OLD.delivery_latitude IS DISTINCT FROM NEW.delivery_latitude) OR
    (OLD.delivery_longitude IS DISTINCT FROM NEW.delivery_longitude)
  )
  EXECUTE FUNCTION notify_driver_on_location_update();

-- Grant execute permission
GRANT EXECUTE ON FUNCTION notify_driver_on_location_update() TO postgres;

-- Add comment
COMMENT ON FUNCTION notify_driver_on_location_update() IS 
  'Trigger function that sends notification to driver when delivery coordinates are updated.
   Handles direct table updates (bypassing update_customer_location function).';

COMMENT ON TRIGGER trigger_notify_driver_location_update ON orders IS 
  'Triggers when delivery_latitude or delivery_longitude changes to notify the assigned driver.';

