-- =====================================================================================
-- REMOVE GENERALIZED MERCHANT NOTIFICATIONS (KEEP ONLY DETAILED ONES)
-- =====================================================================================
-- This migration removes the generalized notification functions and replaces them
-- with detailed versions that include customer name/phone in the notification body.
-- 
-- Problem:
-- Merchants are receiving duplicate notifications - one generalized (without info)
-- and one detailed (with customer name/phone). The generalized ones should be removed.
-- 
-- Solution:
-- Replace the generalized functions with detailed versions that include customer
-- information in the notification body, and remove duplicates.
-- =====================================================================================

BEGIN;

-- =====================================================================================
-- 1. REPLACE notify_merchant_order_accepted() WITH DETAILED VERSION
-- =====================================================================================
-- Keep the version that includes customer name in the body
CREATE OR REPLACE FUNCTION notify_merchant_order_accepted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_driver_name TEXT;
  v_customer_name TEXT;
  v_customer_phone TEXT;
  v_existing_notification_id UUID;
BEGIN
  -- Only notify when status changes TO 'accepted'
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    -- Check if notification already exists (prevent duplicates)
    SELECT id INTO v_existing_notification_id
    FROM notifications
    WHERE user_id = NEW.merchant_id
      AND type = 'order_accepted'
      AND (data->>'order_id')::uuid = NEW.id
      AND created_at >= NOW() - INTERVAL '10 seconds'
    LIMIT 1;
    
    -- Only create notification if it doesn't already exist
    IF v_existing_notification_id IS NULL THEN
      -- Get driver name and customer info
      SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
      v_customer_name := NEW.customer_name;
      v_customer_phone := NEW.customer_phone;
      
      -- Insert detailed notification for merchant (includes customer name and phone)
      INSERT INTO notifications (user_id, title, body, type, data)
      VALUES (
        NEW.merchant_id,
        '✅ تم قبول الطلب',
        'قبل السائق ' || COALESCE(v_driver_name, 'السائق') || ' طلب ' || COALESCE(v_customer_name, 'العميل') || 
        CASE WHEN v_customer_phone IS NOT NULL THEN ' (' || v_customer_phone || ')' ELSE '' END || E'\n' ||
        'وهو في طريقه للاستلام',
        'order_accepted',
        jsonb_build_object(
          'order_id', NEW.id,
          'driver_id', NEW.driver_id,
          'driver_name', v_driver_name,
          'customer_name', v_customer_name,
          'customer_phone', v_customer_phone
        )
      );
      
      RAISE NOTICE 'Created detailed accepted notification for merchant % order %', NEW.merchant_id, NEW.id;
    ELSE
      RAISE NOTICE 'Skipped duplicate accepted notification for merchant % order % (existing: %)', 
        NEW.merchant_id, NEW.id, v_existing_notification_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_merchant_order_accepted IS 
  'Notifies merchant when order is accepted. Includes customer name and phone in notification body. Includes deduplication.';

-- =====================================================================================
-- 2. REPLACE notify_merchant_order_on_the_way() WITH DETAILED VERSION
-- =====================================================================================
-- Keep the version that includes customer name in the body
CREATE OR REPLACE FUNCTION notify_merchant_order_on_the_way()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_driver_name TEXT;
  v_customer_name TEXT;
  v_customer_phone TEXT;
  v_existing_notification_id UUID;
BEGIN
  -- Only notify when status changes TO 'on_the_way'
  IF OLD.status != 'on_the_way' AND NEW.status = 'on_the_way' THEN
    -- Check if notification already exists (prevent duplicates)
    SELECT id INTO v_existing_notification_id
    FROM notifications
    WHERE user_id = NEW.merchant_id
      AND type IN ('order_on_the_way', 'order_status_update')
      AND (data->>'order_id')::uuid = NEW.id
      AND created_at >= NOW() - INTERVAL '10 seconds'
    LIMIT 1;
    
    -- Only create notification if it doesn't already exist
    IF v_existing_notification_id IS NULL THEN
      -- Get driver name and customer info
      SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
      v_customer_name := NEW.customer_name;
      v_customer_phone := NEW.customer_phone;
      
      -- Insert detailed notification for merchant (includes customer name and phone)
      INSERT INTO notifications (user_id, title, body, type, data)
      VALUES (
        NEW.merchant_id,
        '🚗 السائق في الطريق',
        'السائق ' || COALESCE(v_driver_name, 'السائق') || ' في طريقه لتوصيل طلب ' || 
        COALESCE(v_customer_name, 'العميل') ||
        CASE WHEN v_customer_phone IS NOT NULL THEN ' (' || v_customer_phone || ')' ELSE '' END,
        'order_on_the_way',
        jsonb_build_object(
          'order_id', NEW.id,
          'status', 'on_the_way',
          'driver_name', v_driver_name,
          'customer_name', v_customer_name,
          'customer_phone', v_customer_phone
        )
      );
      
      RAISE NOTICE 'Created detailed on_the_way notification for merchant % order %', NEW.merchant_id, NEW.id;
    ELSE
      RAISE NOTICE 'Skipped duplicate on_the_way notification for merchant % order % (existing: %)', 
        NEW.merchant_id, NEW.id, v_existing_notification_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_merchant_order_on_the_way IS 
  'Notifies merchant when order is on the way. Includes customer name and phone in notification body. Includes deduplication.';

