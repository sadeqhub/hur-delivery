-- =====================================================================================
-- SET SERVICE ROLE KEY FOR WHATSAPP QUEUE CRON
-- =====================================================================================
-- This script sets the service role key in the system_settings table
-- =====================================================================================
-- 
-- INSTRUCTIONS:
-- 1. Go to Supabase Dashboard > Settings > API
-- 2. Copy your "service_role" key (secret) - it starts with "eyJ..."
-- 3. Replace 'YOUR_SERVICE_ROLE_KEY_HERE' below with your actual key
-- 4. Run this script
-- =====================================================================================

-- Insert or update the service role key in system_settings
INSERT INTO system_settings (key, value, value_type, description, updated_at)
VALUES (
  'supabase_service_role_key',
  'YOUR_SERVICE_ROLE_KEY_HERE',  -- ⚠️ REPLACE THIS WITH YOUR ACTUAL KEY
  'string',
  'Service role key for triggering edge functions from cron jobs',
  NOW()
)
ON CONFLICT (key) 
DO UPDATE SET 
  value = EXCLUDED.value,
  updated_at = NOW();

-- Verify it was set
SELECT 
  key,
  CASE 
    WHEN LENGTH(value) > 50 THEN LEFT(value, 20) || '...' || RIGHT(value, 20)
    ELSE 'Key too short - may be incorrect'
  END as value_preview,
  LENGTH(value) as key_length,
  updated_at
FROM system_settings
WHERE key = 'supabase_service_role_key';

-- Test the function
SELECT 
  'Test Result' as test,
  success,
  message,
  pending_count
FROM trigger_whatsapp_queue_processor();

