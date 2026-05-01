-- =====================================================================================
-- CONFIGURE DAILY SUMMARY EMAIL SYSTEM SETTINGS
-- =====================================================================================
-- This script configures the required system settings for the daily summary email
-- 
-- INSTRUCTIONS:
-- 1. Find your Supabase Project Reference:
--    - Go to your Supabase Dashboard
--    - Look at your project URL: https://[PROJECT_REF].supabase.co
--    - The PROJECT_REF is the part between "https://" and ".supabase.co"
--    - Example: If URL is https://abc123xyz.supabase.co, then PROJECT_REF is "abc123xyz"
--
-- 2. Find your Service Role Key:
--    - Go to Supabase Dashboard > Settings > API
--    - Find "Service Role Key" (it's marked as "secret" - this is important!)
--    - Click "Reveal" to show the key
--    - Copy the entire key (it's a long JWT token)
--
-- 3. Replace the placeholders below with your actual values
-- 4. Run this script in Supabase SQL Editor
-- =====================================================================================

-- ⚠️ REPLACE THESE VALUES WITH YOUR ACTUAL VALUES ⚠️
-- Replace 'YOUR_PROJECT_REF_HERE' with your actual Supabase project reference
-- Replace 'YOUR_SERVICE_ROLE_KEY_HERE' with your actual service role key

-- Configure Supabase Project Reference
INSERT INTO system_settings (key, value, value_type, description)
VALUES (
  'supabase_project_ref',
  'YOUR_PROJECT_REF_HERE',  -- ⚠️ REPLACE THIS with your actual project ref
  'string',
  'Supabase project reference for Edge Function URLs'
)
ON CONFLICT (key) DO UPDATE 
SET 
  value = EXCLUDED.value,
  updated_at = NOW();

-- Configure Service Role Key
INSERT INTO system_settings (key, value, value_type, description, is_public)
VALUES (
  'supabase_service_role_key',
  'YOUR_SERVICE_ROLE_KEY_HERE',  -- ⚠️ REPLACE THIS with your actual service role key
  'string',
  'Supabase service role key for Edge Function authentication',
  false  -- Keep this as false - service role key should never be public
)
ON CONFLICT (key) DO UPDATE 
SET 
  value = EXCLUDED.value,
  updated_at = NOW();

-- Verify the configuration
SELECT 
  'Configuration Status' as check_type,
  key,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN '***HIDDEN***'
    WHEN value = 'YOUR_PROJECT_REF_HERE' OR value = 'YOUR_SERVICE_ROLE_KEY_HERE' 
         OR value IS NULL OR value = ''
    THEN '❌ NOT CONFIGURED - Please update the values above'
    ELSE '✅ CONFIGURED: ' || LEFT(value, 20) || '...'
  END as status,
  updated_at
FROM system_settings
WHERE key IN ('supabase_project_ref', 'supabase_service_role_key')
ORDER BY key;

-- Test the configuration
DO $$
DECLARE
  v_project_ref TEXT;
  v_service_key TEXT;
BEGIN
  v_project_ref := get_supabase_project_ref();
  v_service_key := get_service_role_key();
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CONFIGURATION TEST';
  RAISE NOTICE '========================================';
  
  IF v_project_ref IS NULL OR v_project_ref = '' OR v_project_ref = 'YOUR_PROJECT_REF' THEN
    RAISE WARNING '❌ supabase_project_ref is NOT configured correctly';
  ELSE
    RAISE NOTICE '✅ supabase_project_ref: %', LEFT(v_project_ref, 20) || '...';
  END IF;
  
  IF v_service_key IS NULL OR v_service_key = '' OR v_service_key = 'YOUR_SERVICE_ROLE_KEY' THEN
    RAISE WARNING '❌ supabase_service_role_key is NOT configured correctly';
  ELSE
    RAISE NOTICE '✅ supabase_service_role_key: CONFIGURED (hidden for security)';
  END IF;
  
  IF (v_project_ref IS NOT NULL AND v_project_ref != '' AND v_project_ref != 'YOUR_PROJECT_REF')
     AND (v_service_key IS NOT NULL AND v_service_key != '' AND v_service_key != 'YOUR_SERVICE_ROLE_KEY') THEN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Configuration looks good!';
    RAISE NOTICE '   You can now test the function with:';
    RAISE NOTICE '   SELECT call_daily_summary_email();';
  ELSE
    RAISE WARNING '';
    RAISE WARNING '⚠️  Please update the placeholder values above and run this script again';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

















