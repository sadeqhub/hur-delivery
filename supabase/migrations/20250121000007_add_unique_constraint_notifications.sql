-- =====================================================================================
-- ADD UNIQUE CONSTRAINT TO PREVENT DUPLICATE NOTIFICATIONS
-- =====================================================================================
-- This migration adds a unique constraint to prevent duplicate notifications
-- for the same order event (accepted, on_the_way, delivered) for the same user.
-- 
-- Problem:
-- Merchants are receiving multiple notifications for the same order status update
-- even with deduplication logic. We need database-level enforcement.
-- 
-- Solution:
-- Create a unique partial index on (user_id, type, order_id) for order status
-- notifications. This ensures only one notification per order/user/type combination
-- can exist in the database.
-- =====================================================================================

BEGIN;

-- =====================================================================================
-- 1. CLEAN UP EXISTING DUPLICATE NOTIFICATIONS (KEEP FIRST ONE)
-- =====================================================================================
-- Remove duplicate notifications, keeping only the first (oldest) one for each
-- order/user/type combination
-- IMPORTANT: We need to remove ALL duplicates, not just recent ones, before creating the index

DO $$
DECLARE
  deleted_count INT;
  duplicate_count INT;
BEGIN
  -- Delete duplicates, keeping the oldest one for each user/type/order combination
  -- Use a subquery with ROW_NUMBER() to identify duplicates
  WITH duplicate_notifications AS (
    SELECT 
      n.id,
      ROW_NUMBER() OVER (
        PARTITION BY n.user_id, n.type, (n.data->>'order_id')::uuid
        ORDER BY n.created_at ASC, n.id ASC  -- Add id as tiebreaker for same timestamp
      ) AS rn
    FROM notifications n
    WHERE n.type IN ('order_accepted', 'order_on_the_way', 'order_delivered', 'order_status_update')
      AND (n.data->>'order_id')::uuid IS NOT NULL
  )
  DELETE FROM notifications
  WHERE id IN (
    SELECT id FROM duplicate_notifications WHERE rn > 1
  );
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % duplicate order status notifications', deleted_count;
  
  -- Verify no duplicates remain (for debugging)
  SELECT COUNT(*) INTO duplicate_count
  FROM (
    SELECT n.user_id, n.type, (n.data->>'order_id')::uuid AS order_id, COUNT(*) AS cnt
    FROM notifications n
    WHERE n.type IN ('order_accepted', 'order_on_the_way', 'order_delivered', 'order_status_update')
      AND (n.data->>'order_id')::uuid IS NOT NULL
    GROUP BY n.user_id, n.type, (n.data->>'order_id')::uuid
    HAVING COUNT(*) > 1
  ) duplicates;
  
  IF duplicate_count > 0 THEN
    RAISE WARNING 'Still found % duplicate notification groups after cleanup!', duplicate_count;
  ELSE
    RAISE NOTICE 'No duplicates found - safe to create unique index';
  END IF;
END $$;

-- =====================================================================================
-- 2. CREATE UNIQUE PARTIAL INDEX ON NOTIFICATIONS
-- =====================================================================================
-- Create a unique index that prevents duplicate notifications for the same
-- order/user/type combination for order status notifications
-- 
-- Note: We use a partial index (WHERE clause) to only apply this constraint
-- to order status notifications, not all notifications

-- Drop existing index if it exists
DROP INDEX IF EXISTS idx_notifications_unique_order_status;

-- Create unique partial index
-- This ensures: one notification per (user_id, type, order_id) combination
-- Only applies to order status notification types
CREATE UNIQUE INDEX idx_notifications_unique_order_status
ON notifications (
  user_id, 
  type, 
  ((data->>'order_id')::uuid)
)
WHERE type IN ('order_accepted', 'order_on_the_way', 'order_delivered', 'order_status_update')
  AND (data->>'order_id')::uuid IS NOT NULL;

COMMENT ON INDEX idx_notifications_unique_order_status IS 
  'Prevents duplicate order status notifications for the same user/order/type combination';

