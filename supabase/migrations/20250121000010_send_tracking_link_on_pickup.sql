-- =====================================================================================
-- SEND TRACKING LINK WHEN ORDER STATUS IS ACCEPTED
-- =====================================================================================
-- Creates a trigger that sends a WhatsApp message with tracking link to customer
-- when order status changes to 'accepted' (driver accepts the order)
-- =====================================================================================

-- Enable pg_net extension if not already enabled (for HTTP requests)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    CREATE EXTENSION IF NOT EXISTS pg_net;
    RAISE NOTICE 'pg_net extension enabled';
  ELSE
    RAISE NOTICE 'pg_net extension already enabled';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Could not enable pg_net extension: %', SQLERRM;
    RAISE WARNING 'pg_net may already be installed. Continuing...';
END $$;

-- =====================================================================================
-- FUNCTION: Call Edge Function to Send Tracking Link
-- =====================================================================================

CREATE OR REPLACE FUNCTION send_tracking_link_on_accepted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_request_id BIGINT;
  v_supabase_url TEXT := 'https://bvtoxmmiitznagsbubhg.supabase.co';
  -- Use service role key for internal function calls
  -- Note: This key should be kept secure. In production, consider using a secure vault.
  v_service_role_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjA3OTkxNywiZXhwIjoyMDY3NjU1OTE3fQ.wKOQiltkUnYiZY1LRRkJcZ_8lL7WZZgmpDdHVoDRqqE';
BEGIN
  -- Only trigger when status changes TO 'accepted'
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    RAISE NOTICE 'Order % status changed to accepted, sending tracking link to customer', NEW.id;
    
    -- Call the Edge Function using net.http_post
    BEGIN
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/wasso-send-tracking-link',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body := jsonb_build_object(
          'order_id', NEW.id::text
        )
      ) INTO v_request_id;

      RAISE NOTICE 'Tracking link Edge Function called successfully. Request ID: %', v_request_id;
    EXCEPTION WHEN OTHERS THEN
      -- Log error but don't fail the transaction
      RAISE WARNING 'Failed to call tracking link Edge Function: %', SQLERRM;
    END;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION send_tracking_link_on_accepted IS 
  'Automatically calls the wasso-send-tracking-link Edge Function when order status changes to accepted';

-- =====================================================================================
-- CREATE TRIGGER ON ORDERS TABLE
-- =====================================================================================

DROP TRIGGER IF EXISTS trigger_send_tracking_link_on_order_create ON orders;
DROP TRIGGER IF EXISTS trigger_send_tracking_link_on_pickup ON orders;
CREATE TRIGGER trigger_send_tracking_link_on_accepted
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted')
  EXECUTE FUNCTION send_tracking_link_on_accepted();

COMMENT ON TRIGGER trigger_send_tracking_link_on_accepted ON orders IS 
  'Sends WhatsApp message with tracking link to customer when order status changes to accepted';

