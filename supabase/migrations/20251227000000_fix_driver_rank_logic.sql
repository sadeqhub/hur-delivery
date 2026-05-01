-- =====================================================================================
-- FIX DRIVER RANK LOGIC v2
-- =====================================================================================
-- Logic:
-- 1. If driver age < 1 month -> TRIAL
-- 2. If driver age >= 1 month -> Rank based on LAST MONTH'S performance
--    - Gold: >= 300 hours
--    - Silver: >= 250 hours
--    - Bronze: < 250 hours
-- =====================================================================================

CREATE OR REPLACE FUNCTION update_driver_ranks_v2()
RETURNS jsonb AS $$
DECLARE
  v_driver RECORD;
  v_new_rank TEXT;
  v_months_active INTEGER;
  v_last_month_date DATE;
  v_last_month_hours DECIMAL;
  v_updated_count INTEGER := 0;
  v_trial_count INTEGER := 0;
  v_gold_count INTEGER := 0;
  v_silver_count INTEGER := 0;
  v_bronze_count INTEGER := 0;
BEGIN
  -- Determine last month's date (e.g., if now is Feb, this is Jan 1st)
  v_last_month_date := DATE_TRUNC('month', NOW() - INTERVAL '1 month')::DATE;

  FOR v_driver IN SELECT id, created_at, rank FROM users WHERE role = 'driver' LOOP
    
    -- Calculate months active (approximate using 30 days)
    v_months_active := EXTRACT(EPOCH FROM (NOW() - v_driver.created_at)) / (30 * 24 * 3600);
    
    IF v_months_active < 1 THEN
      -- Less than 1 month old -> TRIAL
      v_new_rank := 'trial';
      v_trial_count := v_trial_count + 1;
    ELSE
      -- More than 1 month old -> Check LAST MONTH's stats
      -- We must check stats for the full previous month 
      -- (or current accumulated stats if this is run mid-month? Requirement says "last month's achievements")
      
      -- If this function is run on the 1st of the month, "last month" is the full previous month.
      v_last_month_hours := get_driver_monthly_online_hours(v_driver.id, v_last_month_date);
      
      IF v_last_month_hours >= 300 THEN
        v_new_rank := 'gold';
        v_gold_count := v_gold_count + 1;
      ELSIF v_last_month_hours >= 250 THEN
        v_new_rank := 'silver';
        v_silver_count := v_silver_count + 1;
      ELSE
        v_new_rank := 'bronze';
        v_bronze_count := v_bronze_count + 1;
      END IF;
    END IF;

    -- Update if changed
    IF v_new_rank IS DISTINCT FROM v_driver.rank THEN
      UPDATE users 
      SET rank = v_new_rank,
          updated_at = NOW()
      WHERE id = v_driver.id;
      v_updated_count := v_updated_count + 1;
    END IF;
    
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'drivers_processed', v_trial_count + v_gold_count + v_silver_count + v_bronze_count,
    'ranks_updated', v_updated_count,
    'stats', jsonb_build_object(
      'trial', v_trial_count,
      'gold', v_gold_count,
      'silver', v_silver_count,
      'bronze', v_bronze_count
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- FIX DEFAULT RANK & EXISTING DATA
-- =====================================================================================

-- 1. Enforce 'trial' as the default rank for all new users (especially drivers)
ALTER TABLE users ALTER COLUMN rank SET DEFAULT 'trial';

-- 2. One-time data fix: Convert 'bronze' drivers to 'trial' if they are less than 1 month old
-- This fixes the issue where new accounts were incorrectly getting 'bronze'
UPDATE users
SET rank = 'trial',
    updated_at = NOW()
WHERE role = 'driver'
  AND rank = 'bronze'
  AND created_at > (NOW() - INTERVAL '1 month');

-- 3. Run the rank update function once to ensure consistency for all other drivers
SELECT update_driver_ranks_v2();
