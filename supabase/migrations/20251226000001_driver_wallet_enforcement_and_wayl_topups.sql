-- =====================================================================================
-- DRIVER WALLET ENFORCEMENT + WAYL TOPUPS + MONTHLY RANK AUTOMATION
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1) Extend driver wallet transactions to support top-ups via Wayl
-- -------------------------------------------------------------------------------------
DO $$
BEGIN
  -- Update transaction type check to include top_up
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'driver_wallet_transactions_transaction_type_check'
  ) THEN
    ALTER TABLE driver_wallet_transactions
      DROP CONSTRAINT driver_wallet_transactions_transaction_type_check;
  END IF;

  ALTER TABLE driver_wallet_transactions
    ADD CONSTRAINT driver_wallet_transactions_transaction_type_check
    CHECK (transaction_type IN ('top_up', 'earning', 'withdrawal', 'adjustment', 'commission_deduction'));
END $$;

DO $$
BEGIN
  -- Update payment_method check to include wayl
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'driver_wallet_transactions_payment_method_check'
  ) THEN
    ALTER TABLE driver_wallet_transactions
      DROP CONSTRAINT driver_wallet_transactions_payment_method_check;
  END IF;

  ALTER TABLE driver_wallet_transactions
    ADD CONSTRAINT driver_wallet_transactions_payment_method_check
    CHECK (payment_method IN ('zain_cash', 'qi_card', 'hur_representative', 'admin_adjustment', 'bank_transfer', 'wayl'));
END $$;

-- Function to add balance to driver wallet (top-up)
CREATE OR REPLACE FUNCTION add_driver_wallet_balance(
  p_driver_id UUID,
  p_amount DECIMAL,
  p_payment_method TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_enabled TEXT;
  v_current_balance DECIMAL(10,2);
  v_new_balance DECIMAL(10,2);
  v_transaction_id UUID;
BEGIN
  -- Check if driver wallet is enabled
  SELECT value INTO v_wallet_enabled
  FROM system_settings
  WHERE key = 'driver_wallet';

  IF v_wallet_enabled IS DISTINCT FROM 'enabled' THEN
    RETURN jsonb_build_object(
      'success', true,
      'wallet_disabled', true,
      'message', 'Driver wallet is disabled'
    );
  END IF;

  -- Ensure wallet exists
  SELECT balance INTO v_current_balance
  FROM driver_wallets
  WHERE driver_id = p_driver_id;

  IF v_current_balance IS NULL THEN
    INSERT INTO driver_wallets (driver_id, balance)
    VALUES (p_driver_id, 0.00)
    ON CONFLICT (driver_id) DO NOTHING;

    SELECT balance INTO v_current_balance
    FROM driver_wallets
    WHERE driver_id = p_driver_id;

    v_current_balance := COALESCE(v_current_balance, 0.00);
  END IF;

  v_new_balance := v_current_balance + p_amount;

  UPDATE driver_wallets
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE driver_id = p_driver_id;

  INSERT INTO driver_wallet_transactions (
    driver_id,
    transaction_type,
    amount,
    balance_before,
    balance_after,
    payment_method,
    notes
  ) VALUES (
    p_driver_id,
    'top_up',
    p_amount,
    v_current_balance,
    v_new_balance,
    p_payment_method,
    COALESCE(p_notes, 'شحن المحفظة')
  ) RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'balance_before', v_current_balance,
    'balance_after', v_new_balance,
    'amount', p_amount
  );
END;
$$;

GRANT EXECUTE ON FUNCTION add_driver_wallet_balance(UUID, DECIMAL, TEXT, TEXT) TO authenticated, anon;

-- -------------------------------------------------------------------------------------
-- 2) Extend pending_topups to support driver topups using the same Wayl flow
-- -------------------------------------------------------------------------------------

ALTER TABLE pending_topups
  ALTER COLUMN merchant_id DROP NOT NULL;

ALTER TABLE pending_topups
  ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE pending_topups
  ADD COLUMN IF NOT EXISTS wallet_type TEXT NOT NULL DEFAULT 'merchant'
  CHECK (wallet_type IN ('merchant', 'driver'));

DO $$
BEGIN
  -- Ensure exactly one owner is set depending on wallet_type
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'pending_topups_wallet_owner_check'
  ) THEN
    ALTER TABLE pending_topups DROP CONSTRAINT pending_topups_wallet_owner_check;
  END IF;

  ALTER TABLE pending_topups
    ADD CONSTRAINT pending_topups_wallet_owner_check
    CHECK (
      (wallet_type = 'merchant' AND merchant_id IS NOT NULL AND driver_id IS NULL)
      OR
      (wallet_type = 'driver' AND driver_id IS NOT NULL AND merchant_id IS NULL)
    );
END $$;

CREATE INDEX IF NOT EXISTS idx_pending_topups_driver ON pending_topups(driver_id) WHERE driver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pending_topups_wallet_type ON pending_topups(wallet_type);

DROP POLICY IF EXISTS "Drivers can view their own pending topups" ON pending_topups;
CREATE POLICY "Drivers can view their own pending topups" ON pending_topups
  FOR SELECT USING (driver_id = auth.uid());

