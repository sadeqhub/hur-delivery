-- =====================================================================================
-- FIX ALL NOTIFICATION DUPLICATES (MERCHANTS AND DRIVERS)
-- =====================================================================================
-- This migration fixes duplicate notifications for both merchants and drivers:
-- 1. Adds deduplication to driver location update notifications
-- 2. Improves merchant delivered notification deduplication
-- 3. Removes all existing merchant location notifications
-- 4. Cleans up duplicate notifications
-- =====================================================================================

BEGIN;

-- =====================================================================================
-- 1. FIX DRIVER LOCATION UPDATE NOTIFICATION FUNCTION (ADD DEDUPLICATION)
-- =====================================================================================
-- The notify_driver_on_location_update() function needs deduplication like the merchant one
CREATE OR REPLACE FUNCTION notify_driver_on_location_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_location_changed BOOLEAN := FALSE;
  v_existing_notification_id UUID;
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
    
    -- Check if notification already exists (prevent duplicates)
    -- Check for notifications created in the last 10 seconds to catch rapid-fire updates
    SELECT id INTO v_existing_notification_id
    FROM notifications
    WHERE user_id = NEW.driver_id
      AND type = 'customer_location_updated'
      AND (data->>'order_id')::uuid = NEW.id
      AND created_at >= NOW() - INTERVAL '10 seconds'
    LIMIT 1;
    
    -- Only create notification if it doesn't already exist
    IF v_existing_notification_id IS NULL THEN
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
      );
      
      RAISE NOTICE 'Created location notification for driver % order %', NEW.driver_id, NEW.id;
    ELSE
      RAISE NOTICE 'Skipped duplicate location notification for driver % order % (existing: %)', 
        NEW.driver_id, NEW.id, v_existing_notification_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_driver_on_location_update IS 
  'Notifies driver when customer location is updated. Includes deduplication to prevent duplicates.';

-- =====================================================================================
-- 2. FIX update_customer_location() FUNCTION (ADD DEDUPLICATION)
-- =====================================================================================
-- This function also creates driver notifications and needs deduplication
CREATE OR REPLACE FUNCTION update_customer_location(
  p_order_id UUID,
  p_latitude DECIMAL(10,8),
  p_longitude DECIMAL(11,8),
  p_is_auto_update BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  order_exists BOOLEAN;
  v_driver_id UUID;
  v_order_status TEXT;
  v_old_lat DECIMAL(10,8);
  v_old_lng DECIMAL(11,8);
  v_location_changed BOOLEAN := FALSE;
  v_existing_notification_id UUID;
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
    
    -- Check if notification already exists (prevent duplicates)
    SELECT id INTO v_existing_notification_id
    FROM notifications
    WHERE user_id = v_driver_id
      AND type = 'customer_location_updated'
      AND (data->>'order_id')::uuid = p_order_id
      AND created_at >= NOW() - INTERVAL '10 seconds'
    LIMIT 1;
    
    -- Only create notification if it doesn't already exist
    IF v_existing_notification_id IS NULL THEN
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
      );
      
      RAISE NOTICE 'Created location notification for driver % order %', v_driver_id, p_order_id;
    ELSE
      RAISE NOTICE 'Skipped duplicate location notification for driver % order % (existing: %)', 
        v_driver_id, p_order_id, v_existing_notification_id;
    END IF;
  END IF;
  
  RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION update_customer_location(UUID, DECIMAL, DECIMAL, BOOLEAN) IS 
  'Updates order with customer location coordinates received via WhatsApp. 
   Sends push notification to driver when location is updated (only for real customer locations, not auto-updates).
   Includes deduplication to prevent duplicates.';

-- =====================================================================================
-- 3. DELETE ALL MERCHANT LOCATION NOTIFICATIONS (SHOULD NOT EXIST)
-- =====================================================================================
-- Remove any existing merchant notifications for location updates
-- These should only be sent to drivers, not merchants
-- Use a more reliable DELETE query
DO $$
DECLARE
  deleted_count INT;
BEGIN
  -- Delete notifications where the user is a merchant and the notification is about location
  WITH merchant_location_notifications AS (
    SELECT n.id
    FROM notifications n
    JOIN users u ON n.user_id = u.id
    WHERE n.type IN ('location_received', 'customer_location_updated')
      AND u.role = 'merchant'
  )
  DELETE FROM notifications
  WHERE id IN (SELECT id FROM merchant_location_notifications);
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % merchant location notifications', deleted_count;
END $$;

-- =====================================================================================
-- 4. CLEAN UP DUPLICATE NOTIFICATIONS (KEEP ONLY THE FIRST ONE)
-- =====================================================================================
-- Remove duplicate notifications, keeping only the first one for each order/user/type combination
DO $$
DECLARE
  deleted_count INT;
BEGIN
  -- Delete duplicate "delivered" notifications (keep the first one)
  WITH duplicate_delivered AS (
    SELECT 
      n.id,
      ROW_NUMBER() OVER (
        PARTITION BY n.user_id, n.type, (n.data->>'order_id')::uuid
        ORDER BY n.created_at ASC
      ) AS rn
    FROM notifications n
    WHERE n.type = 'order_delivered'
      AND n.created_at >= NOW() - INTERVAL '30 days'
  )
  DELETE FROM notifications
  WHERE id IN (
    SELECT id FROM duplicate_delivered WHERE rn > 1
  );
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % duplicate delivered notifications', deleted_count;
  
  -- Delete duplicate location notifications (keep the first one)
  WITH duplicate_location AS (
    SELECT 
      n.id,
      ROW_NUMBER() OVER (
        PARTITION BY n.user_id, n.type, (n.data->>'order_id')::uuid
        ORDER BY n.created_at ASC
      ) AS rn
    FROM notifications n
    WHERE n.type = 'customer_location_updated'
      AND n.created_at >= NOW() - INTERVAL '30 days'
  )
  DELETE FROM notifications
  WHERE id IN (
    SELECT id FROM duplicate_location WHERE rn > 1
  );
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % duplicate location notifications', deleted_count;
END $$;

COMMIT;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- 1. DRIVER LOCATION NOTIFICATIONS:
--    - Added deduplication check to notify_driver_on_location_update() trigger function
--    - Added deduplication check to update_customer_location() function
--    - Both check for existing notifications within last 10 seconds
-- 
-- 2. MERCHANT LOCATION NOTIFICATIONS:
--    - Deleted all existing merchant location notifications
--    - Edge function was already fixed to not create them
-- 
-- 3. DUPLICATE CLEANUP:
--    - Removed duplicate "delivered" notifications (kept first one)
--    - Removed duplicate location notifications (kept first one)
--    - Uses ROW_NUMBER() to identify duplicates
-- 
-- 4. DEDUPLICATION STRATEGY:
--    - Function-level check: Prevents duplicates in triggers/functions
--    - Time window: 10 seconds for rapid-fire updates
--    - Cleanup: Removes existing duplicates
-- =====================================================================================

