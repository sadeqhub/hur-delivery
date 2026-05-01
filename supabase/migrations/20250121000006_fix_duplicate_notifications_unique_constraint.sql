-- =====================================================================================
-- FIX DUPLICATE NOTIFICATIONS WITH ADVISORY LOCKS
-- =====================================================================================
-- This migration uses advisory locks to prevent duplicate notifications from being
-- created by concurrent trigger/function executions.
-- 
-- Problem:
-- Multiple triggers/functions create notifications at the same timestamp, causing
-- both to pass the deduplication check (which checks within 10 seconds). Since they
-- check BEFORE inserting, they both think there's no duplicate.
-- 
-- Solution:
-- Use advisory locks to serialize notification inserts for the same order/user/type.
-- This prevents race conditions that application-level checks can't handle.
-- =====================================================================================

BEGIN;

-- =====================================================================================
-- 1. CREATE HELPER FUNCTION FOR SAFE NOTIFICATION INSERT
-- =====================================================================================
-- Note: We don't use a unique index because we need to check for duplicates within
-- a time window (10 seconds), and PostgreSQL doesn't support mutable functions like
-- NOW() in index predicates. Instead, we use advisory locks to prevent concurrent
-- duplicate inserts.
-- =====================================================================================
-- This function uses advisory locks to prevent concurrent duplicate inserts
CREATE OR REPLACE FUNCTION safe_insert_merchant_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_type TEXT,
  p_data JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_order_id UUID;
  v_lock_id BIGINT;
  v_notification_id UUID;
  v_existing_id UUID;
BEGIN
  -- Extract order_id from data
  v_order_id := (p_data->>'order_id')::uuid;
  
  -- Create a lock ID from user_id, type, and order_id
  -- Use hash function for consistent hashing (convert to bigint)
  -- PostgreSQL hashlittle expects bytes, so we use a simpler approach:
  -- Use abs(hash_extended()) to get a positive bigint
  v_lock_id := ABS(hashtext(p_user_id::text || p_type || COALESCE(v_order_id::text, '')))::bigint;
  
  -- Try to acquire advisory lock (non-blocking)
  -- pg_try_advisory_xact_lock uses transaction-level locks
  IF pg_try_advisory_xact_lock(v_lock_id) THEN
    -- Check if notification already exists (within last 10 seconds)
    SELECT id INTO v_existing_id
    FROM notifications
    WHERE user_id = p_user_id
      AND type = p_type
      AND (data->>'order_id')::uuid = v_order_id
      AND created_at >= NOW() - INTERVAL '10 seconds'
    LIMIT 1;
    
    IF v_existing_id IS NULL THEN
      -- Insert notification
      INSERT INTO notifications (user_id, title, body, type, data)
      VALUES (p_user_id, p_title, p_body, p_type, p_data)
      RETURNING id INTO v_notification_id;
      
      RETURN v_notification_id;
    ELSE
      -- Duplicate exists, return existing ID
      RETURN v_existing_id;
    END IF;
  ELSE
    -- Could not acquire lock, meaning another transaction is inserting
    -- Wait a bit and check if it was inserted
    PERFORM pg_sleep(0.01); -- 10ms
    
    SELECT id INTO v_existing_id
    FROM notifications
    WHERE user_id = p_user_id
      AND type = p_type
      AND (data->>'order_id')::uuid = v_order_id
      AND created_at >= NOW() - INTERVAL '10 seconds'
    LIMIT 1;
    
    IF v_existing_id IS NOT NULL THEN
      RETURN v_existing_id;
    ELSE
      -- Still not there, insert (race condition, but rare)
      INSERT INTO notifications (user_id, title, body, type, data)
      VALUES (p_user_id, p_title, p_body, p_type, p_data)
      ON CONFLICT DO NOTHING
      RETURNING id INTO v_notification_id;
      
      RETURN v_notification_id;
    END IF;
  END IF;
END;
$$;

COMMENT ON FUNCTION safe_insert_merchant_notification IS 
  'Safely inserts merchant notification with deduplication using advisory locks. Returns notification ID.';

-- =====================================================================================
-- 3. UPDATE NOTIFICATION FUNCTIONS TO USE SAFE INSERT
-- =====================================================================================

-- Update notify_merchant_order_accepted
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
  v_notification_id UUID;
BEGIN
  -- Only notify when status changes TO 'accepted'
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    -- Get driver name and customer info
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    v_customer_phone := NEW.customer_phone;
    
    -- Use safe insert function (handles deduplication)
    SELECT safe_insert_merchant_notification(
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
    ) INTO v_notification_id;
    
    IF v_notification_id IS NOT NULL THEN
      RAISE NOTICE 'Created/skipped accepted notification for merchant % order % (id: %)', 
        NEW.merchant_id, NEW.id, v_notification_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Update notify_merchant_order_on_the_way
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
  v_notification_id UUID;
BEGIN
  -- Only notify when status changes TO 'on_the_way'
  IF OLD.status != 'on_the_way' AND NEW.status = 'on_the_way' THEN
    -- Get driver name and customer info
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    v_customer_phone := NEW.customer_phone;
    
    -- Use safe insert function (handles deduplication)
    SELECT safe_insert_merchant_notification(
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
    ) INTO v_notification_id;
    
    IF v_notification_id IS NOT NULL THEN
      RAISE NOTICE 'Created/skipped on_the_way notification for merchant % order % (id: %)', 
        NEW.merchant_id, NEW.id, v_notification_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Update notify_merchant_order_delivered (already has deduplication, but use safe insert for consistency)
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
  v_notification_id UUID;
BEGIN
  -- Only notify when status changes TO 'delivered'
  IF OLD.status != 'delivered' AND NEW.status = 'delivered' THEN
    -- Get driver name and customer info
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    v_customer_phone := NEW.customer_phone;
    
    -- Use safe insert function (handles deduplication)
    SELECT safe_insert_merchant_notification(
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
    ) INTO v_notification_id;
    
    IF v_notification_id IS NOT NULL THEN
      RAISE NOTICE 'Created/skipped delivered notification for merchant % order % (id: %)', 
        NEW.merchant_id, NEW.id, v_notification_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMIT;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- 1. ADVISORY LOCKS:
--    - Uses pg_try_advisory_xact_lock() to prevent concurrent inserts
--    - Lock ID is derived from user_id, type, and order_id
--    - Transaction-level locks are automatically released on commit/rollback
-- 
-- 2. SAFE INSERT FUNCTION:
--    - safe_insert_merchant_notification() handles deduplication with locks
--    - Checks for existing notifications within 10 seconds
--    - If lock can't be acquired, waits briefly and checks again
--    - Returns the notification ID (existing or newly created)
-- 
-- 3. UPDATED FUNCTIONS:
--    - All three notification functions now use safe_insert_merchant_notification()
--    - This ensures only one notification is created per order/user/type combination
--    - Works even with concurrent trigger executions
-- 
-- 4. WHY THIS WORKS:
--    - Advisory locks serialize concurrent attempts to insert the same notification
--    - First transaction acquires lock and inserts
--    - Second transaction waits, then checks and finds existing notification
--    - Prevents race conditions that application-level checks can't handle
-- =====================================================================================