-- =====================================================================================
-- 3. REPLACE notify_merchant_order_delivered() WITH DETAILED VERSION
-- =====================================================================================
-- Keep the version that includes customer name in the body (already done in previous migration)
-- But ensure it includes customer phone if available
CREATE OR REPLACE FUNCTION notify_merchant_order_delivered()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_driver_name TEXT;
  v_customer_name TEXT;
  v_customer_phone TEXT;
  v_existing_notification_id UUID;
BEGIN
  -- Only notify when status changes TO 'delivered'
  IF OLD.status != 'delivered' AND NEW.status = 'delivered' THEN
    -- Check if notification already exists (prevent duplicates)
    SELECT id INTO v_existing_notification_id
    FROM notifications
    WHERE user_id = NEW.merchant_id
      AND type = 'order_delivered'
      AND (data->>'order_id')::uuid = NEW.id
      AND created_at >= NOW() - INTERVAL '10 seconds'
    LIMIT 1;
    
    -- Only create notification if it doesn't already exist
    IF v_existing_notification_id IS NULL THEN
      -- Get driver name and customer info
      SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
      v_customer_name := NEW.customer_name;
      v_customer_phone := NEW.customer_phone;
      
      -- Insert detailed notification for merchant (includes customer name and phone)
      INSERT INTO notifications (user_id, title, body, type, data)
      VALUES (
        NEW.merchant_id,
        '🎉 تم التسليم',
        'تم تسليم طلب ' || COALESCE(v_customer_name, 'العميل') ||
        CASE WHEN v_customer_phone IS NOT NULL THEN ' (' || v_customer_phone || ')' ELSE '' END || 
        ' بنجاح' || E'\n' ||
        'السائق: ' || COALESCE(v_driver_name, 'غير معروف'),
        'order_delivered',
        jsonb_build_object(
          'order_id', NEW.id,
          'driver_name', v_driver_name,
          'customer_name', v_customer_name,
          'customer_phone', v_customer_phone,
          'delivery_fee', NEW.delivery_fee,
          'total_amount', NEW.total_amount
        )
      );
      
      RAISE NOTICE 'Created detailed delivered notification for merchant % order %', NEW.merchant_id, NEW.id;
    ELSE
      RAISE NOTICE 'Skipped duplicate delivered notification for merchant % order % (existing: %)', 
        NEW.merchant_id, NEW.id, v_existing_notification_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_merchant_order_delivered IS 
  'Notifies merchant when order is delivered. Includes customer name and phone in notification body. Includes deduplication.';

-- =====================================================================================
-- 4. DELETE GENERALIZED NOTIFICATIONS (KEEP ONLY DETAILED ONES)
-- =====================================================================================
-- Remove notifications that don't include customer information in the body
-- These are the "generalized" notifications that should be removed
DO $$
DECLARE
  deleted_count INT;
BEGIN
  -- Delete generalized "accepted" notifications (body doesn't contain customer name)
  -- Generalized messages: 'السائق قبل الطلب وهو في طريقه للاستلام'
  DELETE FROM notifications n
  USING users u
  WHERE n.user_id = u.id
    AND u.role = 'merchant'
    AND n.type = 'order_accepted'
    AND n.created_at >= NOW() - INTERVAL '30 days'
    AND n.body = 'السائق قبل الطلب وهو في طريقه للاستلام';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % generalized accepted notifications', deleted_count;
  
  -- Delete generalized "on_the_way" notifications (body doesn't contain customer name)
  -- Generalized messages: 'السائق في طريقه للتوصيل', 'السائق في طريقه لتسليم طلبك'
  DELETE FROM notifications n
  USING users u
  WHERE n.user_id = u.id
    AND u.role = 'merchant'
    AND n.type IN ('order_on_the_way', 'order_status_update')
    AND n.created_at >= NOW() - INTERVAL '30 days'
    AND (
      n.body = 'السائق في طريقه للتوصيل'
      OR n.body = 'السائق في طريقه لتسليم طلبك'
    );
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % generalized on_the_way notifications', deleted_count;
  
  -- Delete generalized "delivered" notifications (body doesn't contain customer name)
  -- Generalized message: 'تم تسليم الطلب بنجاح'
  -- Keep the one that says 'تم تسليم طلب [customer] بنجاح'
  DELETE FROM notifications n
  USING users u
  WHERE n.user_id = u.id
    AND u.role = 'merchant'
    AND n.type = 'order_delivered'
    AND n.created_at >= NOW() - INTERVAL '30 days'
    AND n.body = 'تم تسليم الطلب بنجاح';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % generalized delivered notifications', deleted_count;
END $$;

COMMIT;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- 1. REPLACED FUNCTIONS:
--    - notify_merchant_order_accepted(): Now includes customer name and phone in body
--    - notify_merchant_order_on_the_way(): Now includes customer name and phone in body
--    - notify_merchant_order_delivered(): Now includes customer name and phone in body
-- 
-- 2. DELETED NOTIFICATIONS:
--    - Removed generalized notifications that don't include customer information
--    - Kept detailed notifications that include customer name/phone
-- 
-- 3. DEDUPLICATION:
--    - All functions now check for existing notifications within 10 seconds
--    - Prevents duplicate notifications even if triggers fire multiple times
-- 
-- 4. NOTIFICATION BODY FORMAT:
--    - Accepted: "قبل السائق [driver] طلب [customer] ([phone])\nوهو في طريقه للاستلام"
--    - On the way: "السائق [driver] في طريقه لتوصيل طلب [customer] ([phone])"
--    - Delivered: "تم تسليم طلب [customer] ([phone]) بنجاح\nالسائق: [driver]"
-- =====================================================================================