-- =====================================================================================
-- 3. SIMPLIFY NOTIFICATION FUNCTIONS (REMOVE DEDUPLICATION LOGIC)
-- =====================================================================================
-- Since the database now enforces uniqueness, we can simplify the notification
-- functions to remove the deduplication checks. However, we still need to handle
-- the case where a notification already exists (to avoid errors).

-- Update notify_merchant_order_accepted to use INSERT ... ON CONFLICT
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
BEGIN
  -- Only notify when status changes TO 'accepted'
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    -- Get driver name and customer info
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    v_customer_phone := NEW.customer_phone;
    
    -- Insert notification (unique index will prevent duplicates)
    -- Use exception handling to silently ignore duplicate violations
    BEGIN
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
    EXCEPTION
      WHEN unique_violation THEN
        -- Duplicate notification already exists, silently ignore
        NULL;
    END;
    
    RAISE NOTICE 'Created/skipped accepted notification for merchant % order %', NEW.merchant_id, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_merchant_order_accepted IS 
  'Notifies merchant when order is accepted. Includes customer name and phone. Database enforces uniqueness.';

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
BEGIN
  -- Only notify when status changes TO 'on_the_way'
  IF OLD.status != 'on_the_way' AND NEW.status = 'on_the_way' THEN
    -- Get driver name and customer info
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    v_customer_phone := NEW.customer_phone;
    
    -- Insert notification (unique index will prevent duplicates)
    -- Use exception handling to silently ignore duplicate violations
    BEGIN
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
    EXCEPTION
      WHEN unique_violation THEN
        -- Duplicate notification already exists, silently ignore
        NULL;
    END;
    
    RAISE NOTICE 'Created/skipped on_the_way notification for merchant % order %', NEW.merchant_id, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_merchant_order_on_the_way IS 
  'Notifies merchant when order is on the way. Includes customer name and phone. Database enforces uniqueness.';

-- Update notify_merchant_order_delivered
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
BEGIN
  -- Only notify when status changes TO 'delivered'
  IF OLD.status != 'delivered' AND NEW.status = 'delivered' THEN
    -- Get driver name and customer info
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    v_customer_phone := NEW.customer_phone;
    
    -- Insert notification (unique index will prevent duplicates)
    -- Use exception handling to silently ignore duplicate violations
    BEGIN
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
    EXCEPTION
      WHEN unique_violation THEN
        -- Duplicate notification already exists, silently ignore
        NULL;
    END;
    
    RAISE NOTICE 'Created/skipped delivered notification for merchant % order %', NEW.merchant_id, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_merchant_order_delivered IS 
  'Notifies merchant when order is delivered. Includes customer name and phone. Database enforces uniqueness.';

COMMIT;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- 1. UNIQUE INDEX:
--    - Creates a unique constraint on (user_id, type, order_id) for order status notifications
--    - Only applies to notification types: order_accepted, order_on_the_way, order_delivered, order_status_update
--    - Uses a partial index (WHERE clause) so it doesn't affect other notification types
--    - Prevents duplicates at the database level, even with concurrent inserts
-- 
-- 2. SIMPLIFIED FUNCTIONS:
--    - Removed complex deduplication logic and advisory locks
--    - Use INSERT ... ON CONFLICT DO NOTHING to handle duplicates gracefully
--    - Much simpler and more reliable than application-level checks
-- 
-- 3. DUPLICATE CLEANUP:
--    - Removes existing duplicate notifications before creating the constraint
--    - Keeps the oldest notification for each user/order/type combination
-- 
-- 4. HOW IT WORKS:
--    - When a trigger tries to insert a duplicate notification, PostgreSQL detects
--      the unique constraint violation and the ON CONFLICT clause prevents the error
--    - The second (and subsequent) attempts to insert the same notification are silently ignored
--    - This works even with concurrent trigger executions
-- 
-- 5. BENEFITS:
--    - Database-level enforcement (most reliable)
--    - No race conditions (database handles concurrency)
--    - Simpler code (no complex locking logic)
--    - Better performance (database handles it efficiently)
-- =====================================================================================

