-- =====================================================================================
-- ADD WHAPI API KEY TO SYSTEM SETTINGS
-- =====================================================================================
-- Migrates from Wasso to Whapi.Cloud for WhatsApp messaging.
-- The edge functions (send-location-request, otpiq-webhook,
-- daily-summary-email) now use Whapi.Cloud API and read this key.
-- =====================================================================================

INSERT INTO system_settings (key, value, value_type, description, updated_at)
VALUES (
  'whapi_api_key',
  '1YCNHkB3X8RAPApvRCyiyl69N5EWjBW5',
  'string',
  'Whapi.Cloud API token for WhatsApp messaging (Bearer auth)',
  NOW()
)
ON CONFLICT (key) 
DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = NOW();
