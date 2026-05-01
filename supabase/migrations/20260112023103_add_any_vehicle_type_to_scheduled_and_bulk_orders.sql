-- =====================================================================================
-- ADD "ANY" VEHICLE TYPE SUPPORT TO SCHEDULED_ORDERS AND BULK_ORDERS
-- =====================================================================================
-- Updates scheduled_orders and bulk_orders tables to allow 'any' vehicle type
-- This matches the support added to the orders table in 20251021030000_add_any_vehicle_type.sql
-- Also fixes process_scheduled_orders() function to handle 'any' vehicle type
-- =====================================================================================

-- Update scheduled_orders constraint to allow 'any'
ALTER TABLE scheduled_orders DROP CONSTRAINT IF EXISTS scheduled_orders_vehicle_type_check;
ALTER TABLE scheduled_orders 
  ADD CONSTRAINT scheduled_orders_vehicle_type_check 
  CHECK (vehicle_type IN ('motorcycle', 'car', 'truck', 'motorbike', 'any'));

-- Update bulk_orders constraint to allow 'any' for consistency
ALTER TABLE bulk_orders DROP CONSTRAINT IF EXISTS bulk_orders_vehicle_type_check;
ALTER TABLE bulk_orders 
  ADD CONSTRAINT bulk_orders_vehicle_type_check 
  CHECK (vehicle_type IN ('motorcycle', 'car', 'truck', 'motorbike', 'any'));

-- =====================================================================================
-- FIX process_scheduled_orders() FUNCTION TO HANDLE 'any' VEHICLE TYPE
-- =====================================================================================
-- The function currently rejects 'any' and incorrectly normalizes 'motorbike' to 'motorcycle'
-- But the orders table uses 'motorbike', not 'motorcycle'
-- Need to:
-- 1. Accept 'any' vehicle type
-- 2. Normalize 'motorcycle' to 'motorbike' (to match orders table constraint)
-- 3. Pass 'any' through to orders table
-- =====================================================================================

CREATE OR REPLACE FUNCTION process_scheduled_orders()
RETURNS TABLE(processed_count INTEGER, failed_count INTEGER) AS $$
DECLARE
  scheduled_item RECORD;
  new_order_id UUID;
  processed INTEGER := 0;
  failed INTEGER := 0;
  normalized_vehicle_type TEXT;
BEGIN
  RAISE NOTICE '====================================';
  RAISE NOTICE 'PROCESSING SCHEDULED ORDERS';
  RAISE NOTICE 'Current Time: %', NOW();
  RAISE NOTICE '====================================';
  
  -- Find all scheduled orders that are due (scheduled_date + scheduled_time <= NOW())
  FOR scheduled_item IN
    SELECT * FROM scheduled_orders
    WHERE status = 'scheduled'
    AND (scheduled_date + scheduled_time) <= NOW()
    ORDER BY (scheduled_date + scheduled_time) ASC
  LOOP
    BEGIN
      RAISE NOTICE '------------------------------------';
      RAISE NOTICE 'Processing scheduled order: %', scheduled_item.id;
      RAISE NOTICE '  Merchant ID: %', scheduled_item.merchant_id;
      RAISE NOTICE '  Customer: %', scheduled_item.customer_name;
      RAISE NOTICE '  Phone: %', scheduled_item.customer_phone;
      RAISE NOTICE '  Scheduled for: % %', scheduled_item.scheduled_date, scheduled_item.scheduled_time;
      RAISE NOTICE '  Vehicle Type: "%"', scheduled_item.vehicle_type;
      
      -- Validate vehicle type
      IF scheduled_item.vehicle_type IS NULL THEN
        RAISE EXCEPTION 'Vehicle type cannot be NULL';
      END IF;
      
      -- Normalize vehicle type to match orders table constraint ('motorbike', 'car', 'truck', 'any')
      -- The orders table uses 'motorbike', not 'motorcycle'
      normalized_vehicle_type := scheduled_item.vehicle_type;
      
      IF normalized_vehicle_type = 'motorcycle' THEN
        normalized_vehicle_type := 'motorbike';
        RAISE NOTICE '  Normalized vehicle type from motorcycle to motorbike';
      END IF;
      
      -- Accept: motorbike, car, truck, any (matching orders table constraint)
      IF normalized_vehicle_type NOT IN ('motorbike', 'car', 'truck', 'any') THEN
        RAISE EXCEPTION 'Invalid vehicle type: "%". Must be one of: motorcycle, car, truck, any', scheduled_item.vehicle_type;
      END IF;
      
      -- Create the order
      INSERT INTO orders (
        merchant_id,
        customer_name,
        customer_phone,
        pickup_address,
        delivery_address,
        pickup_latitude,
        pickup_longitude,
        delivery_latitude,
        delivery_longitude,
        vehicle_type,
        total_amount,
        delivery_fee,
        notes,
        status,
        created_at,
        updated_at
      ) VALUES (
        scheduled_item.merchant_id,
        scheduled_item.customer_name,
        scheduled_item.customer_phone,
        scheduled_item.pickup_address,
        scheduled_item.delivery_address,
        scheduled_item.pickup_latitude,
        scheduled_item.pickup_longitude,
        scheduled_item.delivery_latitude,
        scheduled_item.delivery_longitude,
        normalized_vehicle_type,
        scheduled_item.total_amount,
        scheduled_item.delivery_fee,
        scheduled_item.notes,
        'pending',
        NOW(),
        NOW()
      )
      RETURNING id INTO new_order_id;
      
      RAISE NOTICE '  ✓ Created order: %', new_order_id;
      
      -- Update scheduled order status
      UPDATE scheduled_orders
      SET status = 'posted',
          created_order_id = new_order_id,
          updated_at = NOW()
      WHERE id = scheduled_item.id;
      
      processed := processed + 1;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '  ✗ FAILED to create order for scheduled item %', scheduled_item.id;
      RAISE WARNING '  Error: %', SQLERRM;
      RAISE WARNING '  SQL State: %', SQLSTATE;
      
      -- Update scheduled order to failed status
      UPDATE scheduled_orders
      SET status = 'failed',
          updated_at = NOW()
      WHERE id = scheduled_item.id;
      
      failed := failed + 1;
    END;
  END LOOP;
  
  IF processed > 0 OR failed > 0 THEN
    RAISE NOTICE '====================================';
    RAISE NOTICE 'SCHEDULED ORDERS PROCESSED';
    RAISE NOTICE 'Posted: % | Failed: %', processed, failed;
    RAISE NOTICE '====================================';
  END IF;
  
  RETURN QUERY SELECT processed, failed;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- DONE! "Any" vehicle type is now supported in scheduled_orders and bulk_orders
-- The process_scheduled_orders() function now properly handles 'any' vehicle type
-- =====================================================================================

