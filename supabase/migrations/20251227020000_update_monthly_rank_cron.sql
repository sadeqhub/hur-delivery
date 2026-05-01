-- =====================================================================================
-- UPDATE MONTHLY RANK CRON SYSTEM
-- =====================================================================================
-- This migration updates the existing `run_monthly_driver_rank_adjustments` function
-- to use the new `update_driver_ranks_v2()` logic instead of the deprecated v1 logic.
-- =====================================================================================

CREATE OR REPLACE FUNCTION run_monthly_driver_rank_adjustments()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Call the new V2 rank update logic
  -- This handles both:
  -- 1. Trial status enforcement (for < 1 month old accounts)
  -- 2. Performance-based ranking (Gold/Silver/Bronze) based on LAST MONTH's stats
  
  v_result := update_driver_ranks_v2();

  RETURN jsonb_build_object(
    'success', true,
    'result', v_result,
    'message', 'Monthly driver rank adjustment completed using v2 logic'
  );
END;
$$;

-- Ensure permissions are correct
GRANT EXECUTE ON FUNCTION run_monthly_driver_rank_adjustments() TO authenticated, anon;

-- Note: The cron job causing this to run is already scheduled in
-- 20251226000001_driver_wallet_enforcement_and_wayl_topups.sql
-- It calls this function by name, so replacing the function body is sufficient.
