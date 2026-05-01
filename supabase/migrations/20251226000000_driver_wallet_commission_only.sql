-- =====================================================================================
-- DRIVER WALLET: COMMISSION-ONLY ACCOUNTING
-- =====================================================================================
-- Goal:
-- - Drivers collect delivery fee directly from customers.
-- - The system should NOT credit delivery fee to driver_wallets.
-- - The system should ONLY deduct the platform commission from driver_wallets when an order is delivered.
-- - Deductions must be idempotent (never double-deduct for the same order).
--
-- This migration overrides the wallet/earnings functions introduced in
-- 20251117000000_driver_rank_and_wallet_system.sql.

-- -------------------------------------------------------------------------------------
-- 1) Idempotency guard: one commission deduction per (driver_id, order_id)
-- -------------------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_driver_wallet_commission_deduction_per_order
  ON driver_wallet_transactions(driver_id, order_id)
  WHERE transaction_type = 'commission_deduction' AND order_id IS NOT NULL;

-- -------------------------------------------------------------------------------------
-- 2) Commission deduction function (updates wallet + inserts transaction)
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION deduct_driver_commission_for_order(
  p_driver_id UUID,
  p_order_id UUID,
  p_delivery_fee DECIMAL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_enabled TEXT;
  v_commission_percentage DECIMAL;
  v_commission DECIMAL(10,2);
  v_current_balance DECIMAL(10,2);
  v_new_balance DECIMAL(10,2);
  v_existing_tx UUID;
  v_tx_id UUID;
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

  -- Idempotency: if deduction already exists for this order, do nothing
  SELECT id INTO v_existing_tx
  FROM driver_wallet_transactions
  WHERE driver_id = p_driver_id
    AND order_id = p_order_id
    AND transaction_type = 'commission_deduction'
  LIMIT 1;

  IF v_existing_tx IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_deducted', true,
      'transaction_id', v_existing_tx
    );
  END IF;

  -- Calculate commission from rank-based percentage
  v_commission_percentage := get_driver_commission_percentage(p_driver_id);
  v_commission := ROUND((p_delivery_fee * v_commission_percentage) / 100.0, 2);

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

  -- Deduct commission only (delivery fee is NOT credited)
  v_new_balance := v_current_balance - v_commission;

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
    order_id,
    notes
  ) VALUES (
    p_driver_id,
    'commission_deduction',
    -v_commission,
    v_current_balance,
    v_new_balance,
    p_order_id,
    'خصم عمولة طلب #' || substring(p_order_id::text, 1, 8) || ' (' || v_commission_percentage || '%)'
  ) RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'commission_percentage', v_commission_percentage,
    'commission', v_commission,
    'balance_before', v_current_balance,
    'balance_after', v_new_balance,
    'transaction_id', v_tx_id
  );
END;
$$;

-- -------------------------------------------------------------------------------------
-- 3) Override create_driver_earning_with_rank to NOT credit wallet
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_driver_earning_with_rank(
  p_driver_id UUID,
  p_order_id UUID,
  p_delivery_fee DECIMAL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_commission_percentage DECIMAL;
  v_commission DECIMAL;
  v_net_amount DECIMAL;
  v_earning_id UUID;
  v_wallet_result jsonb;
BEGIN
  v_commission_percentage := get_driver_commission_percentage(p_driver_id);
  v_commission := (p_delivery_fee * v_commission_percentage) / 100.0;
  v_net_amount := p_delivery_fee - v_commission;

  -- Keep earnings record for reporting, but DO NOT credit wallet with delivery fee.
  INSERT INTO earnings (driver_id, order_id, amount, commission, net_amount, status)
  VALUES (p_driver_id, p_order_id, p_delivery_fee, v_commission, v_net_amount, 'pending')
  RETURNING id INTO v_earning_id;

  -- Deduct commission only from driver wallet
  v_wallet_result := deduct_driver_commission_for_order(
    p_driver_id,
    p_order_id,
    p_delivery_fee
  );

  RETURN jsonb_build_object(
    'success', true,
    'earning_id', v_earning_id,
    'delivery_fee', p_delivery_fee,
    'commission_percentage', v_commission_percentage,
    'commission', v_commission,
    'net_amount', v_net_amount,
    'wallet_result', v_wallet_result
  );
END;
$$;

-- -------------------------------------------------------------------------------------
-- 4) Override update_order_status to use the commission-only flow
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id UUID,
  p_new_status TEXT,
  p_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_status TEXT;
  v_driver_id UUID;
  v_merchant_id UUID;
  v_user_role TEXT;
  v_delivery_fee DECIMAL;
  v_order_exists BOOLEAN;
  v_user_exists BOOLEAN;
BEGIN
  RAISE NOTICE 'Attempting to update order % to status % by user %', p_order_id, p_new_status, p_user_id;

  SELECT EXISTS(SELECT 1 FROM orders WHERE id = p_order_id) INTO v_order_exists;
  IF NOT v_order_exists THEN
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_NOT_FOUND',
      'message', 'Order not found'
    );
  END IF;

  SELECT EXISTS(SELECT 1 FROM users WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RETURN json_build_object(
      'success', false,
      'error', 'USER_NOT_FOUND',
      'message', 'User not found'
    );
  END IF;

  SELECT status, driver_id, merchant_id, delivery_fee
  INTO v_current_status, v_driver_id, v_merchant_id, v_delivery_fee
  FROM orders
  WHERE id = p_order_id;

  SELECT role INTO v_user_role FROM users WHERE id = p_user_id;

  IF v_current_status IN ('delivered', 'cancelled') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_COMPLETED',
      'message', 'Cannot update completed order',
      'current_status', v_current_status
    );
  END IF;

  IF v_user_role = 'driver' THEN
    IF v_driver_id IS NULL THEN
      RETURN json_build_object(
        'success', false,
        'error', 'NOT_ASSIGNED',
        'message', 'Order is not assigned to any driver',
        'driver_id', v_driver_id
      );
    END IF;

    IF v_driver_id != p_user_id THEN
      RETURN json_build_object(
        'success', false,
        'error', 'UNAUTHORIZED',
        'message', 'Order not assigned to this driver',
        'expected_driver', v_driver_id,
        'actual_driver', p_user_id
      );
    END IF;
  END IF;

  IF v_user_role = 'merchant' AND v_merchant_id != p_user_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'UNAUTHORIZED',
      'message', 'Order does not belong to this merchant'
    );
  END IF;

  UPDATE orders
  SET
    status = p_new_status,
    updated_at = NOW(),
    picked_up_at = CASE WHEN p_new_status = 'on_the_way' THEN NOW() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE delivered_at END,
    cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN NOW() ELSE cancelled_at END
  WHERE id = p_order_id;

  -- Commission-only wallet update when order is delivered
  IF p_new_status = 'delivered' AND v_current_status != 'delivered' AND v_driver_id IS NOT NULL THEN
    PERFORM create_driver_earning_with_rank(
      v_driver_id,
      p_order_id,
      v_delivery_fee
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', 'Order status updated successfully',
    'old_status', v_current_status,
    'new_status', p_new_status
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', 'DATABASE_ERROR',
      'message', SQLERRM,
      'detail', SQLSTATE
    );
END;
$$;
