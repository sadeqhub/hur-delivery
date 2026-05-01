-- =====================================================================================
-- FIX COMMISSION RATES VISIBILITY
-- =====================================================================================
-- This migration updates the commission percentage settings in system_settings
-- to be PUBLIC (is_public = TRUE).
--
-- Issue: The RLS policy "system_settings_view_public" only allows users (including drivers)
-- to view settings where is_public = TRUE. Previously, these were FALSE.
-- =====================================================================================

UPDATE system_settings
SET is_public = TRUE,
    updated_at = NOW()
WHERE key IN (
  'trial_commission_percentage',
  'bronze_commission_percentage',
  'silver_commission_percentage',
  'gold_commission_percentage'
);
