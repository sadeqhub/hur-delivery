-- Migration to switch WhatsApp automation from old system to Wasso API
-- This updates the trigger to use the new send-location-request function

-- Drop the old trigger
DROP TRIGGER IF EXISTS trigger_order_whatsapp_request ON orders;

-- Update the trigger function to call the new Wasso edge function
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
    -- Get merchant name
    SELECT name INTO merchant_name
    FROM users
    WHERE id = NEW.merchant_id;
    
    -- Insert a record to track the WhatsApp request
    INSERT INTO whatsapp_location_requests (order_id, customer_phone)
    VALUES (NEW.id, customer_phone);
    
    -- Call the new Wasso edge function to send WhatsApp message
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
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger on orders table
CREATE TRIGGER trigger_order_whatsapp_request
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_whatsapp_location_request();

-- Add comment
COMMENT ON FUNCTION trigger_whatsapp_location_request() IS 'Automatically sends WhatsApp location request via Wasso API when order is created';