-- Complete Wayl topup and apply to the right wallet
CREATE OR REPLACE FUNCTION complete_wayl_topup(
  p_wayl_reference_id text,
  p_webhook_data jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_topup pending_topups%ROWTYPE;
  v_result jsonb;
BEGIN
  SELECT * INTO v_pending_topup
  FROM pending_topups
  WHERE wayl_reference_id = p_wayl_reference_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Pending topup not found or already processed'
    );
  END IF;

  UPDATE pending_topups
  SET status = 'completed',
      completed_at = now(),
      webhook_data = COALESCE(p_webhook_data, webhook_data),
      updated_at = now()
  WHERE id = v_pending_topup.id;

  IF v_pending_topup.wallet_type = 'driver' THEN
    SELECT add_driver_wallet_balance(
      v_pending_topup.driver_id,
      v_pending_topup.amount,
      'wayl',
      'شحن عبر Wayl - ' || v_pending_topup.wayl_reference_id
    ) INTO v_result;
  ELSE
    SELECT add_wallet_balance(
      v_pending_topup.merchant_id,
      v_pending_topup.amount,
      'wayl',
      'شحن عبر Wayl - ' || v_pending_topup.wayl_reference_id
    ) INTO v_result;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'pending_topup_id', v_pending_topup.id,
    'wallet_result', v_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION complete_wayl_topup(text, jsonb) TO authenticated, anon;

-- -------------------------------------------------------------------------------------
-- 3) Enforce: driver cannot go online or accept orders with negative wallet balance
-- -------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION is_driver_wallet_positive(p_driver_id UUID)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance DECIMAL(10,2);
BEGIN
  SELECT balance INTO v_balance
  FROM driver_wallets
  WHERE driver_id = p_driver_id;

  v_balance := COALESCE(v_balance, 0.00);

  RETURN v_balance >= 0;
END;
$$;

GRANT EXECUTE ON FUNCTION is_driver_wallet_positive(UUID) TO authenticated, anon;

CREATE OR REPLACE FUNCTION prevent_driver_online_if_wallet_negative()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'driver' AND NEW.is_online = true THEN
    IF NOT is_driver_wallet_positive(NEW.id) THEN
      RAISE EXCEPTION 'DRIVER_WALLET_NEGATIVE';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_driver_online_if_wallet_negative_trigger ON users;
CREATE TRIGGER prevent_driver_online_if_wallet_negative_trigger
  BEFORE UPDATE OF is_online ON users
  FOR EACH ROW
  EXECUTE FUNCTION prevent_driver_online_if_wallet_negative();

-- Guard driver_accept_order
CREATE OR REPLACE FUNCTION driver_accept_order(
  p_order_id UUID,
  p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status TEXT;
  v_assigned_driver UUID;
  v_response_time INTEGER;
BEGIN
  IF NOT is_driver_wallet_positive(p_driver_id) THEN
    RAISE EXCEPTION 'DRIVER_WALLET_NEGATIVE';
  END IF;

  SELECT status, driver_id INTO v_order_status, v_assigned_driver
  FROM orders
  WHERE id = p_order_id;

  IF v_order_status != 'pending' THEN
    RAISE EXCEPTION 'Order is not pending (status: %)', v_order_status;
  END IF;

  IF v_assigned_driver != p_driver_id THEN
    RAISE EXCEPTION 'Order is not assigned to this driver';
  END IF;

  SELECT EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER
  INTO v_response_time
  FROM orders
  WHERE id = p_order_id;

  UPDATE orders
  SET
    status = 'accepted',
    accepted_at = NOW(),
    updated_at = NOW()
  WHERE id = p_order_id;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
    UPDATE order_assignments
    SET
      status = 'accepted',
      responded_at = NOW(),
      response_time_seconds = v_response_time
    WHERE order_id = p_order_id AND driver_id = p_driver_id AND status = 'pending';
  END IF;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION driver_accept_order(UUID, UUID) TO authenticated, anon;

-- -------------------------------------------------------------------------------------
-- 4) Monthly driver rank automation (pg_cron)
-- -------------------------------------------------------------------------------------

-- Ensure rank reset + recalculation runs monthly.
-- NOTE: Some Supabase projects restrict pg_cron installation/privileges.
-- This migration will only schedule the cron job if pg_cron is already available.

CREATE OR REPLACE FUNCTION run_monthly_driver_rank_adjustments()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reset_result jsonb;
  v_driver RECORD;
  v_updated INTEGER := 0;
BEGIN
  v_reset_result := reset_driver_ranks_monthly();

  FOR v_driver IN
    SELECT id
    FROM users
    WHERE role = 'driver'
  LOOP
    PERFORM update_driver_rank(v_driver.id);
    v_updated := v_updated + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'reset', v_reset_result,
    'drivers_processed', v_updated
  );
END;
$$;

GRANT EXECUTE ON FUNCTION run_monthly_driver_rank_adjustments() TO authenticated, anon;

DO $$
BEGIN
  -- Only schedule if pg_cron functions exist
  IF to_regprocedure('cron.schedule(text,text,text)') IS NULL THEN
    RAISE NOTICE 'pg_cron is not available; skipping monthly-driver-rank-adjustments scheduling.';
    RETURN;
  END IF;

  -- Unschedule old job if possible
  IF to_regprocedure('cron.unschedule(text)') IS NOT NULL THEN
    PERFORM cron.unschedule('monthly-driver-rank-adjustments')
    WHERE to_regclass('cron.job') IS NOT NULL
      AND EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'monthly-driver-rank-adjustments');
  END IF;

  -- Run at 00:05 on the 1st of every month
  PERFORM cron.schedule(
    'monthly-driver-rank-adjustments',
    '5 0 1 * *',
    $job$SELECT run_monthly_driver_rank_adjustments();$job$
  );
END $$;
