-- =====================================================================================
-- CONFIGURE DAILY SUMMARY EMAIL WITH YOUR VALUES
-- =====================================================================================
-- This script configures the daily summary email with your actual Supabase credentials
-- =====================================================================================

-- Set Project Reference (extracted from: https://bvtoxmmiitznagsbubhg.supabase.co)
UPDATE system_settings
SET value = 'bvtoxmmiitznagsbubhg', updated_at = NOW()
WHERE key = 'supabase_project_ref';

-- Set Service Role Key
UPDATE system_settings
SET value = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjA3OTkxNywiZXhwIjoyMDY3NjU1OTE3fQ.wKOQiltkUnYiZY1LRRkJcZ_8lL7WZZgmpDdHVoDRqqE', updated_at = NOW()
WHERE key = 'supabase_service_role_key';

-- Verify the configuration
SELECT 
  key,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN '***HIDDEN***'
    ELSE value
  END as value,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN '✅ CONFIGURED'
    WHEN key = 'supabase_project_ref' THEN '✅ CONFIGURED: ' || value
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
  
  IF v_project_ref IS NOT NULL AND v_project_ref != '' 
     AND v_project_ref != 'YOUR_PROJECT_REF' 
     AND v_project_ref != 'YOUR_PROJECT_REF_HERE' THEN
    RAISE NOTICE '✅ Project reference: %', v_project_ref;
  ELSE
    RAISE WARNING '❌ Project reference: NOT CONFIGURED';
  END IF;
  
  IF v_service_key IS NOT NULL AND v_service_key != '' 
     AND v_service_key != 'YOUR_SERVICE_ROLE_KEY' 
     AND v_service_key != 'YOUR_SERVICE_ROLE_KEY_HERE' THEN
    RAISE NOTICE '✅ Service role key: CONFIGURED (length: % chars)', LENGTH(v_service_key);
  ELSE
    RAISE WARNING '❌ Service role key: NOT CONFIGURED';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ Configuration complete!';
  RAISE NOTICE '';
  RAISE NOTICE 'You can now test the function:';
  RAISE NOTICE '  SELECT call_daily_summary_email();';
  RAISE NOTICE '';
  RAISE NOTICE 'The cron job will run automatically at 9PM GMT+3 (18:00 UTC)';
  RAISE NOTICE '========================================';
END $$;

















