-- =====================================================================================
-- FIX FUNCTION SEARCH_PATH - DIRECT APPROACH
-- =====================================================================================
-- This migration fixes function search_path issues by directly recreating functions
-- with SET search_path = public, pg_temp added to their definitions.
-- 
-- This is a follow-up to 20250121000000_fix_all_security_linter_warnings.sql
-- to handle cases where the regex approach may not have worked.
-- =====================================================================================

BEGIN;

-- =====================================================================================
-- HELPER FUNCTION: Safely add search_path to function definition
-- =====================================================================================
CREATE OR REPLACE FUNCTION _temp_add_search_path(func_def TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  result TEXT;
  as_pattern_pos INT;
  actual_as_text TEXT;
  search_path_line TEXT := 'SET search_path = public, extensions, pg_temp';
BEGIN
  -- If already has search_path, return as-is
  IF func_def ILIKE '%set search_path%' THEN
    RETURN func_def;
  END IF;
  
  -- Find "AS $$" pattern (case insensitive) and insert SET search_path before it
  -- PostgreSQL function definitions end with "AS $$" followed by the function body
  
  -- pg_get_functiondef returns function definitions with newlines
  -- Format is typically: ... RETURNS type [LANGUAGE ...] [SECURITY ...] AS $$
  -- We need to insert SET search_path before "AS $$"
  
  -- Use case-insensitive regex first (most reliable for variations)
  -- Match: any whitespace + "AS" + whitespace + "$$"
  result := regexp_replace(
    func_def,
    '(\s+)(AS\s+\$\$)',
    E'\n' || search_path_line || E'\\1\\2',
    'i'
  );
  
  -- If regex didn't match, try direct string replacement
  IF result = func_def THEN
    -- Try exact pattern "AS $$" (case sensitive, most common)
    IF position('AS $$' IN func_def) > 0 THEN
      result := replace(func_def, 'AS $$', search_path_line || E'\nAS $$');
    -- Try with newline before "AS $$" (common in pg_get_functiondef output)
    ELSIF position(E'\nAS $$' IN func_def) > 0 THEN
      result := replace(func_def, E'\nAS $$', E'\n' || search_path_line || E'\nAS $$');
    -- Try with space before "AS $$"
    ELSIF position(' AS $$' IN func_def) > 0 THEN
      result := replace(func_def, ' AS $$', E'\n' || search_path_line || E'\n AS $$');
    -- Try lowercase variations
    ELSIF position('as $$' IN func_def) > 0 THEN
      result := replace(func_def, 'as $$', search_path_line || E'\nas $$');
    ELSIF position(E'\nas $$' IN func_def) > 0 THEN
      result := replace(func_def, E'\nas $$', E'\n' || search_path_line || E'\nas $$');
    -- Try simpler regex without capturing whitespace
    ELSE
      result := regexp_replace(
        func_def,
        '(AS\s+\$\$)',
        search_path_line || E'\n\\1',
        'i'
      );
    END IF;
  END IF;
  
  RETURN result;
END;
$$;

-- =====================================================================================
-- FIX ALL FUNCTIONS THAT STILL NEED SEARCH_PATH
-- =====================================================================================
DO $$
DECLARE
  func_rec RECORD;
  original_def TEXT;
  modified_def TEXT;
  fixed_count INT := 0;
  failed_count INT := 0;
  failed_functions TEXT[] := ARRAY[]::TEXT[];
  search_path_line TEXT := 'SET search_path = public, extensions, pg_temp';
BEGIN
  RAISE NOTICE 'Starting direct function search_path fixes...';
  
  -- Get all functions that still don't have search_path
  FOR func_rec IN
    SELECT 
      p.oid,
      p.proname AS func_name,
      pg_get_function_identity_arguments(p.oid) AS func_args,
      pg_get_functiondef(p.oid) AS func_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND pg_get_functiondef(p.oid) NOT ILIKE '%set search_path%'
      AND p.proname NOT LIKE 'pg_%'
      AND p.proname NOT LIKE 'information_schema%'
      AND p.proname NOT LIKE '_%'
      AND p.proname NOT LIKE 'st_%'
      AND p.proname NOT LIKE 'postgis_%'
      AND p.proname NOT LIKE 'geography_%'
      AND p.proname NOT LIKE 'geometry_%'
      AND p.proname NOT LIKE '_temp_%'  -- Exclude our helper function
    ORDER BY p.proname
  LOOP
    BEGIN
      original_def := func_rec.func_def;
      
      -- Use helper function to modify
      modified_def := _temp_add_search_path(original_def);
      
      -- Verify modification happened
      IF modified_def != original_def AND modified_def ILIKE '%set search_path%' THEN
        -- Recreate the function with search_path
        EXECUTE modified_def;
        fixed_count := fixed_count + 1;
        
        IF fixed_count % 20 = 0 THEN
          RAISE NOTICE 'Fixed % functions (last: %)...', fixed_count, func_rec.func_name;
        END IF;
      ELSE
        -- Helper function didn't modify - try direct replacement with multiple patterns
        -- This handles edge cases where the helper function pattern matching failed
        
        -- Try multiple patterns directly
        IF position('AS $$' IN original_def) > 0 THEN
          modified_def := replace(original_def, 'AS $$', search_path_line || E'\nAS $$');
        ELSIF position(E'\nAS $$' IN original_def) > 0 THEN
          modified_def := replace(original_def, E'\nAS $$', E'\n' || search_path_line || E'\nAS $$');
        ELSIF position(' AS $$' IN original_def) > 0 THEN
          modified_def := replace(original_def, ' AS $$', E'\n' || search_path_line || E'\n AS $$');
        ELSIF position('as $$' IN original_def) > 0 THEN
          modified_def := replace(original_def, 'as $$', search_path_line || E'\nas $$');
        ELSIF position(E'\nas $$' IN original_def) > 0 THEN
          modified_def := replace(original_def, E'\nas $$', E'\n' || search_path_line || E'\nas $$');
        ELSE
          -- Try regex as last resort
          modified_def := regexp_replace(
            original_def,
            '(\s+)(AS\s+\$\$)',
            E'\n' || search_path_line || E'\\1\\2',
            'i'
          );
        END IF;
        
        -- Try to recreate with modified definition
        IF modified_def != original_def AND modified_def ILIKE '%set search_path%' THEN
          BEGIN
            EXECUTE modified_def;
            fixed_count := fixed_count + 1;
            RAISE NOTICE 'Fixed %(%) using fallback method', func_rec.func_name, func_rec.func_args;
          EXCEPTION
            WHEN OTHERS THEN
              failed_count := failed_count + 1;
              failed_functions := array_append(failed_functions, 
                func_rec.func_name || '(' || COALESCE(func_rec.func_args, '') || ')');
              RAISE NOTICE 'Error recreating %(%): %', func_rec.func_name, func_rec.func_args, SQLERRM;
          END;
        ELSE
          failed_count := failed_count + 1;
          failed_functions := array_append(failed_functions, 
            func_rec.func_name || '(' || COALESCE(func_rec.func_args, '') || ')');
          RAISE NOTICE 'Could not fix %(%) - pattern matching failed', func_rec.func_name, func_rec.func_args;
          -- Log first 100 characters of definition for debugging
          RAISE NOTICE 'Function definition preview: %...', substring(original_def, 1, 100);
        END IF;
      END IF;
      
    EXCEPTION
      WHEN OTHERS THEN
        failed_count := failed_count + 1;
        failed_functions := array_append(failed_functions, 
          func_rec.func_name || '(' || COALESCE(func_rec.func_args, '') || ')');
        RAISE NOTICE 'Error fixing %(%): %', func_rec.func_name, func_rec.func_args, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Function search_path fixes complete!';
  RAISE NOTICE 'Fixed: %', fixed_count;
  RAISE NOTICE 'Failed: %', failed_count;
  
  IF failed_count > 0 THEN
    RAISE WARNING 'Failed to fix % functions:', failed_count;
    RAISE NOTICE 'Functions that need manual fix:';
    FOR func_rec IN
      SELECT unnest(failed_functions) AS func_name
    LOOP
      RAISE NOTICE '  - %', func_rec.func_name;
    END LOOP;
  END IF;
END $$;

-- Clean up helper function
DROP FUNCTION IF EXISTS _temp_add_search_path(TEXT);

-- =====================================================================================
-- FIX EXTENSIONS: Move from public schema to extensions schema
-- =====================================================================================
-- This section handles extensions that may not have been moved in the previous migration

DO $$
BEGIN
  -- Try to move postgis extension
  IF EXISTS (
    SELECT 1 FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace
    WHERE e.extname = 'postgis' AND n.nspname = 'public'
  ) THEN
    BEGIN
      ALTER EXTENSION postgis SET SCHEMA extensions;
      RAISE NOTICE 'Moved postgis extension to extensions schema';
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not move postgis: %', SQLERRM;
    END;
  END IF;
  
  -- Try to move http extension
  IF EXISTS (
    SELECT 1 FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace
    WHERE e.extname = 'http' AND n.nspname = 'public'
  ) THEN
    BEGIN
      ALTER EXTENSION http SET SCHEMA extensions;
      RAISE NOTICE 'Moved http extension to extensions schema';
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not move http: %', SQLERRM;
    END;
  END IF;
  
  -- Try to move pg_net extension
  IF EXISTS (
    SELECT 1 FROM pg_extension e
    JOIN pg_namespace n ON n.oid = e.extnamespace
    WHERE e.extname = 'pg_net' AND n.nspname = 'public'
  ) THEN
    BEGIN
      ALTER EXTENSION pg_net SET SCHEMA extensions;
      RAISE NOTICE 'Moved pg_net extension to extensions schema';
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not move pg_net: %', SQLERRM;
    END;
  END IF;
END $$;

COMMIT;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- If some functions still fail after this migration, they may need to be manually
-- recreated. The failed function names will be logged.
-- 
-- To manually fix a function, use:
--   1. Get its definition: SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'function_name';
--   2. Add "SET search_path = public, extensions, pg_temp" before "AS $$"
--   3. Execute the modified definition
-- =====================================================================================
