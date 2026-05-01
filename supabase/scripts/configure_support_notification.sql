-- =====================================================================================
-- CONFIGURE SUPPORT NOTIFICATION
-- =====================================================================================
-- This script configures the system settings needed for support notifications
-- 
-- INSTRUCTIONS:
-- 1. Get your Service Role Key from: Supabase Dashboard > Settings > API > Service Role Key
-- 2. Click "Reveal" and copy the entire key (it's a long JWT token starting with eyJ...)
-- 3. Replace 'YOUR_SERVICE_ROLE_KEY_HERE' below with your actual service role key
-- 4. Run this script
-- =====================================================================================

-- Step 1: Enable pg_net extension (required for HTTP requests)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Step 2: Configure Supabase Project Reference
-- Replace 'bvtoxmmiitznagsbubhg' if your project ref is different
INSERT INTO system_settings (key, value, value_type, description)
VALUES (
  'supabase_project_ref',
  'bvtoxmmiitznagsbubhg',  -- Replace if different
  'string',
  'Supabase project reference for Edge Function URLs'
)
ON CONFLICT (key) DO UPDATE 
SET 
  value = EXCLUDED.value,
  updated_at = NOW();

-- Step 3: Configure Service Role Key
-- ⚠️ REPLACE 'YOUR_SERVICE_ROLE_KEY_HERE' with your actual service role key from the dashboard
INSERT INTO system_settings (key, value, value_type, description, is_public)
VALUES (
  'supabase_service_role_key',
  'YOUR_SERVICE_ROLE_KEY_HERE',  -- ⚠️ REPLACE THIS!
  'string',
  'Supabase service role key for Edge Function authentication (secret)',
  false
)
ON CONFLICT (key) DO UPDATE 
SET 
  value = EXCLUDED.value,
  updated_at = NOW();

-- Step 4: Verify configuration
SELECT 
  key,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN '***HIDDEN***'
    ELSE value
  END as value,
  CASE 
    WHEN key = 'supabase_project_ref' 
      AND (value IS NULL OR value = '' OR value = 'YOUR_PROJECT_REF') 
    THEN '❌ NOT CONFIGURED - Check project ref above'
    WHEN key = 'supabase_project_ref' 
      AND value LIKE '%.supabase.co' 
    THEN '⚠️  WRONG - Remove .supabase.co, use just the project ref'
    WHEN key = 'supabase_project_ref' 
      AND value LIKE 'https://%' 
    THEN '⚠️  WRONG - Remove https://, use just the project ref'
    WHEN key = 'supabase_project_ref' 
    THEN '✅ Configured: ' || value
    WHEN key = 'supabase_service_role_key' 
      AND (value IS NULL OR value = '' OR value = 'YOUR_SERVICE_ROLE_KEY_HERE') 
    THEN '❌ NOT CONFIGURED - Replace YOUR_SERVICE_ROLE_KEY_HERE above'
    WHEN key = 'supabase_service_role_key' 
      AND LENGTH(value) < 50 
    THEN '⚠️  TOO SHORT - Make sure you copied the entire key'
    WHEN key = 'supabase_service_role_key' 
    THEN '✅ Configured'
    ELSE 'Unknown'
  END as status,
  updated_at
FROM system_settings 
WHERE key IN ('supabase_project_ref', 'supabase_service_role_key')
ORDER BY key;

-- Step 5: Verify pg_net extension
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
    THEN '✅ pg_net extension is enabled'
    ELSE '❌ pg_net extension is NOT enabled'
  END as pg_net_status;

-- Step 6: Test configuration using helper functions
DO $$
DECLARE
  v_extension_exists BOOLEAN;
  v_project_ref TEXT;
  v_service_key TEXT;
  v_url TEXT;
BEGIN
  -- Check if pg_net exists
  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') INTO v_extension_exists;
  
  IF NOT v_extension_exists THEN
    RAISE NOTICE '❌ pg_net extension not found. Run: CREATE EXTENSION IF NOT EXISTS pg_net;';
  ELSE
    -- Try to get settings using helper functions
    BEGIN
      v_project_ref := get_supabase_project_ref();
      v_service_key := get_service_role_key();
      
      IF v_project_ref IS NULL OR v_project_ref = '' OR v_project_ref = 'YOUR_PROJECT_REF' THEN
        RAISE NOTICE '❌ Supabase project ref not configured in system_settings';
      ELSIF v_service_key IS NULL OR v_service_key = '' OR v_service_key = 'YOUR_SERVICE_ROLE_KEY' THEN
        RAISE NOTICE '❌ Service Role Key not configured in system_settings';
      ELSE
        v_url := format('https://%s.supabase.co', v_project_ref);
        RAISE NOTICE '✅ Configuration looks good!';
        RAISE NOTICE '   Project Ref: %', v_project_ref;
        RAISE NOTICE '   URL: %', v_url;
        RAISE NOTICE '   Service Key: ***CONFIGURED***';
        RAISE NOTICE '';
        RAISE NOTICE '📝 To test, send a support message from a non-admin user';
        RAISE NOTICE '   and check the logs for "Support request notification sent"';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '⚠️  Error checking settings: %', SQLERRM;
      RAISE NOTICE '   Make sure helper functions get_supabase_project_ref() and get_service_role_key() exist';
    END;
  END IF;
END $$;
