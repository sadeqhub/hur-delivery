-- =====================================================================================
-- CLEANUP DUPLICATE RANK FUNCTIONS
-- =====================================================================================
-- This migration drops the old, deprecated functions related to driver ranking
-- to prevent confusion and potential logic conflicts.
--
-- Functions being dropped:
-- 1. update_driver_rank(uuid) - The old v1 logic
-- 2. reset_driver_ranks_monthly() - The old v1 monthly reset logic
--
-- The system now relies on:
-- 1. update_driver_ranks_v2() - The new consolidated logic
-- 2. run_monthly_driver_rank_adjustments() - The wrapper calling v2
-- =====================================================================================

DROP FUNCTION IF EXISTS update_driver_rank(uuid);
DROP FUNCTION IF EXISTS reset_driver_ranks_monthly();
