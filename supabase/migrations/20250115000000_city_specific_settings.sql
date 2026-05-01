-- =====================================================================================
-- CITY-SPECIFIC COMMISSION AND WALLET SETTINGS
-- =====================================================================================
-- This migration creates city-specific settings for commissions and wallets.
-- Each city (najaf, mosul) can have different:
-- - Wallet enable/disable settings for drivers and merchants
-- - Commission types and values for drivers (fixed or percentage per rank)
-- - Commission types and values for merchants (fixed, percentage from order fee, or percentage from delivery fee)
-- =====================================================================================

-- Create city_settings table
CREATE TABLE IF NOT EXISTS city_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city TEXT NOT NULL UNIQUE CHECK (city IN ('najaf', 'mosul')),
  
  -- Driver wallet settings
  driver_wallet_enabled BOOLEAN NOT NULL DEFAULT true,
  
  -- Driver commission settings
  driver_commission_type TEXT NOT NULL DEFAULT 'percentage_delivery_fee' 
    CHECK (driver_commission_type IN ('fixed', 'percentage_delivery_fee')),
  driver_commission_value DECIMAL(10,2), -- Fixed amount or percentage value
  driver_commission_by_rank JSONB DEFAULT '{}'::jsonb, -- Per-rank overrides: {"trial": 0, "bronze": 10, "silver": 7, "gold": 5}
  
  -- Merchant wallet settings
  merchant_wallet_enabled BOOLEAN NOT NULL DEFAULT true,
  
  -- Merchant commission settings
  merchant_commission_type TEXT NOT NULL DEFAULT 'fixed' 
    CHECK (merchant_commission_type IN ('fixed', 'percentage_order_fee', 'percentage_delivery_fee')),
  merchant_commission_value DECIMAL(10,2) NOT NULL DEFAULT 500.00, -- Fixed amount or percentage value
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_city_settings_city ON city_settings(city);

-- Enable RLS
ALTER TABLE city_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Only admins can view/edit city settings
CREATE POLICY "Admins can view city settings" ON city_settings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

CREATE POLICY "Admins can insert city settings" ON city_settings
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update city settings" ON city_settings
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

-- Initialize default settings for najaf and mosul
INSERT INTO city_settings (city, driver_wallet_enabled, driver_commission_type, driver_commission_value, driver_commission_by_rank, merchant_wallet_enabled, merchant_commission_type, merchant_commission_value)
VALUES 
  (
    'najaf',
    true,
    'percentage_delivery_fee',
    NULL, -- Using per-rank percentages
    '{"trial": 0, "bronze": 10, "silver": 7, "gold": 5}'::jsonb,
    true,
    'fixed',
    500.00
  ),
  (
    'mosul',
    true,
    'percentage_delivery_fee',
    NULL, -- Using per-rank percentages
    '{"trial": 0, "bronze": 10, "silver": 7, "gold": 5}'::jsonb,
    true,
    'fixed',
    500.00
  )
ON CONFLICT (city) DO NOTHING;

-- Add comment
COMMENT ON TABLE city_settings IS 'City-specific settings for wallet enablement and commission structures';
COMMENT ON COLUMN city_settings.driver_commission_by_rank IS 'JSON object with commission percentages per rank: {"trial": 0, "bronze": 10, "silver": 7, "gold": 5}';

-- =====================================================================================
-- HELPER FUNCTIONS TO GET CITY SETTINGS
-- =====================================================================================

