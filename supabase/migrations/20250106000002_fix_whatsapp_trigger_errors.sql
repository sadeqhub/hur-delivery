-- Fix WhatsApp trigger to not block order creation if it fails
-- The trigger should be non-blocking and handle errors gracefully

CREATE OR REPLACE FUNCTION trigger_whatsapp_location_request()
RETURNS TRIGGER AS $$
DECLARE
  customer_phone TEXT;
  merchant_name TEXT;
BEGIN
  -- Get customer phone number from the new order
  customer_phone := NEW.customer_phone;
  
  -- Only trigger for new orders (not updates)
  IF TG_OP = 'INSERT' THEN
    BEGIN
      -- Get merchant name
      SELECT name INTO merchant_name
      FROM users
      WHERE id = NEW.merchant_id;
      
      -- Insert a record to track the WhatsApp request
      INSERT INTO whatsapp_location_requests (order_id, customer_phone)
      VALUES (NEW.id, customer_phone)
      ON CONFLICT (order_id) DO NOTHING;
      
      -- Try to call the Wasso edge function (non-blocking)
      -- If this fails, it won't block the order creation
      BEGIN
        PERFORM net.http_post(
          url := current_setting('app.settings.supabase_url') || '/functions/v1/send-location-request',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
          ),
          body := jsonb_build_object(
            'order_id', NEW.id,
            'customer_phone', customer_phone,
            'customer_name', NEW.customer_name,
            'merchant_name', merchant_name
          )
        );
      EXCEPTION
        WHEN OTHERS THEN
          -- Log the error but don't fail the order creation
          RAISE WARNING 'Failed to send WhatsApp location request for order %: %', NEW.id, SQLERRM;
      END;
    EXCEPTION
      WHEN OTHERS THEN
        -- Log the error but don't fail the order creation
        RAISE WARNING 'Error in WhatsApp trigger for order %: %', NEW.id, SQLERRM;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure the trigger exists
DROP TRIGGER IF EXISTS trigger_order_whatsapp_request ON orders;
CREATE TRIGGER trigger_order_whatsapp_request
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_whatsapp_location_request();

-- Add unique constraint to whatsapp_location_requests if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'whatsapp_location_requests_order_id_key'
  ) THEN
    ALTER TABLE whatsapp_location_requests 
    ADD CONSTRAINT whatsapp_location_requests_order_id_key UNIQUE (order_id);
  END IF;
END $$;

COMMENT ON FUNCTION trigger_whatsapp_location_request() IS 'Sends WhatsApp location request via Wasso API when order is created (non-blocking, errors are logged but do not fail order creation)';

