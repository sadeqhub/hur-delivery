-- =====================================================================================
-- UPDATE DAILY SUMMARY EMAIL CONFIGURATION
-- =====================================================================================
-- 
-- INSTRUCTIONS:
-- 1. Find your Supabase Project Reference:
--    - Look at your Supabase project URL in the dashboard
--    - Example: If URL is https://abc123xyz.supabase.co
--    - Then your PROJECT_REF is: abc123xyz
--
-- 2. Find your Service Role Key:
--    - Go to: Supabase Dashboard > Settings > API
--    - Find "Service Role Key" (marked as "secret")
--    - Click "Reveal" and copy the entire key
--
-- 3. Replace the values in the UPDATE statements below
-- 4. Run this script
-- =====================================================================================

-- ⚠️ STEP 1: Replace 'YOUR_ACTUAL_PROJECT_REF' with your real project reference
-- Example: If your URL is https://abc123xyz.supabase.co, use 'abc123xyz'
UPDATE system_settings
SET 
  value = 'YOUR_ACTUAL_PROJECT_REF',  -- ⚠️ REPLACE THIS!
  updated_at = NOW()
WHERE key = 'supabase_project_ref';

-- ⚠️ STEP 2: Replace 'YOUR_ACTUAL_SERVICE_ROLE_KEY' with your real service role key
-- This is a long JWT token (starts with eyJ...)
UPDATE system_settings
SET 
  value = 'YOUR_ACTUAL_SERVICE_ROLE_KEY',  -- ⚠️ REPLACE THIS!
  updated_at = NOW()
WHERE key = 'supabase_service_role_key';

-- Verify the update
SELECT 
  key,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN 
      CASE 
        WHEN value = 'YOUR_ACTUAL_SERVICE_ROLE_KEY' OR value = 'YOUR_SERVICE_ROLE_KEY_HERE' 
             OR value = 'YOUR_SERVICE_ROLE_KEY' OR value IS NULL OR value = ''
        THEN '❌ STILL NOT CONFIGURED - Please replace the placeholder in the UPDATE statement above'
        WHEN LENGTH(value) < 50 THEN '⚠️  VALUE TOO SHORT - Service role keys are usually 200+ characters'
        ELSE '✅ CONFIGURED (length: ' || LENGTH(value) || ' chars)'
      END
    WHEN key = 'supabase_project_ref' THEN
      CASE 
        WHEN value = 'YOUR_ACTUAL_PROJECT_REF' OR value = 'YOUR_PROJECT_REF_HERE' 
             OR value = 'YOUR_PROJECT_REF' OR value IS NULL OR value = ''
        THEN '❌ STILL NOT CONFIGURED - Please replace the placeholder in the UPDATE statement above'
        WHEN value LIKE '%.supabase.co' OR value LIKE 'https://%' THEN 
          '⚠️  WRONG FORMAT - Should be just the project ref (e.g., "abc123xyz"), not the full URL'
        ELSE '✅ CONFIGURED: ' || value
      END
  END as status,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN '***HIDDEN***'
    ELSE value
  END as value_preview
FROM system_settings
WHERE key IN ('supabase_project_ref', 'supabase_service_role_key')
ORDER BY key;

-- Test if configuration works
DO $$
DECLARE
  v_project_ref TEXT;
  v_service_key TEXT;
  v_all_configured BOOLEAN := true;
BEGIN
  v_project_ref := get_supabase_project_ref();
  v_service_key := get_service_role_key();
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CONFIGURATION TEST';
  RAISE NOTICE '========================================';
  
  IF v_project_ref IS NULL OR v_project_ref = '' 
     OR v_project_ref = 'YOUR_PROJECT_REF' 
     OR v_project_ref = 'YOUR_PROJECT_REF_HERE'
     OR v_project_ref = 'YOUR_ACTUAL_PROJECT_REF' THEN
    RAISE WARNING '❌ supabase_project_ref: NOT CONFIGURED';
    RAISE WARNING '   Current value appears to be a placeholder';
    v_all_configured := false;
  ELSE
    RAISE NOTICE '✅ supabase_project_ref: %', v_project_ref;
  END IF;
  
  IF v_service_key IS NULL OR v_service_key = '' 
     OR v_service_key = 'YOUR_SERVICE_ROLE_KEY' 
     OR v_service_key = 'YOUR_SERVICE_ROLE_KEY_HERE'
     OR v_service_key = 'YOUR_ACTUAL_SERVICE_ROLE_KEY' THEN
    RAISE WARNING '❌ supabase_service_role_key: NOT CONFIGURED';
    RAISE WARNING '   Current value appears to be a placeholder';
    v_all_configured := false;
  ELSE
    RAISE NOTICE '✅ supabase_service_role_key: CONFIGURED (hidden)';
  END IF;
  
  RAISE NOTICE '';
  IF v_all_configured THEN
    RAISE NOTICE '✅ All configuration looks good!';
    RAISE NOTICE '';
    RAISE NOTICE 'You can now test the function:';
    RAISE NOTICE '  SELECT call_daily_summary_email();';
  ELSE
    RAISE WARNING '⚠️  Configuration incomplete. Please update the values above.';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

















