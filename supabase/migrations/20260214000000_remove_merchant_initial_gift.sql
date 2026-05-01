-- =====================================================================================
-- REMOVE MERCHANT INITIAL GIFT
-- =====================================================================================
-- Removes the initial gift/credit given to merchants when they sign up
-- New merchants will start with 0.00 balance instead of the welcome gift
-- =====================================================================================

-- Update the wallet initialization function to remove initial gift
CREATE OR REPLACE FUNCTION initialize_merchant_wallet()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create wallet for merchants
  IF NEW.role = 'merchant' THEN
    -- Create wallet with zero balance (no initial gift)
    INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
    VALUES (NEW.id, 0.00, 500.00, -10000.00);
    
    -- No initial gift transaction is recorded
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permission to the updated function
GRANT EXECUTE ON FUNCTION initialize_merchant_wallet() TO anon, authenticated;

COMMENT ON FUNCTION initialize_merchant_wallet() IS 'Creates wallet for new merchants with zero balance (no initial gift)';

-- Also update deduct_order_fee_from_wallet to create wallets with zero balance
-- (in case a wallet doesn't exist when fee deduction happens)
-- We only update the wallet creation part, keeping the rest of the function intact
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
  v_merchant_wallet_setting TEXT;
  v_commission_amount DECIMAL(10,2);
  v_merchant_created_at TIMESTAMPTZ;
  v_days_old NUMERIC;
BEGIN
  -- Only deduct fee when order is delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    
    BEGIN
      -- Get merchant info
      SELECT city, created_at INTO v_merchant_city, v_merchant_created_at
      FROM users
      WHERE id = NEW.merchant_id AND role = 'merchant';
      
      -- Check merchant age: Only exempt if merchant is LESS than 30 days old
      IF v_merchant_created_at IS NOT NULL THEN
        v_days_old := EXTRACT(EPOCH FROM (NOW() - v_merchant_created_at)) / 86400;
        
        -- If merchant is less than 30 days old, exempt from fees
        IF v_days_old < 30 THEN
          RETURN NEW; -- Skip fee deduction for new merchants
        END IF;
        -- Otherwise, merchant is 30+ days old, proceed with fee deduction
      END IF;
      
      -- Check merchant-specific wallet setting (highest priority)
      SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
      FROM merchant_settings
      WHERE merchant_id = NEW.merchant_id;
      
      -- If merchant has explicit setting to disable, skip
      IF v_merchant_wallet_enabled IS NOT NULL AND NOT v_merchant_wallet_enabled THEN
        RETURN NEW;
      END IF;
      
      -- Check city-specific wallet setting if merchant setting is NULL
      IF v_merchant_wallet_enabled IS NULL AND v_merchant_city IS NOT NULL THEN
        SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
        FROM city_settings
        WHERE city = v_merchant_city;
        
        -- If city has explicit setting to disable, skip
        IF v_merchant_wallet_enabled IS NOT NULL AND NOT v_merchant_wallet_enabled THEN
          RETURN NEW;
        END IF;
      END IF;
      
      -- Check global setting (lowest priority, defaults to enabled)
      SELECT value INTO v_merchant_wallet_setting
      FROM system_settings
      WHERE key = 'merchant_wallet';
      
      -- Default to 'enabled' if setting doesn't exist or is NULL
      IF v_merchant_wallet_setting IS NULL OR v_merchant_wallet_setting = '' THEN
        v_merchant_wallet_setting := 'enabled';
      END IF;
      
      -- Only skip if explicitly disabled
      IF v_merchant_wallet_setting != 'enabled' THEN
        RETURN NEW;
      END IF;
      
      -- All checks passed - proceed with fee deduction
      -- Calculate commission
      v_commission_amount := get_merchant_commission_amount(
        NEW.merchant_id,
        COALESCE(NEW.total_amount, 0.00),
        COALESCE(NEW.delivery_fee, 0.00)
      );
      
      -- Get or create merchant wallet (with zero balance, no initial gift)
      SELECT id, balance, order_fee, credit_limit 
      INTO v_wallet_id, v_current_balance, v_order_fee, v_credit_limit
      FROM merchant_wallets
      WHERE merchant_id = NEW.merchant_id;
      
      IF v_wallet_id IS NULL THEN
        -- Create wallet with zero balance (no initial gift)
        INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
        VALUES (NEW.merchant_id, 0.00, 500.00, -10000.00)
        RETURNING id, balance, order_fee, credit_limit 
        INTO v_wallet_id, v_current_balance, v_order_fee, v_credit_limit;
      END IF;
      
      -- Deduct commission
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
      
    EXCEPTION
      WHEN OTHERS THEN
        -- Log error but don't block order update
        RAISE WARNING 'Error in fee deduction for order % merchant %: %', 
          NEW.id, NEW.merchant_id, SQLERRM;
        RETURN NEW;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permission to the updated function
GRANT EXECUTE ON FUNCTION deduct_order_fee_from_wallet() TO anon, authenticated;

COMMENT ON FUNCTION deduct_order_fee_from_wallet() IS 'Deducts order fee from merchant wallet on delivery. Creates wallet with zero balance if missing (no initial gift).';

