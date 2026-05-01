-- =====================================================================================
-- DIAGNOSE SUPPORT NOTIFICATION TRIGGER
-- =====================================================================================
-- This script helps diagnose why the support notification edge function
-- might not be triggering when users send support messages
-- =====================================================================================

-- 1. Check if pg_net extension is enabled
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
    THEN '✅ pg_net extension is enabled'
    ELSE '❌ pg_net extension is NOT enabled - Required for HTTP requests'
  END as pg_net_status;

-- 2. Check database settings for Supabase URL and service role key
SELECT 
  name,
  setting,
  CASE 
    WHEN name = 'app.settings.supabase_url' AND (setting IS NULL OR setting = '') 
    THEN '❌ NOT CONFIGURED'
    WHEN name = 'app.settings.supabase_url' 
    THEN '✅ Configured: ' || SUBSTRING(setting, 1, 30) || '...'
    WHEN name = 'app.settings.service_role_key' AND (setting IS NULL OR setting = '') 
    THEN '❌ NOT CONFIGURED'
    WHEN name = 'app.settings.service_role_key' 
    THEN '✅ Configured (hidden)'
    ELSE 'Unknown'
  END as status
FROM pg_settings 
WHERE name LIKE 'app.settings%'
ORDER BY name;

-- 3. Check if send_message function exists and has the support notification logic
SELECT 
  p.proname as function_name,
  pg_get_functiondef(p.oid) LIKE '%wasso-send-support-notification%' as has_notification_code,
  pg_get_functiondef(p.oid) LIKE '%v_conversation_is_support%' as has_support_check,
  pg_get_functiondef(p.oid) LIKE '%net.http_post%' as uses_http_post
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'send_message'
  AND n.nspname = 'public';

-- 4. Test if we can call net.http_post (will show error if extension missing)
DO $$
DECLARE
  v_extension_exists BOOLEAN;
  v_test_result BIGINT;
BEGIN
  -- Check if extension exists
  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') INTO v_extension_exists;
  
  IF NOT v_extension_exists THEN
    RAISE NOTICE '❌ pg_net extension not found. Cannot test HTTP POST.';
    RAISE NOTICE '   Fix: CREATE EXTENSION IF NOT EXISTS pg_net;';
  ELSE
    RAISE NOTICE '✅ pg_net extension exists. Testing HTTP POST...';
    -- Try a test call (this will fail but show if the function is accessible)
    BEGIN
      SELECT extensions.net.http_post(
        url := 'https://httpbin.org/post',
        headers := jsonb_build_object('Content-Type', 'application/json'),
        body := jsonb_build_object('test', true)
      ) INTO v_test_result;
      RAISE NOTICE '✅ HTTP POST test successful. Request ID: %', v_test_result;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '⚠️  HTTP POST test failed: %', SQLERRM;
    END;
  END IF;
END $$;

-- 5. Check recent support messages (to see if condition is matching)
SELECT 
  m.id,
  m.conversation_id,
  m.sender_id,
  u.role as sender_role,
  u.name as sender_name,
  c.is_support,
  m.created_at,
  CASE 
    WHEN c.is_support = true AND u.role != 'admin' 
    THEN '✅ Should trigger notification'
    ELSE '⏭️  Will NOT trigger notification'
  END as should_notify
FROM messages m
JOIN conversations c ON c.id = m.conversation_id
JOIN users u ON u.id = m.sender_id
WHERE c.is_support = true
ORDER BY m.created_at DESC
LIMIT 10;

-- 6. Show how to configure the settings if missing
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_settings 
      WHERE name = 'app.settings.supabase_url' 
      AND setting IS NOT NULL 
      AND setting != ''
    ) AND EXISTS (
      SELECT 1 FROM pg_settings 
      WHERE name = 'app.settings.service_role_key' 
      AND setting IS NOT NULL 
      AND setting != ''
    )
    THEN '✅ All settings configured'
    ELSE '❌ Missing configuration. Run these commands:'
  END as configuration_status;

-- Show configuration commands
SELECT 
  'ALTER DATABASE postgres SET app.settings.supabase_url TO ''https://bvtoxmmiitznagsbubhg.supabase.co'';' as configure_url,
  'ALTER DATABASE postgres SET app.settings.service_role_key TO ''YOUR_SERVICE_ROLE_KEY'';' as configure_key
WHERE NOT EXISTS (
  SELECT 1 FROM pg_settings 
  WHERE name = 'app.settings.supabase_url' 
  AND setting IS NOT NULL 
  AND setting != ''
) OR NOT EXISTS (
  SELECT 1 FROM pg_settings 
  WHERE name = 'app.settings.service_role_key' 
  AND setting IS NOT NULL 
  AND setting != ''
);















