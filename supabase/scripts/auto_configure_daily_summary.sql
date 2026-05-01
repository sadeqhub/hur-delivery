-- =====================================================================================
-- AUTO-CONFIGURE DAILY SUMMARY EMAIL
-- =====================================================================================
-- This script attempts to auto-detect the project reference and helps you
-- configure the service role key easily
-- =====================================================================================

-- Step 1: Try to auto-detect project reference from various sources
DO $$
DECLARE
  v_project_ref TEXT;
  v_detected_source TEXT;
BEGIN
  -- Try method 1: Extract from current_setting if available
  BEGIN
    v_project_ref := current_setting('app.settings.project_ref', true);
    IF v_project_ref IS NOT NULL AND v_project_ref != '' THEN
      v_detected_source := 'app.settings.project_ref';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
  
  -- Try method 2: Extract from database name (Supabase pattern)
  IF v_project_ref IS NULL OR v_project_ref = '' THEN
    SELECT current_database() INTO v_project_ref;
    -- Supabase databases often follow pattern: postgres.[project_ref]
    IF v_project_ref LIKE 'postgres.%' THEN
      v_project_ref := REPLACE(v_project_ref, 'postgres.', '');
      v_detected_source := 'database name';
    ELSIF v_project_ref NOT LIKE 'postgres%' AND LENGTH(v_project_ref) BETWEEN 10 AND 25 THEN
      -- Might be the project ref directly
      v_detected_source := 'database name (possible)';
    ELSE
      v_project_ref := NULL;
    END IF;
  END IF;
  
  -- Try method 3: Check if already set in system_settings
  IF v_project_ref IS NULL OR v_project_ref = '' OR v_project_ref = 'YOUR_PROJECT_REF' THEN
    SELECT value INTO v_project_ref
    FROM system_settings
    WHERE key = 'supabase_project_ref'
      AND value IS NOT NULL 
      AND value != ''
      AND value != 'YOUR_PROJECT_REF'
      AND value != 'YOUR_PROJECT_REF_HERE';
    
    IF v_project_ref IS NOT NULL THEN
      v_detected_source := 'system_settings (existing)';
    END IF;
  END IF;
  
  -- Display what we found
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AUTO-DETECTION RESULTS';
  RAISE NOTICE '========================================';
  
  IF v_project_ref IS NOT NULL AND v_project_ref != '' 
     AND v_project_ref != 'YOUR_PROJECT_REF' 
     AND v_project_ref != 'YOUR_PROJECT_REF_HERE' THEN
    RAISE NOTICE '✅ Detected project reference: %', v_project_ref;
    RAISE NOTICE '   Source: %', v_detected_source;
    
    -- Update system_settings with detected value
    INSERT INTO system_settings (key, value, value_type, description)
    VALUES ('supabase_project_ref', v_project_ref, 'string', 'Supabase project reference')
    ON CONFLICT (key) DO UPDATE 
    SET value = EXCLUDED.value, updated_at = NOW();
    
    RAISE NOTICE '✅ Saved to system_settings';
  ELSE
    RAISE WARNING '❌ Could not auto-detect project reference';
    RAISE WARNING '';
    RAISE WARNING 'Please set it manually:';
    RAISE WARNING '  UPDATE system_settings';
    RAISE WARNING '  SET value = ''YOUR_PROJECT_REF'', updated_at = NOW()';
    RAISE WARNING '  WHERE key = ''supabase_project_ref'';';
    RAISE WARNING '';
    RAISE WARNING 'To find your project reference:';
    RAISE WARNING '  1. Go to Supabase Dashboard';
    RAISE WARNING '  2. Look at your project URL: https://[PROJECT_REF].supabase.co';
    RAISE WARNING '  3. The PROJECT_REF is the part before .supabase.co';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

-- Step 2: Check service role key status
DO $$
DECLARE
  v_service_key TEXT;
  v_key_length INTEGER;
