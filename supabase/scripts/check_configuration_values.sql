-- =====================================================================================
-- CHECK CONFIGURATION VALUES (Safe - doesn't reveal sensitive data)
-- =====================================================================================
-- This script checks if the configuration values are set correctly
-- without revealing the actual service role key
-- =====================================================================================

SELECT 
  key,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN 
      CASE 
        WHEN value IS NULL OR value = '' THEN '❌ NOT SET (empty)'
        WHEN value = 'YOUR_SERVICE_ROLE_KEY_HERE' OR value = 'YOUR_SERVICE_ROLE_KEY' THEN '❌ PLACEHOLDER VALUE (not configured)'
        WHEN LENGTH(value) < 50 THEN '⚠️  VALUE TOO SHORT (service role keys are usually 200+ characters)'
        ELSE '✅ CONFIGURED (length: ' || LENGTH(value) || ' characters)'
      END
    WHEN key = 'supabase_project_ref' THEN
      CASE 
        WHEN value IS NULL OR value = '' THEN '❌ NOT SET (empty)'
        WHEN value = 'YOUR_PROJECT_REF_HERE' OR value = 'YOUR_PROJECT_REF' THEN '❌ PLACEHOLDER VALUE (not configured)'
        WHEN value LIKE '%.supabase.co' THEN '⚠️  INCLUDES FULL URL (should only be the project ref, not the full URL)'
        WHEN LENGTH(value) < 10 THEN '⚠️  VALUE TOO SHORT (project refs are usually 10-20 characters)'
        ELSE '✅ CONFIGURED: ' || value
      END
    ELSE 'Unknown key'
  END as status,
  CASE 
    WHEN key = 'supabase_service_role_key' THEN '***HIDDEN***'
    ELSE value
  END as value_preview,
  LENGTH(value) as value_length,
  updated_at
FROM system_settings
WHERE key IN ('supabase_project_ref', 'supabase_service_role_key')
ORDER BY key;

-- Test the helper functions
SELECT 
  'Function Test' as check_type,
  CASE 
    WHEN get_supabase_project_ref() IS NULL OR get_supabase_project_ref() = '' 
         OR get_supabase_project_ref() = 'YOUR_PROJECT_REF' 
         OR get_supabase_project_ref() = 'YOUR_PROJECT_REF_HERE'
    THEN '❌ NOT CONFIGURED'
    ELSE '✅ CONFIGURED: ' || LEFT(get_supabase_project_ref(), 20) || '...'
  END as project_ref_status,
  CASE 
    WHEN get_service_role_key() IS NULL OR get_service_role_key() = '' 
         OR get_service_role_key() = 'YOUR_SERVICE_ROLE_KEY' 
         OR get_service_role_key() = 'YOUR_SERVICE_ROLE_KEY_HERE'
    THEN '❌ NOT CONFIGURED'
    ELSE '✅ CONFIGURED (hidden)'
  END as service_key_status;

















