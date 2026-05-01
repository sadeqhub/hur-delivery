-- =====================================================================================
-- MERCHANT-SPECIFIC COMMISSION AND WALLET SETTINGS
-- =====================================================================================
-- This migration creates merchant-specific settings that override city settings.
-- Each merchant can have personalized:
-- - Wallet enable/disable settings
-- - Commission types and values (fixed, percentage from order fee, or percentage from delivery fee)
-- Settings default to city settings if not set for a merchant.
-- =====================================================================================

-- Create merchant_settings table
CREATE TABLE IF NOT EXISTS merchant_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  
  -- Merchant wallet settings
  merchant_wallet_enabled BOOLEAN, -- NULL means use city default
  
  -- Merchant commission settings
  merchant_commission_type TEXT 
    CHECK (merchant_commission_type IN ('fixed', 'percentage_order_fee', 'percentage_delivery_fee') OR merchant_commission_type IS NULL),
  merchant_commission_value DECIMAL(10,2), -- NULL means use city default
  
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_merchant_settings_merchant ON merchant_settings(merchant_id);

-- Enable RLS
ALTER TABLE merchant_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Only admins can view/edit merchant settings
CREATE POLICY "Admins can view merchant settings" ON merchant_settings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

CREATE POLICY "Admins can insert merchant settings" ON merchant_settings
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update merchant settings" ON merchant_settings
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete merchant settings" ON merchant_settings
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

-- Add comment
COMMENT ON TABLE merchant_settings IS 'Merchant-specific settings that override city settings. NULL values mean use city default.';
COMMENT ON COLUMN merchant_settings.merchant_wallet_enabled IS 'NULL means use city default, true/false overrides city setting';
COMMENT ON COLUMN merchant_settings.merchant_commission_type IS 'NULL means use city default';
COMMENT ON COLUMN merchant_settings.merchant_commission_value IS 'NULL means use city default';

-- =====================================================================================
-- FUNCTION TO INITIALIZE MERCHANT SETTINGS FROM CITY SETTINGS
-- =====================================================================================
CREATE OR REPLACE FUNCTION initialize_merchant_settings_from_city(p_merchant_id UUID)
RETURNS VOID AS $$
DECLARE
  v_merchant_city TEXT;
  v_city_settings RECORD;
BEGIN
  -- Get merchant city
  SELECT city INTO v_merchant_city
  FROM users
  WHERE id = p_merchant_id AND role = 'merchant';
  
  -- If merchant has no city, skip initialization
  IF v_merchant_city IS NULL THEN
    RETURN;
  END IF;
  
  -- Get city settings
  SELECT 
    merchant_wallet_enabled,
    merchant_commission_type,
    merchant_commission_value
  INTO v_city_settings
  FROM city_settings
  WHERE city = v_merchant_city;
  
  -- If city settings exist and merchant settings don't exist, create merchant settings
  IF v_city_settings IS NOT NULL THEN
    INSERT INTO merchant_settings (
      merchant_id,
      merchant_wallet_enabled,
      merchant_commission_type,
      merchant_commission_value
    )
    VALUES (
      p_merchant_id,
      v_city_settings.merchant_wallet_enabled,
      v_city_settings.merchant_commission_type,
      v_city_settings.merchant_commission_value
    )
    ON CONFLICT (merchant_id) DO NOTHING;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- UPDATE EXISTING FUNCTIONS TO CHECK MERCHANT SETTINGS FIRST
-- =====================================================================================

