-- =====================================================================================
-- MERCHANT FEE EXEMPTION FOR NEW MERCHANTS
-- =====================================================================================
-- This migration updates the deduct_order_fee_from_wallet function to exempt
-- merchants who have been registered for less than a month from fee deductions.
-- =====================================================================================

CREATE OR REPLACE FUNCTION deduct_order_fee_from_wallet()
RETURNS TRIGGER AS $$
DECLARE
  v_wallet_id uuid;
  v_current_balance decimal(10,2);
  v_order_fee decimal(10,2);
  v_credit_limit decimal(10,2);
  v_new_balance decimal(10,2);
  v_merchant_city TEXT;
  v_merchant_wallet_enabled BOOLEAN;
  v_merchant_wallet_setting TEXT; -- Separate variable for TEXT system_settings value
  v_commission_amount DECIMAL(10,2);
  v_merchant_created_at TIMESTAMPTZ;
  v_is_new_merchant BOOLEAN;
BEGIN
  -- Only deduct fee when order is delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    
    -- Get merchant city and registration date
    SELECT city, created_at INTO v_merchant_city, v_merchant_created_at
    FROM users
    WHERE id = NEW.merchant_id AND role = 'merchant';
    
    -- Check if merchant is less than a month old (30 days) - exempt from fees
    -- Only exempt if merchant was created less than 30 days ago
    IF v_merchant_created_at IS NOT NULL THEN
      -- Use explicit date comparison: merchant is new if created_at is within last 30 days
      IF v_merchant_created_at > (NOW() - INTERVAL '30 days') THEN
        -- Merchant is less than 30 days old, skip fee deduction
        RAISE NOTICE 'Merchant % is exempt from fees (registered less than 30 days ago)', 
          NEW.merchant_id;
        RETURN NEW;
      END IF;
      -- If merchant is 30 days or older, continue with fee deduction
    END IF;
    
    -- Check merchant-specific wallet setting first (from merchant_settings table)
    SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
    FROM merchant_settings
    WHERE merchant_id = NEW.merchant_id;
    
    -- If merchant has explicit setting, use it
    IF v_merchant_wallet_enabled IS NOT NULL THEN
      IF NOT v_merchant_wallet_enabled THEN
        -- Wallet disabled for this merchant, skip deduction
        RETURN NEW;
      END IF;
    ELSE
      -- Check city-specific wallet setting if merchant setting is NULL
      IF v_merchant_city IS NOT NULL THEN
        SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
        FROM city_settings
        WHERE city = v_merchant_city;
        
        IF v_merchant_wallet_enabled IS NOT NULL AND NOT v_merchant_wallet_enabled THEN
          -- Wallet disabled for this city, skip deduction
          RETURN NEW;
        END IF;
      END IF;
    END IF;
    
    -- Fallback to global setting - use TEXT variable for system_settings value
    SELECT value INTO v_merchant_wallet_setting
    FROM system_settings
    WHERE key = 'merchant_wallet';
    
    -- Check if wallet is enabled (must be exactly 'enabled' string)
    IF v_merchant_wallet_setting IS DISTINCT FROM 'enabled' THEN
      -- Wallet disabled globally, skip deduction
      RETURN NEW;
    END IF;
    
    -- Calculate commission based on city settings
    v_commission_amount := get_merchant_commission_amount(
      NEW.merchant_id,
      COALESCE(NEW.total_amount, 0.00),
      COALESCE(NEW.delivery_fee, 0.00)
    );
    
    -- Get merchant wallet info
    SELECT id, balance, order_fee, credit_limit 
    INTO v_wallet_id, v_current_balance, v_order_fee, v_credit_limit
    FROM merchant_wallets
    WHERE merchant_id = NEW.merchant_id;
    
    -- If wallet doesn't exist, create it (shouldn't happen, but safety check)
    IF v_wallet_id IS NULL THEN
      INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
      VALUES (NEW.merchant_id, 10000.00, 500.00, -10000.00)
      RETURNING id, balance, order_fee, credit_limit 
      INTO v_wallet_id, v_current_balance, v_order_fee, v_credit_limit;
    END IF;
    
    -- Use calculated commission amount instead of fixed order_fee
    v_new_balance := v_current_balance - v_commission_amount;
    
    -- Update wallet balance
    UPDATE merchant_wallets
    SET balance = v_new_balance,
        updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Record transaction
    INSERT INTO wallet_transactions (
      merchant_id,
      transaction_type,
      amount,
      balance_before,
      balance_after,
      order_id,
      notes
    ) VALUES (
      NEW.merchant_id,
      'order_fee',
      -v_commission_amount,
      v_current_balance,
      v_new_balance,
      NEW.id,
      'رسوم توصيل طلب #' || substring(NEW.id::text, 1, 8) || ' (' || v_commission_amount || ' IQD)'
    );
    
    -- Log if balance goes below credit limit (for monitoring)
    IF v_new_balance < v_credit_limit THEN
      RAISE NOTICE 'Merchant % balance (%) is below credit limit (%)', 
        NEW.merchant_id, v_new_balance, v_credit_limit;
    END IF;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- Helper function to check if merchant is exempt from fees
-- =====================================================================================
CREATE OR REPLACE FUNCTION is_merchant_fee_exempt(p_merchant_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_merchant_created_at TIMESTAMPTZ;
BEGIN
  SELECT created_at INTO v_merchant_created_at
  FROM users
  WHERE id = p_merchant_id AND role = 'merchant';
  
  IF v_merchant_created_at IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Return true if merchant is less than 30 days old (created within last 30 days)
  RETURN v_merchant_created_at > (NOW() - INTERVAL '30 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

