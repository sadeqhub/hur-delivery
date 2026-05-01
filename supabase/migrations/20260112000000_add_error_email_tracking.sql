-- Add column to track last error email sent timestamp
-- This prevents spamming admin with error emails (rate limit: once every 6 hours)

ALTER TABLE whatsapp_location_requests
ADD COLUMN IF NOT EXISTS last_error_email_sent_at TIMESTAMPTZ;

COMMENT ON COLUMN whatsapp_location_requests.last_error_email_sent_at IS 
  'Timestamp of the last error email sent to admin when WhatsApp message fails. Used to rate limit error notifications to once every 6 hours.';