-- Update is_merchant_wallet_enabled to check merchant settings first
CREATE OR REPLACE FUNCTION is_merchant_wallet_enabled(p_merchant_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_city TEXT;
  v_merchant_wallet_enabled BOOLEAN;
  v_city_wallet_enabled BOOLEAN;
  v_global_wallet_enabled TEXT;
BEGIN
  -- Check merchant-specific setting first
  SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
  FROM merchant_settings
  WHERE merchant_id = p_merchant_id;
  
  -- If merchant has explicit setting, use it
  IF v_merchant_wallet_enabled IS NOT NULL THEN
    RETURN v_merchant_wallet_enabled;
  END IF;
  
  -- Get merchant city
  SELECT city INTO v_city
  FROM users
  WHERE id = p_merchant_id AND role = 'merchant';
  
  -- Check city-specific setting
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

-- Update get_merchant_commission_amount to check merchant settings first
CREATE OR REPLACE FUNCTION get_merchant_commission_amount(
  p_merchant_id UUID,
  p_total_amount DECIMAL,
  p_delivery_fee DECIMAL
)
RETURNS DECIMAL(10,2) AS $$
DECLARE
  v_city TEXT;
  v_merchant_commission_type TEXT;
  v_merchant_commission_value DECIMAL(10,2);
  v_city_commission_type TEXT;
  v_city_commission_value DECIMAL(10,2);
  v_commission DECIMAL(10,2);
BEGIN
  -- Check merchant-specific settings first
  SELECT merchant_commission_type, merchant_commission_value
  INTO v_merchant_commission_type, v_merchant_commission_value
  FROM merchant_settings
  WHERE merchant_id = p_merchant_id;
  
  -- If merchant has explicit settings, use them
  IF v_merchant_commission_type IS NOT NULL AND v_merchant_commission_value IS NOT NULL THEN
    IF v_merchant_commission_type = 'fixed' THEN
      RETURN v_merchant_commission_value;
    ELSIF v_merchant_commission_type = 'percentage_order_fee' THEN
      RETURN ROUND((p_total_amount * v_merchant_commission_value) / 100.0, 2);
    ELSIF v_merchant_commission_type = 'percentage_delivery_fee' THEN
      RETURN ROUND((p_delivery_fee * v_merchant_commission_value) / 100.0, 2);
    END IF;
  END IF;
  
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
    v_city_commission_type,
    v_city_commission_value
  FROM city_settings
  WHERE city = v_city;
  
  -- If city settings not found, use default
  IF v_city_commission_type IS NULL THEN
    RETURN 500.00; -- Default fixed commission
  END IF;
  
  -- Calculate commission based on city settings
  IF v_city_commission_type = 'fixed' THEN
    RETURN COALESCE(v_city_commission_value, 500.00);
  ELSIF v_city_commission_type = 'percentage_order_fee' THEN
    RETURN ROUND((p_total_amount * COALESCE(v_city_commission_value, 10.0)) / 100.0, 2);
  ELSIF v_city_commission_type = 'percentage_delivery_fee' THEN
    RETURN ROUND((p_delivery_fee * COALESCE(v_city_commission_value, 10.0)) / 100.0, 2);
  ELSE
    RETURN 500.00; -- Default fallback
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- TRIGGER TO AUTO-INITIALIZE MERCHANT SETTINGS WHEN MERCHANT IS CREATED
-- =====================================================================================
CREATE OR REPLACE FUNCTION auto_initialize_merchant_settings()
RETURNS TRIGGER AS $$
BEGIN
  -- Only for merchants
  IF NEW.role = 'merchant' THEN
    -- Initialize settings from city (if city exists)
    PERFORM initialize_merchant_settings_from_city(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS auto_initialize_merchant_settings_trigger ON users;
CREATE TRIGGER auto_initialize_merchant_settings_trigger
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION auto_initialize_merchant_settings();

-- =====================================================================================
-- INITIALIZE SETTINGS FOR EXISTING MERCHANTS
-- =====================================================================================
-- Initialize merchant settings for all existing merchants from their city settings
DO $$
DECLARE
  merchant_record RECORD;
BEGIN
  FOR merchant_record IN 
    SELECT id FROM users WHERE role = 'merchant'
  LOOP
    PERFORM initialize_merchant_settings_from_city(merchant_record.id);
  END LOOP;
END $$;

-- Grant permissions
GRANT SELECT ON merchant_settings TO authenticated, anon;
GRANT EXECUTE ON FUNCTION initialize_merchant_settings_from_city(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION is_merchant_wallet_enabled(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_merchant_commission_amount(UUID, DECIMAL, DECIMAL) TO authenticated, anon;

-- Enable realtime for merchant_settings
ALTER PUBLICATION supabase_realtime ADD TABLE merchant_settings;