-- Function to get city from user
CREATE OR REPLACE FUNCTION get_user_city(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_city TEXT;
BEGIN
  SELECT city INTO v_city
  FROM users
  WHERE id = p_user_id;
  
  RETURN v_city;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get city settings
CREATE OR REPLACE FUNCTION get_city_settings(p_city TEXT)
RETURNS TABLE (
  driver_wallet_enabled BOOLEAN,
  driver_commission_type TEXT,
  driver_commission_value DECIMAL,
  driver_commission_by_rank JSONB,
  merchant_wallet_enabled BOOLEAN,
  merchant_commission_type TEXT,
  merchant_commission_value DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cs.driver_wallet_enabled,
    cs.driver_commission_type,
    cs.driver_commission_value,
    cs.driver_commission_by_rank,
    cs.merchant_wallet_enabled,
    cs.merchant_commission_type,
    cs.merchant_commission_value
  FROM city_settings cs
  WHERE cs.city = p_city;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- UPDATE DRIVER COMMISSION FUNCTIONS TO USE CITY SETTINGS
-- =====================================================================================

-- Updated function to get driver commission percentage based on city and rank
CREATE OR REPLACE FUNCTION get_driver_commission_percentage(p_driver_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  v_rank TEXT;
  v_city TEXT;
  v_commission_percentage DECIMAL;
  v_commission_type TEXT;
  v_commission_by_rank JSONB;
BEGIN
  -- Get driver rank and city
  SELECT rank, city INTO v_rank, v_city
  FROM users
  WHERE id = p_driver_id AND role = 'driver';
  
  -- Default to bronze if rank is null
  IF v_rank IS NULL THEN
    v_rank := 'bronze';
  END IF;
  
  -- If city is null, fall back to global settings
  IF v_city IS NULL THEN
    -- Fallback to old system_settings approach
    SELECT value::DECIMAL INTO v_commission_percentage
    FROM system_settings
    WHERE key = CASE v_rank
      WHEN 'trial' THEN 'trial_commission_percentage'
      WHEN 'bronze' THEN 'bronze_commission_percentage'
      WHEN 'silver' THEN 'silver_commission_percentage'
      WHEN 'gold' THEN 'gold_commission_percentage'
      ELSE 'bronze_commission_percentage'
    END;
    
    IF v_commission_percentage IS NULL THEN
      IF v_rank = 'trial' THEN
        v_commission_percentage := 0.0;
      ELSE
        v_commission_percentage := 10.0;
      END IF;
    END IF;
    
    RETURN v_commission_percentage;
  END IF;
  
  -- Get city-specific settings
  SELECT 
    driver_commission_type,
    driver_commission_value,
    driver_commission_by_rank
  INTO 
    v_commission_type,
    v_commission_percentage,
    v_commission_by_rank
  FROM city_settings
  WHERE city = v_city;
  
  -- If city settings not found, fall back to global settings
  IF v_commission_type IS NULL THEN
    SELECT value::DECIMAL INTO v_commission_percentage
    FROM system_settings
    WHERE key = CASE v_rank
      WHEN 'trial' THEN 'trial_commission_percentage'
      WHEN 'bronze' THEN 'bronze_commission_percentage'
      WHEN 'silver' THEN 'silver_commission_percentage'
      WHEN 'gold' THEN 'gold_commission_percentage'
      ELSE 'bronze_commission_percentage'
    END;
    
    IF v_commission_percentage IS NULL THEN
      IF v_rank = 'trial' THEN
        v_commission_percentage := 0.0;
      ELSE
        v_commission_percentage := 10.0;
      END IF;
    END IF;
    
    RETURN v_commission_percentage;
  END IF;
  
  -- If commission type is fixed, return 0 (percentage-based function)
  IF v_commission_type = 'fixed' THEN
    RETURN 0.0; -- Fixed commissions are handled separately
  END IF;
  
  -- For percentage_delivery_fee, check per-rank overrides
  IF v_commission_by_rank IS NOT NULL AND v_commission_by_rank ? v_rank THEN
    v_commission_percentage := (v_commission_by_rank->>v_rank)::DECIMAL;
  ELSIF v_commission_value IS NOT NULL THEN
    v_commission_percentage := v_commission_value;
  ELSE
    -- Fallback to default based on rank
    IF v_rank = 'trial' THEN
      v_commission_percentage := 0.0;
    ELSE
      v_commission_percentage := 10.0;
    END IF;
  END IF;
  
  RETURN COALESCE(v_commission_percentage, 0.0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get driver commission amount (handles both fixed and percentage)
CREATE OR REPLACE FUNCTION get_driver_commission_amount(
  p_driver_id UUID,
  p_delivery_fee DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
  v_rank TEXT;
  v_city TEXT;
  v_commission_type TEXT;
  v_commission_value DECIMAL;
  v_commission_by_rank JSONB;
  v_commission DECIMAL(10,2);
BEGIN
  -- Get driver rank and city
  SELECT rank, city INTO v_rank, v_city
  FROM users
  WHERE id = p_driver_id AND role = 'driver';
  
  -- Default to bronze if rank is null
  IF v_rank IS NULL THEN
    v_rank := 'bronze';
  END IF;
  
  -- If city is null, fall back to global settings (percentage only)
  IF v_city IS NULL THEN
    SELECT value::DECIMAL INTO v_commission_value
    FROM system_settings
    WHERE key = CASE v_rank
      WHEN 'trial' THEN 'trial_commission_percentage'
      WHEN 'bronze' THEN 'bronze_commission_percentage'
      WHEN 'silver' THEN 'silver_commission_percentage'
      WHEN 'gold' THEN 'gold_commission_percentage'
      ELSE 'bronze_commission_percentage'
    END;
    
    IF v_commission_value IS NULL THEN
      IF v_rank = 'trial' THEN
        v_commission_value := 0.0;
      ELSE
        v_commission_value := 10.0;
      END IF;
    END IF;
    
    RETURN ROUND((p_delivery_fee * v_commission_value) / 100.0, 2);
  END IF;
  
  -- Get city-specific settings
  SELECT 
    driver_commission_type,
    driver_commission_value,
    driver_commission_by_rank
  INTO 
    v_commission_type,
    v_commission_value,
    v_commission_by_rank
  FROM city_settings
  WHERE city = v_city;
  
  -- If city settings not found, fall back to global settings
  IF v_commission_type IS NULL THEN
    SELECT value::DECIMAL INTO v_commission_value
    FROM system_settings
    WHERE key = CASE v_rank
      WHEN 'trial' THEN 'trial_commission_percentage'
      WHEN 'bronze' THEN 'bronze_commission_percentage'
      WHEN 'silver' THEN 'silver_commission_percentage'
      WHEN 'gold' THEN 'gold_commission_percentage'
      ELSE 'bronze_commission_percentage'
    END;
    
    IF v_commission_value IS NULL THEN
      IF v_rank = 'trial' THEN
        v_commission_value := 0.0;
      ELSE
        v_commission_value := 10.0;
      END IF;
    END IF;
    
    RETURN ROUND((p_delivery_fee * v_commission_value) / 100.0, 2);
  END IF;
  
  -- Calculate commission based on type
  IF v_commission_type = 'fixed' THEN
    -- Fixed commission
    RETURN COALESCE(v_commission_value, 0.0);
  ELSE
    -- Percentage commission - check per-rank overrides
    IF v_commission_by_rank IS NOT NULL AND v_commission_by_rank ? v_rank THEN
      v_commission_value := (v_commission_by_rank->>v_rank)::DECIMAL;
    ELSIF v_commission_value IS NULL THEN
      -- Fallback to default based on rank
      IF v_rank = 'trial' THEN
        v_commission_value := 0.0;
      ELSE
        v_commission_value := 10.0;
      END IF;
    END IF;
    
    RETURN ROUND((p_delivery_fee * v_commission_value) / 100.0, 2);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- UPDATE DRIVER WALLET FUNCTIONS TO USE CITY SETTINGS
-- =====================================================================================

-- Update deduct_driver_commission_for_order to check city-specific wallet settings
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
  v_city TEXT;
  v_city_wallet_enabled BOOLEAN;
  v_commission DECIMAL(10,2);
  v_current_balance DECIMAL(10,2);
  v_new_balance DECIMAL(10,2);
  v_existing_tx UUID;
  v_tx_id UUID;
BEGIN
  -- Get driver city
  SELECT city INTO v_city
  FROM users
  WHERE id = p_driver_id AND role = 'driver';
  
  -- Check city-specific wallet setting first, then fall back to global
  IF v_city IS NOT NULL THEN
    SELECT driver_wallet_enabled INTO v_city_wallet_enabled
    FROM city_settings
    WHERE city = v_city;
    
    IF v_city_wallet_enabled IS NOT NULL AND NOT v_city_wallet_enabled THEN
      RETURN jsonb_build_object(
        'success', true,
        'wallet_disabled', true,
        'message', 'Driver wallet is disabled for this city'
      );
    END IF;
  END IF;
  
  -- Fallback to global setting
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

  -- Calculate commission using city-specific settings
  v_commission := get_driver_commission_amount(p_driver_id, p_delivery_fee);

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
    'عمولة من طلب #' || substring(p_order_id::text, 1, 8) || ' (' || v_commission || ' IQD)'
  ) RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_tx_id,
    'balance_before', v_current_balance,
    'balance_after', v_new_balance,
    'commission', v_commission
  );
END;
$$;

-- =====================================================================================
-- UPDATE MERCHANT COMMISSION FUNCTIONS TO USE CITY SETTINGS
-- =====================================================================================

-- Function to get merchant commission amount based on city settings
CREATE OR REPLACE FUNCTION get_merchant_commission_amount(
  p_merchant_id UUID,
  p_total_amount DECIMAL,
  p_delivery_fee DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
  v_city TEXT;
  v_commission_type TEXT;
  v_commission_value DECIMAL;
  v_commission DECIMAL(10,2);
BEGIN
  -- Get merchant city
  SELECT city INTO v_city
  FROM users
  WHERE id = p_merchant_id AND role = 'merchant';
  
  -- If city is null, use default fixed commission
  IF v_city IS NULL THEN
    RETURN 500.00; -- Default fixed commission
  END IF;
  
  -- Get city-specific settings
  SELECT 
    merchant_commission_type,
    merchant_commission_value
  INTO 
    v_commission_type,
    v_commission_value
  FROM city_settings
  WHERE city = v_city;
  
  -- If city settings not found, use default
  IF v_commission_type IS NULL THEN
    RETURN 500.00; -- Default fixed commission
  END IF;
  
  -- Calculate commission based on type
  IF v_commission_type = 'fixed' THEN
    RETURN COALESCE(v_commission_value, 500.00);
  ELSIF v_commission_type = 'percentage_order_fee' THEN
    RETURN ROUND((p_total_amount * COALESCE(v_commission_value, 10.0)) / 100.0, 2);
  ELSIF v_commission_type = 'percentage_delivery_fee' THEN
    RETURN ROUND((p_delivery_fee * COALESCE(v_commission_value, 10.0)) / 100.0, 2);
  ELSE
    RETURN 500.00; -- Default fallback
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update merchant wallet deduction function to use city-specific settings
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
  v_commission_amount DECIMAL(10,2);
BEGIN
  -- Only deduct fee when order is delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    
    -- Get merchant city
    SELECT city INTO v_merchant_city
    FROM users
    WHERE id = NEW.merchant_id AND role = 'merchant';
    
    -- Check city-specific wallet setting first, then fall back to global
    IF v_merchant_city IS NOT NULL THEN
      SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
      FROM city_settings
      WHERE city = v_merchant_city;
      
      IF v_merchant_wallet_enabled IS NOT NULL AND NOT v_merchant_wallet_enabled THEN
        -- Wallet disabled for this city, skip deduction
        RETURN NEW;
      END IF;
    END IF;
    
    -- Fallback to global setting
    SELECT value INTO v_merchant_wallet_enabled
    FROM system_settings
    WHERE key = 'merchant_wallet';
    
    IF v_merchant_wallet_enabled IS DISTINCT FROM 'enabled' THEN
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
-- UPDATE WALLET PROVIDER FUNCTIONS TO CHECK CITY SETTINGS
-- =====================================================================================

-- Function to check if driver wallet is enabled for a city
CREATE OR REPLACE FUNCTION is_driver_wallet_enabled(p_driver_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_city TEXT;
  v_city_wallet_enabled BOOLEAN;
  v_global_wallet_enabled TEXT;
BEGIN
  -- Get driver city
  SELECT city INTO v_city
  FROM users
  WHERE id = p_driver_id AND role = 'driver';
  
  -- Check city-specific setting first
  IF v_city IS NOT NULL THEN
    SELECT driver_wallet_enabled INTO v_city_wallet_enabled
    FROM city_settings
    WHERE city = v_city;
    
    IF v_city_wallet_enabled IS NOT NULL THEN
      RETURN v_city_wallet_enabled;
    END IF;
  END IF;
  
  -- Fallback to global setting
  SELECT value INTO v_global_wallet_enabled
  FROM system_settings
  WHERE key = 'driver_wallet';
  
  RETURN COALESCE(v_global_wallet_enabled = 'enabled', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if merchant wallet is enabled for a city
CREATE OR REPLACE FUNCTION is_merchant_wallet_enabled(p_merchant_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_city TEXT;
  v_city_wallet_enabled BOOLEAN;
  v_global_wallet_enabled TEXT;
BEGIN
  -- Get merchant city
  SELECT city INTO v_city
  FROM users
  WHERE id = p_merchant_id AND role = 'merchant';
  
  -- Check city-specific setting first
  IF v_city IS NOT NULL THEN
    SELECT merchant_wallet_enabled INTO v_city_wallet_enabled
    FROM city_settings
    WHERE city = v_city;
    
    IF v_city_wallet_enabled IS NOT NULL THEN
      RETURN v_city_wallet_enabled;
    END IF;
  END IF;
  
  -- Fallback to global setting
  SELECT value INTO v_global_wallet_enabled
  FROM system_settings
  WHERE key = 'merchant_wallet';
  
  RETURN COALESCE(v_global_wallet_enabled = 'enabled', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT SELECT ON city_settings TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_user_city(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_city_settings(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_driver_commission_amount(UUID, DECIMAL) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_merchant_commission_amount(UUID, DECIMAL, DECIMAL) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION is_driver_wallet_enabled(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION is_merchant_wallet_enabled(UUID) TO authenticated, anon;

-- Enable realtime for city_settings
ALTER PUBLICATION supabase_realtime ADD TABLE city_settings;

