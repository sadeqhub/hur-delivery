-- =====================================================================================
-- DIAGNOSTIC: Check Fee Deduction Status
-- =====================================================================================
-- This migration adds diagnostic functions to check why fees aren't being deducted
-- =====================================================================================

-- Function to check if a merchant should have fees deducted
CREATE OR REPLACE FUNCTION diagnose_merchant_fee_deduction(p_merchant_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_merchant_created_at TIMESTAMPTZ;
  v_merchant_city TEXT;
  v_merchant_wallet_enabled BOOLEAN;
  v_merchant_wallet_setting TEXT;
  v_is_exempt BOOLEAN;
  v_days_old NUMERIC;
  v_result JSONB;
BEGIN
  -- Get merchant info
  SELECT city, created_at INTO v_merchant_city, v_merchant_created_at
  FROM users
  WHERE id = p_merchant_id AND role = 'merchant';
  
  IF v_merchant_created_at IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'Merchant not found or not a merchant',
      'merchant_id', p_merchant_id
    );
  END IF;
  
  -- Calculate age
  v_days_old := EXTRACT(EPOCH FROM (NOW() - v_merchant_created_at)) / 86400;
  v_is_exempt := v_merchant_created_at > (NOW() - INTERVAL '30 days');
  
  -- Check merchant-specific setting
  SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
  FROM merchant_settings
  WHERE merchant_id = p_merchant_id;
  
  -- Check global setting
  SELECT value INTO v_merchant_wallet_setting
  FROM system_settings
  WHERE key = 'merchant_wallet';
  
  -- Build result
  v_result := jsonb_build_object(
    'merchant_id', p_merchant_id,
    'created_at', v_merchant_created_at,
    'days_old', ROUND(v_days_old, 2),
    'is_exempt_from_fees', v_is_exempt,
    'city', v_merchant_city,
    'merchant_specific_wallet_enabled', v_merchant_wallet_enabled,
    'global_wallet_setting', v_merchant_wallet_setting,
    'should_deduct_fees', CASE
      WHEN v_is_exempt THEN false
      WHEN v_merchant_wallet_enabled IS NOT NULL AND NOT v_merchant_wallet_enabled THEN false
      WHEN v_merchant_wallet_setting IS DISTINCT FROM 'enabled' THEN false
      ELSE true
    END,
    'blocking_reason', CASE
      WHEN v_is_exempt THEN 'Merchant is less than 30 days old (exempt from fees)'
      WHEN v_merchant_wallet_enabled IS NOT NULL AND NOT v_merchant_wallet_enabled THEN 'Merchant-specific wallet is disabled'
      WHEN v_merchant_city IS NOT NULL THEN 
        (SELECT CASE 
          WHEN merchant_wallet_enabled IS NOT NULL AND NOT merchant_wallet_enabled 
          THEN 'City-specific wallet is disabled for ' || v_merchant_city
          ELSE NULL
        END FROM city_settings WHERE city = v_merchant_city)
      WHEN v_merchant_wallet_setting IS DISTINCT FROM 'enabled' THEN 
        'Global wallet setting is not "enabled" (current: ' || COALESCE(v_merchant_wallet_setting, 'NULL') || ')'
      ELSE 'No blocking reason found - fees should be deducted'
    END
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check recent fee deductions for a merchant
CREATE OR REPLACE FUNCTION check_recent_fee_deductions(p_merchant_id UUID, p_days INTEGER DEFAULT 7)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_recent_orders JSONB;
  v_recent_transactions JSONB;
BEGIN
  -- Get recent delivered orders
  SELECT jsonb_agg(
    jsonb_build_object(
      'order_id', id,
      'status', status,
      'delivered_at', delivered_at,
      'total_amount', total_amount,
      'delivery_fee', delivery_fee,
      'days_ago', EXTRACT(EPOCH FROM (NOW() - delivered_at)) / 86400
    ) ORDER BY delivered_at DESC
  ) INTO v_recent_orders
  FROM orders
  WHERE merchant_id = p_merchant_id
    AND status = 'delivered'
    AND delivered_at >= NOW() - (p_days || ' days')::INTERVAL;
  
  -- Get recent fee transactions
  SELECT jsonb_agg(
    jsonb_build_object(
      'transaction_id', id,
      'transaction_type', transaction_type,
      'amount', amount,
      'order_id', order_id,
      'created_at', created_at,
      'balance_before', balance_before,
      'balance_after', balance_after,
      'notes', notes
    ) ORDER BY created_at DESC
  ) INTO v_recent_transactions
  FROM wallet_transactions
  WHERE merchant_id = p_merchant_id
    AND transaction_type = 'order_fee'
    AND created_at >= NOW() - (p_days || ' days')::INTERVAL;
  
  v_result := jsonb_build_object(
    'merchant_id', p_merchant_id,
    'period_days', p_days,
    'recent_delivered_orders', COALESCE(v_recent_orders, '[]'::jsonb),
    'recent_fee_transactions', COALESCE(v_recent_transactions, '[]'::jsonb),
    'orders_count', (SELECT COUNT(*) FROM orders WHERE merchant_id = p_merchant_id AND status = 'delivered' AND delivered_at >= NOW() - (p_days || ' days')::INTERVAL),
    'transactions_count', (SELECT COUNT(*) FROM wallet_transactions WHERE merchant_id = p_merchant_id AND transaction_type = 'order_fee' AND created_at >= NOW() - (p_days || ' days')::INTERVAL),
    'missing_deductions', (
      SELECT COUNT(*)
      FROM orders o
      WHERE o.merchant_id = p_merchant_id
        AND o.status = 'delivered'
        AND o.delivered_at >= NOW() - (p_days || ' days')::INTERVAL
        AND NOT EXISTS (
          SELECT 1 FROM wallet_transactions wt
          WHERE wt.order_id = o.id
            AND wt.transaction_type = 'order_fee'
        )
    )
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION diagnose_merchant_fee_deduction(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION check_recent_fee_deductions(UUID, INTEGER) TO authenticated, anon;

COMMENT ON FUNCTION diagnose_merchant_fee_deduction IS 
'Diagnostic function to check why fees might not be deducted for a merchant';

COMMENT ON FUNCTION check_recent_fee_deductions IS 
'Check recent fee deductions for a merchant to identify missing deductions';

