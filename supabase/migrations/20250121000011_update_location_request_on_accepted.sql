-- =====================================================================================
-- UPDATE LOCATION REQUEST TO FIRE ON ORDER ACCEPTED
-- =====================================================================================
-- Updates the WhatsApp location request trigger to fire when order status changes
-- to 'accepted' instead of on order creation
-- =====================================================================================

-- Update the trigger function to fire when status changes to 'accepted'
CREATE OR REPLACE FUNCTION trigger_whatsapp_location_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  customer_phone TEXT;
  merchant_name TEXT;
  v_request_id BIGINT;
  v_supabase_url TEXT := 'https://bvtoxmmiitznagsbubhg.supabase.co';
  v_service_role_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjA3OTkxNywiZXhwIjoyMDY3NjU1OTE3fQ.wKOQiltkUnYiZY1LRRkJcZ_8lL7WZZgmpDdHVoDRqqE';
BEGIN
  -- Only trigger when status changes TO 'accepted'
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    customer_phone := NEW.customer_phone;
    
    BEGIN
      -- Get merchant name
      SELECT name INTO merchant_name
      FROM users
      WHERE id = NEW.merchant_id;
      
      -- Insert a record to track the WhatsApp request (ignore if already exists)
      INSERT INTO whatsapp_location_requests (order_id, customer_phone)
      VALUES (NEW.id, customer_phone)
      ON CONFLICT (order_id) DO NOTHING;
      
      -- Call the Wasso edge function to send WhatsApp message
      BEGIN
        SELECT net.http_post(
          url := v_supabase_url || '/functions/v1/send-location-request',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_service_role_key
          ),
          body := jsonb_build_object(
            'order_id', NEW.id::text,
            'customer_phone', customer_phone,
            'customer_name', NEW.customer_name,
            'merchant_name', merchant_name
          )
        ) INTO v_request_id;

        RAISE NOTICE 'Location request Edge Function called successfully. Request ID: %', v_request_id;
      EXCEPTION WHEN OTHERS THEN
        -- Log error but don't fail the transaction
        RAISE WARNING 'Failed to call location request Edge Function: %', SQLERRM;
      END;
    EXCEPTION WHEN OTHERS THEN
      -- Log error but don't fail the transaction
      RAISE WARNING 'Error in WhatsApp trigger for order %: %', NEW.id, SQLERRM;
    END;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop the old INSERT trigger and create UPDATE trigger
DROP TRIGGER IF EXISTS trigger_order_whatsapp_request ON orders;
CREATE TRIGGER trigger_order_whatsapp_request
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted')
  EXECUTE FUNCTION trigger_whatsapp_location_request();

COMMENT ON FUNCTION trigger_whatsapp_location_request IS 
  'Automatically sends WhatsApp location request via Wasso API when order status changes to accepted';

