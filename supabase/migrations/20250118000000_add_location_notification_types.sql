-- =====================================================================================
-- ADD LOCATION NOTIFICATION TYPES
-- =====================================================================================
-- This migration adds 'customer_location_updated' and 'location_received' to the
-- allowed notification types for customer location updates via WhatsApp
-- =====================================================================================

BEGIN;

-- Drop the old constraint
ALTER TABLE notifications 
DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new constraint with location notification types included
ALTER TABLE notifications 
ADD CONSTRAINT notifications_type_check CHECK (
  type IN (
    'order_assigned', 
    'order_accepted', 
    'order_status_update',
    'order_on_the_way',
    'order_delivered', 
    'order_cancelled',
    'order_rejected',
    'payment', 
    'system',
    'message',
    'customer_location_updated',  -- When customer updates location via WhatsApp
    'location_received'            -- When merchant receives customer location
  )
);

-- Add comment
COMMENT ON CONSTRAINT notifications_type_check ON notifications IS 
'Ensures notification type is one of the allowed values including location notification types';

COMMIT;

