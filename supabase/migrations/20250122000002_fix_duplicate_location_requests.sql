-- =====================================================================================
-- FIX DUPLICATE LOCATION REQUESTS
-- =====================================================================================
-- Adds a guard to prevent sending duplicate location request messages
-- Checks if a request was already sent before calling the edge function
-- IMPORTANT: This function ONLY works with UPDATE triggers, NOT INSERT triggers
-- =====================================================================================

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
  v_already_sent BOOLEAN;
BEGIN
  -- ONLY work with UPDATE operations (status changes)
  -- Do NOT process INSERT operations - orders should be created with 'pending' status
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;
  
  -- Only trigger when status changes TO 'accepted'
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    customer_phone := NEW.customer_phone;
    
    -- Check if location request was already sent for this order
    SELECT EXISTS(
      SELECT 1 FROM whatsapp_location_requests 
      WHERE order_id = NEW.id 
      AND status IN ('sent', 'delivered', 'location_received')
    ) INTO v_already_sent;
    
    -- Only send if not already sent
    IF NOT v_already_sent THEN
      BEGIN
        -- Get merchant name
        SELECT name INTO merchant_name
        FROM users
        WHERE id = NEW.merchant_id;
        
        -- Insert a record to track the WhatsApp request (ignore if already exists)
        INSERT INTO whatsapp_location_requests (order_id, customer_phone, status)
        VALUES (NEW.id, customer_phone, 'sent')
        ON CONFLICT (order_id) DO UPDATE SET status = 'sent' WHERE whatsapp_location_requests.status = 'failed';
        
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
    ELSE
      RAISE NOTICE 'Location request already sent for order %, skipping duplicate send', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Ensure only one trigger exists (UPDATE trigger for accepted status)
DROP TRIGGER IF EXISTS trigger_order_whatsapp_request ON orders;

CREATE TRIGGER trigger_order_whatsapp_request
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted')
  EXECUTE FUNCTION trigger_whatsapp_location_request();

COMMENT ON FUNCTION trigger_whatsapp_location_request IS 
  'Automatically sends WhatsApp location request via Wasso API when order status changes to accepted (with duplicate prevention)';

