-- =====================================================================================
-- SIMPLE CONFIGURATION - Copy and paste this, replace values, then run
-- =====================================================================================

-- ⚠️ REPLACE 'YOUR_PROJECT_REF' with your actual project reference
-- Find it in your Supabase Dashboard URL: https://[PROJECT_REF].supabase.co
-- Example: If URL is https://abc123xyz.supabase.co, use: abc123xyz
UPDATE system_settings
SET value = 'YOUR_PROJECT_REF', updated_at = NOW()
WHERE key = 'supabase_project_ref';

-- ⚠️ REPLACE 'YOUR_SERVICE_ROLE_KEY' with your actual service role key
-- Get it from: Supabase Dashboard > Settings > API > Service Role Key > Reveal
-- It's a long JWT token starting with eyJ...
UPDATE system_settings
SET value = 'YOUR_SERVICE_ROLE_KEY', updated_at = NOW()
WHERE key = 'supabase_service_role_key';

-- Check if it worked
SELECT 
  key,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN '***HIDDEN***'
    ELSE value
  END as value,
  CASE 
    WHEN key = 'supabase_service_role_key' AND (value IS NULL OR value = '' OR value LIKE 'YOUR_%') THEN '❌ NOT SET - Replace YOUR_SERVICE_ROLE_KEY above'
    WHEN key = 'supabase_service_role_key' AND LENGTH(value) < 50 THEN '⚠️  TOO SHORT - Make sure you copied the entire key'
    WHEN key = 'supabase_service_role_key' THEN '✅ OK'
    WHEN key = 'supabase_project_ref' AND (value IS NULL OR value = '' OR value LIKE 'YOUR_%') THEN '❌ NOT SET - Replace YOUR_PROJECT_REF above'
    WHEN key = 'supabase_project_ref' AND value LIKE '%.supabase.co' THEN '⚠️  WRONG - Remove .supabase.co, use just the project ref'
    WHEN key = 'supabase_project_ref' AND value LIKE 'https://%' THEN '⚠️  WRONG - Remove https://, use just the project ref'
    WHEN key = 'supabase_project_ref' THEN '✅ OK: ' || value
  END as status
FROM system_settings
WHERE key IN ('supabase_project_ref', 'supabase_service_role_key')
ORDER BY key;

