BEGIN
  SELECT value, LENGTH(value) INTO v_service_key, v_key_length
  FROM system_settings
  WHERE key = 'supabase_service_role_key'
  LIMIT 1;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'SERVICE ROLE KEY STATUS';
  RAISE NOTICE '========================================';
  
  IF v_service_key IS NULL OR v_service_key = '' 
     OR v_service_key = 'YOUR_SERVICE_ROLE_KEY' 
     OR v_service_key = 'YOUR_SERVICE_ROLE_KEY_HERE'
     OR v_service_key = 'YOUR_ACTUAL_SERVICE_ROLE_KEY' THEN
    RAISE WARNING '❌ Service role key is NOT configured';
    RAISE WARNING '';
    RAISE WARNING 'To configure it:';
    RAISE WARNING '  1. Go to Supabase Dashboard > Settings > API';
    RAISE WARNING '  2. Find "Service Role Key" (marked as "secret")';
    RAISE WARNING '  3. Click "Reveal" and copy the entire key';
    RAISE WARNING '  4. Run this command (replace YOUR_KEY):';
    RAISE WARNING '';
    RAISE WARNING '  UPDATE system_settings';
    RAISE WARNING '  SET value = ''YOUR_KEY_HERE'', updated_at = NOW()';
    RAISE WARNING '  WHERE key = ''supabase_service_role_key'';';
  ELSIF v_key_length < 50 THEN
    RAISE WARNING '⚠️  Service role key seems too short (% characters)', v_key_length;
    RAISE WARNING '   Service role keys are usually 200+ characters long';
    RAISE WARNING '   Please verify you copied the entire key';
  ELSE
    RAISE NOTICE '✅ Service role key is configured';
    RAISE NOTICE '   Length: % characters', v_key_length;
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

-- Step 3: Final verification
SELECT 
  'Final Configuration Status' as check_type,
  key,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN 
      CASE 
        WHEN value IS NULL OR value = '' OR value LIKE 'YOUR_%' THEN '❌ NOT CONFIGURED'
        WHEN LENGTH(value) < 50 THEN '⚠️  TOO SHORT'
        ELSE '✅ CONFIGURED'
      END
    WHEN key = 'supabase_project_ref' THEN
      CASE 
        WHEN value IS NULL OR value = '' OR value LIKE 'YOUR_%' THEN '❌ NOT CONFIGURED'
        WHEN value LIKE '%.supabase.co' OR value LIKE 'https://%' THEN '⚠️  WRONG FORMAT'
        ELSE '✅ CONFIGURED: ' || value
      END
  END as status
FROM system_settings
WHERE key IN ('supabase_project_ref', 'supabase_service_role_key')
ORDER BY key;

-- Step 4: Test the configuration
DO $$
DECLARE
  v_project_ref TEXT;
  v_service_key TEXT;
  v_all_ok BOOLEAN := true;
BEGIN
  v_project_ref := get_supabase_project_ref();
  v_service_key := get_service_role_key();
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CONFIGURATION TEST';
  RAISE NOTICE '========================================';
  
  IF v_project_ref IS NULL OR v_project_ref = '' 
     OR v_project_ref LIKE 'YOUR_%' THEN
    RAISE WARNING '❌ Project reference: NOT CONFIGURED';
    v_all_ok := false;
  ELSE
    RAISE NOTICE '✅ Project reference: %', v_project_ref;
  END IF;
  
  IF v_service_key IS NULL OR v_service_key = '' 
     OR v_service_key LIKE 'YOUR_%' THEN
    RAISE WARNING '❌ Service role key: NOT CONFIGURED';
    v_all_ok := false;
  ELSE
    RAISE NOTICE '✅ Service role key: CONFIGURED (hidden)';
  END IF;
  
  RAISE NOTICE '';
  IF v_all_ok THEN
    RAISE NOTICE '✅ All configuration complete!';
    RAISE NOTICE '';
    RAISE NOTICE 'You can test the function with:';
    RAISE NOTICE '  SELECT call_daily_summary_email();';
    RAISE NOTICE '';
    RAISE NOTICE 'The cron job will run automatically at 9PM GMT+3 (18:00 UTC)';
  ELSE
    RAISE WARNING '⚠️  Configuration incomplete. Please complete the steps above.';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

















