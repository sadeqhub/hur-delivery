-- =====================================================================================
-- DRIVER RANK AND WALLET SYSTEM
-- =====================================================================================
-- This migration implements:
-- 1. Wallet enable/disable settings for merchants and drivers
-- 2. Driver rank system (bronze, silver, gold) with commission percentages
-- 3. Driver wallets table and transactions
-- 4. Driver online hours tracking per month
-- 5. Rank advancement based on hours online or orders delivered
-- =====================================================================================

-- =====================================================================================
-- 1. ADD WALLET SETTINGS TO SYSTEM_SETTINGS
-- =====================================================================================

INSERT INTO system_settings (key, value, value_type, description, is_public) VALUES
  ('merchant_wallet', 'enabled', 'string', 'Enable/disable merchant wallet feature', TRUE),
  ('driver_wallet', 'enabled', 'string', 'Enable/disable driver wallet feature', TRUE),
  ('trial_commission_percentage', '0', 'number', 'Commission percentage for trial rank drivers (0% - first month)', FALSE),
  ('bronze_commission_percentage', '10', 'number', 'Commission percentage for bronze rank drivers (10%)', FALSE),
  ('silver_commission_percentage', '7', 'number', 'Commission percentage for silver rank drivers (7%)', FALSE),
  ('gold_commission_percentage', '5', 'number', 'Commission percentage for gold rank drivers (5%)', FALSE)
ON CONFLICT (key) DO NOTHING;

-- =====================================================================================
-- 2. ADD RANK FIELD TO USERS TABLE
-- =====================================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS rank TEXT DEFAULT 'trial' CHECK (rank IN ('trial', 'bronze', 'silver', 'gold'));

-- Update existing constraint if it exists (drop and recreate)
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_rank_check'
  ) THEN
    ALTER TABLE users DROP CONSTRAINT users_rank_check;
  END IF;
  
  -- Add new constraint with trial included
  ALTER TABLE users ADD CONSTRAINT users_rank_check 
    CHECK (rank IN ('trial', 'bronze', 'silver', 'gold'));
END $$;

-- Add index for rank queries
CREATE INDEX IF NOT EXISTS idx_users_rank ON users(rank) WHERE role = 'driver';

-- Add comment
COMMENT ON COLUMN users.rank IS 'Driver rank tier: trial (first month, 0% commission), bronze (default), silver, or gold';

-- =====================================================================================
-- 3. CREATE DRIVER WALLETS TABLE
-- =====================================================================================

CREATE TABLE IF NOT EXISTS driver_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  balance DECIMAL(10,2) DEFAULT 0.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_driver_wallets_driver ON driver_wallets(driver_id);

-- Enable RLS
ALTER TABLE driver_wallets ENABLE ROW LEVEL SECURITY;

-- RLS Policies for driver_wallets (drop if exists, then create)
DROP POLICY IF EXISTS "Drivers can view their own wallet" ON driver_wallets;
CREATE POLICY "Drivers can view their own wallet" ON driver_wallets
  FOR SELECT USING (driver_id = auth.uid());

DROP POLICY IF EXISTS "System can create wallets" ON driver_wallets;
CREATE POLICY "System can create wallets" ON driver_wallets
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "System can update wallets" ON driver_wallets;
CREATE POLICY "System can update wallets" ON driver_wallets
  FOR UPDATE USING (true);

-- =====================================================================================
-- 4. CREATE DRIVER WALLET TRANSACTIONS TABLE
-- =====================================================================================

CREATE TABLE IF NOT EXISTS driver_wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('earning', 'withdrawal', 'adjustment', 'commission_deduction')),
  amount DECIMAL(10,2) NOT NULL, -- Positive for credits, negative for debits
  balance_before DECIMAL(10,2) NOT NULL,
  balance_after DECIMAL(10,2) NOT NULL,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  payment_method TEXT CHECK (payment_method IN ('zain_cash', 'qi_card', 'hur_representative', 'admin_adjustment', 'bank_transfer')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_driver_wallet_transactions_driver ON driver_wallet_transactions(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_wallet_transactions_type ON driver_wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_driver_wallet_transactions_created ON driver_wallet_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_wallet_transactions_order ON driver_wallet_transactions(order_id);

-- Enable RLS
ALTER TABLE driver_wallet_transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for driver_wallet_transactions (drop if exists, then create)
DROP POLICY IF EXISTS "Drivers can view their own transactions" ON driver_wallet_transactions;
CREATE POLICY "Drivers can view their own transactions" ON driver_wallet_transactions
  FOR SELECT USING (driver_id = auth.uid());

DROP POLICY IF EXISTS "System can create transactions" ON driver_wallet_transactions;
CREATE POLICY "System can create transactions" ON driver_wallet_transactions
  FOR INSERT WITH CHECK (true);

-- =====================================================================================
-- 5. CREATE DRIVER ONLINE HOURS TRACKING TABLE
-- =====================================================================================

CREATE TABLE IF NOT EXISTS driver_online_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  hours_online DECIMAL(5,2) DEFAULT 0.00, -- Hours online on this date
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(driver_id, date)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_driver_online_hours_driver ON driver_online_hours(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_online_hours_date ON driver_online_hours(date DESC);
CREATE INDEX IF NOT EXISTS idx_driver_online_hours_driver_date ON driver_online_hours(driver_id, date DESC);

-- Enable RLS
ALTER TABLE driver_online_hours ENABLE ROW LEVEL SECURITY;

-- RLS Policies (drop if exists, then create)
DROP POLICY IF EXISTS "Drivers can view their own online hours" ON driver_online_hours;
CREATE POLICY "Drivers can view their own online hours" ON driver_online_hours
  FOR SELECT USING (driver_id = auth.uid());

DROP POLICY IF EXISTS "System can manage online hours" ON driver_online_hours;
CREATE POLICY "System can manage online hours" ON driver_online_hours
  FOR ALL USING (true);

-- =====================================================================================
-- 6. CREATE FUNCTIONS FOR DRIVER WALLET OPERATIONS
-- =====================================================================================

-- Function to initialize wallet for new driver
CREATE OR REPLACE FUNCTION initialize_driver_wallet()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create wallet for drivers
  IF NEW.role = 'driver' THEN
    INSERT INTO driver_wallets (driver_id, balance)
    VALUES (NEW.id, 0.00)
    ON CONFLICT (driver_id) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create wallet when driver registers
DROP TRIGGER IF EXISTS create_driver_wallet_trigger ON users;
CREATE TRIGGER create_driver_wallet_trigger
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_driver_wallet();

-- Function to add earning to driver wallet (after commission deduction)
CREATE OR REPLACE FUNCTION add_driver_earning(
  p_driver_id UUID,
  p_order_id UUID,
  p_amount DECIMAL,
  p_commission DECIMAL,
  p_net_amount DECIMAL
)
RETURNS jsonb AS $$
DECLARE
  v_current_balance DECIMAL(10,2);
  v_new_balance DECIMAL(10,2);
  v_transaction_id UUID;
  v_wallet_enabled TEXT;
BEGIN
  -- Check if driver wallet is enabled
  SELECT value INTO v_wallet_enabled
  FROM system_settings
  WHERE key = 'driver_wallet';
  
  IF v_wallet_enabled != 'enabled' THEN
    -- Wallet disabled, just return success without updating wallet
    RETURN jsonb_build_object(
      'success', true,
      'wallet_disabled', true,
      'message', 'Driver wallet is disabled'
    );
  END IF;
  
  -- Get or create wallet
  SELECT balance INTO v_current_balance
  FROM driver_wallets
  WHERE driver_id = p_driver_id;
  
  IF v_current_balance IS NULL THEN
    INSERT INTO driver_wallets (driver_id, balance)
    VALUES (p_driver_id, 0.00)
    RETURNING balance INTO v_current_balance;
  END IF;
  
  -- Calculate new balance (add net amount after commission)
  v_new_balance := v_current_balance + p_net_amount;
  
  -- Update wallet balance
  UPDATE driver_wallets
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE driver_id = p_driver_id;
  
  -- Record transaction
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
    'earning',
    p_net_amount,
    v_current_balance,
    v_new_balance,
    p_order_id,
    'أرباح من طلب #' || substring(p_order_id::text, 1, 8) || ' (عمولة: ' || p_commission || ' IQD)'
  ) RETURNING id INTO v_transaction_id;
  
  -- Return result
  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'balance_before', v_current_balance,
    'balance_after', v_new_balance,
    'net_amount', p_net_amount,
    'commission', p_commission
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 7. UPDATE EARNINGS CALCULATION TO USE RANK-BASED COMMISSION
-- =====================================================================================

-- Function to get commission percentage based on driver rank
CREATE OR REPLACE FUNCTION get_driver_commission_percentage(p_driver_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  v_rank TEXT;
  v_commission_percentage DECIMAL;
BEGIN
  -- Get driver rank
  SELECT rank INTO v_rank
  FROM users
  WHERE id = p_driver_id AND role = 'driver';
  
  -- Default to bronze if rank is null
  IF v_rank IS NULL THEN
    v_rank := 'bronze';
  END IF;
  
  -- Get commission percentage from settings based on rank
  SELECT value::DECIMAL INTO v_commission_percentage
  FROM system_settings
  WHERE key = CASE v_rank
    WHEN 'trial' THEN 'trial_commission_percentage'
    WHEN 'bronze' THEN 'bronze_commission_percentage'
    WHEN 'silver' THEN 'silver_commission_percentage'
    WHEN 'gold' THEN 'gold_commission_percentage'
    ELSE 'bronze_commission_percentage'
  END;
  
  -- Default based on rank if setting not found
  IF v_commission_percentage IS NULL THEN
    IF v_rank = 'trial' THEN
      v_commission_percentage := 0.0;
    ELSE
      v_commission_percentage := 10.0;
    END IF;
  END IF;
  
  RETURN v_commission_percentage;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update earnings with rank-based commission and add to wallet
CREATE OR REPLACE FUNCTION create_driver_earning_with_rank(
  p_driver_id UUID,
  p_order_id UUID,
  p_delivery_fee DECIMAL
)
RETURNS jsonb AS $$
DECLARE
  v_commission_percentage DECIMAL;
  v_commission DECIMAL;
  v_net_amount DECIMAL;
  v_earning_id UUID;
  v_wallet_result jsonb;
BEGIN
  -- Get commission percentage based on rank
  v_commission_percentage := get_driver_commission_percentage(p_driver_id);
  
  -- Calculate commission and net amount
  v_commission := (p_delivery_fee * v_commission_percentage) / 100.0;
  v_net_amount := p_delivery_fee - v_commission;
  
  -- Create earnings record
  INSERT INTO earnings (driver_id, order_id, amount, commission, net_amount, status)
  VALUES (p_driver_id, p_order_id, p_delivery_fee, v_commission, v_net_amount, 'pending')
  RETURNING id INTO v_earning_id;
  
  -- Add to driver wallet
  v_wallet_result := add_driver_earning(
    p_driver_id,
    p_order_id,
    p_delivery_fee,
    v_commission,
    v_net_amount
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 8. UPDATE ORDER DELIVERY FUNCTION TO USE NEW EARNINGS FUNCTION
-- =====================================================================================

-- Update the existing update_order_status function to use rank-based commission
-- This replaces the earnings creation logic in the existing function
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
  -- Log the attempt
  RAISE NOTICE 'Attempting to update order % to status % by user %', p_order_id, p_new_status, p_user_id;
  
  -- Check if order exists
  SELECT EXISTS(SELECT 1 FROM orders WHERE id = p_order_id) INTO v_order_exists;
  IF NOT v_order_exists THEN
    RAISE NOTICE 'Order % not found', p_order_id;
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_NOT_FOUND',
      'message', 'Order not found'
    );
  END IF;
  
  -- Check if user exists
  SELECT EXISTS(SELECT 1 FROM users WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RAISE NOTICE 'User % not found', p_user_id;
    RETURN json_build_object(
      'success', false,
      'error', 'USER_NOT_FOUND',
      'message', 'User not found'
    );
  END IF;
  
  -- Get order details
  SELECT status, driver_id, merchant_id, delivery_fee
  INTO v_current_status, v_driver_id, v_merchant_id, v_delivery_fee
  FROM orders
  WHERE id = p_order_id;
  
  -- Get user role
  SELECT role INTO v_user_role FROM users WHERE id = p_user_id;
  
  RAISE NOTICE 'Order status: %, Driver: %, Merchant: %, User role: %', 
    v_current_status, v_driver_id, v_merchant_id, v_user_role;
  
  -- Validate status transition
  IF v_current_status IN ('delivered', 'cancelled') THEN
    RAISE NOTICE 'Cannot update completed order with status %', v_current_status;
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_COMPLETED',
      'message', 'Cannot update completed order',
      'current_status', v_current_status
    );
  END IF;
  
  -- Validate permissions for drivers
  IF v_user_role = 'driver' THEN
    IF v_driver_id IS NULL THEN
      RAISE NOTICE 'Order % not assigned to any driver', p_order_id;
      RETURN json_build_object(
        'success', false,
        'error', 'NOT_ASSIGNED',
        'message', 'Order is not assigned to any driver',
        'driver_id', v_driver_id
      );
    END IF;
    
    IF v_driver_id != p_user_id THEN
      RAISE NOTICE 'Order assigned to % but user is %', v_driver_id, p_user_id;
      RETURN json_build_object(
        'success', false,
        'error', 'UNAUTHORIZED',
        'message', 'Order not assigned to this driver',
        'expected_driver', v_driver_id,
        'actual_driver', p_user_id
      );
    END IF;
  END IF;
  
  -- Validate permissions for merchants
  IF v_user_role = 'merchant' AND v_merchant_id != p_user_id THEN
    RAISE NOTICE 'Merchant mismatch: expected %, got %', v_merchant_id, p_user_id;
    RETURN json_build_object(
      'success', false,
      'error', 'UNAUTHORIZED',
      'message', 'Order does not belong to this merchant'
    );
  END IF;
  
  -- Update order status
  UPDATE orders
  SET 
    status = p_new_status,
    updated_at = NOW(),
    picked_up_at = CASE WHEN p_new_status = 'on_the_way' THEN NOW() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE delivered_at END,
    cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN NOW() ELSE cancelled_at END
  WHERE id = p_order_id;
  
  RAISE NOTICE 'Order % updated to status %', p_order_id, p_new_status;
  
  -- Create earnings with rank-based commission when order is delivered
  IF p_new_status = 'delivered' AND v_current_status != 'delivered' AND v_driver_id IS NOT NULL THEN
    PERFORM create_driver_earning_with_rank(
      v_driver_id,
      p_order_id,
      v_delivery_fee
    );
    RAISE NOTICE 'Earnings record created with rank-based commission for driver %', v_driver_id;
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'message', 'Order status updated successfully',
    'old_status', v_current_status,
    'new_status', p_new_status
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error updating order: % %', SQLERRM, SQLSTATE;
    RETURN json_build_object(
      'success', false,
      'error', 'DATABASE_ERROR',
      'message', SQLERRM,
      'detail', SQLSTATE
    );
END;
$$;

-- =====================================================================================
-- 9. FUNCTIONS FOR TRACKING DRIVER ONLINE HOURS
-- =====================================================================================

-- Function to record driver online time
CREATE OR REPLACE FUNCTION record_driver_online_time(
  p_driver_id UUID,
  p_hours DECIMAL
)
RETURNS void AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
BEGIN
  -- Insert or update today's online hours
  INSERT INTO driver_online_hours (driver_id, date, hours_online, updated_at)
  VALUES (p_driver_id, v_today, p_hours, NOW())
  ON CONFLICT (driver_id, date)
  DO UPDATE SET
    hours_online = driver_online_hours.hours_online + p_hours,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get driver online hours for current month
CREATE OR REPLACE FUNCTION get_driver_monthly_online_hours(p_driver_id UUID, p_month DATE DEFAULT NULL)
RETURNS DECIMAL AS $$
DECLARE
  v_start_date DATE;
  v_end_date DATE;
  v_total_hours DECIMAL;
BEGIN
  -- Use provided month or current month
  IF p_month IS NULL THEN
    p_month := CURRENT_DATE;
  END IF;
  
  -- Calculate month start and end
  v_start_date := DATE_TRUNC('month', p_month)::DATE;
  v_end_date := (DATE_TRUNC('month', p_month) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
  
  -- Sum hours for the month
  SELECT COALESCE(SUM(hours_online), 0) INTO v_total_hours
  FROM driver_online_hours
  WHERE driver_id = p_driver_id
    AND date >= v_start_date
    AND date <= v_end_date;
  
  RETURN COALESCE(v_total_hours, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get driver orders delivered for current month
CREATE OR REPLACE FUNCTION get_driver_monthly_orders_delivered(p_driver_id UUID, p_month DATE DEFAULT NULL)
RETURNS INTEGER AS $$
DECLARE
  v_start_date DATE;
  v_end_date DATE;
  v_total_orders INTEGER;
BEGIN
  -- Use provided month or current month
  IF p_month IS NULL THEN
    p_month := CURRENT_DATE;
  END IF;
  
  -- Calculate month start and end
  v_start_date := DATE_TRUNC('month', p_month)::DATE;
  v_end_date := (DATE_TRUNC('month', p_month) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
  
  -- Count delivered orders for the month
  SELECT COUNT(*) INTO v_total_orders
  FROM orders
  WHERE driver_id = p_driver_id
    AND status = 'delivered'
    AND delivered_at >= v_start_date
    AND delivered_at < v_end_date + INTERVAL '1 day';
  
  RETURN COALESCE(v_total_orders, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 10. FUNCTION TO UPDATE DRIVER RANK BASED ON CRITERIA
-- =====================================================================================

CREATE OR REPLACE FUNCTION update_driver_rank(p_driver_id UUID)
RETURNS jsonb AS $$
DECLARE
  v_current_rank TEXT;
  v_monthly_hours DECIMAL;
  v_monthly_orders INTEGER;
  v_new_rank TEXT;
  v_rank_changed BOOLEAN := FALSE;
  v_driver_created_at TIMESTAMPTZ;
  v_months_since_registration INTEGER;
BEGIN
  -- Get current rank and registration date
  SELECT rank, created_at INTO v_current_rank, v_driver_created_at
  FROM users
  WHERE id = p_driver_id AND role = 'driver';
  
  IF v_current_rank IS NULL THEN
    RETURN jsonb_build_object('error', 'Driver not found');
  END IF;
  
  -- Default to trial if null (for new drivers)
  IF v_current_rank IS NULL THEN
    v_current_rank := 'trial';
  END IF;
  
  -- Calculate months since registration
  v_months_since_registration := EXTRACT(EPOCH FROM (NOW() - v_driver_created_at)) / (30 * 24 * 3600);
  
  -- If driver is on trial and it's been more than 1 month, convert to bronze
  IF v_current_rank = 'trial' AND v_months_since_registration >= 1 THEN
    v_new_rank := 'bronze';
  ELSE
    -- Get monthly stats
    v_monthly_hours := get_driver_monthly_online_hours(p_driver_id);
    v_monthly_orders := get_driver_monthly_orders_delivered(p_driver_id);
    
    -- Determine new rank based on criteria
    -- Gold: 240+ hours OR (high order count can be added later)
    IF v_monthly_hours >= 240 THEN
      v_new_rank := 'gold';
    -- Silver: 150+ hours
    ELSIF v_monthly_hours >= 150 THEN
      v_new_rank := 'silver';
    -- Bronze: default (or keep trial if still in first month)
    ELSIF v_current_rank = 'trial' THEN
      v_new_rank := 'trial'; -- Keep trial if still in first month
    ELSE
      v_new_rank := 'bronze';
    END IF;
  END IF;
  
  -- Update rank if changed
  IF v_new_rank != v_current_rank THEN
    UPDATE users
    SET rank = v_new_rank,
        updated_at = NOW()
    WHERE id = p_driver_id;
    
    v_rank_changed := TRUE;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'current_rank', v_current_rank,
    'new_rank', v_new_rank,
    'rank_changed', v_rank_changed,
    'monthly_hours', v_monthly_hours,
    'monthly_orders', v_monthly_orders,
    'silver_threshold', 150,
    'gold_threshold', 240,
    'is_trial', v_current_rank = 'trial'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 11. FUNCTION TO RESET RANKS MONTHLY (TO BE CALLED VIA CRON OR MANUALLY)
-- =====================================================================================

CREATE OR REPLACE FUNCTION reset_driver_ranks_monthly()
RETURNS jsonb AS $$
DECLARE
  v_drivers_updated INTEGER := 0;
  v_trial_converted INTEGER := 0;
BEGIN
  -- Convert trial drivers to bronze if they've been registered for more than 1 month
  UPDATE users
  SET rank = 'bronze',
      updated_at = NOW()
  WHERE role = 'driver'
    AND rank = 'trial'
    AND created_at < NOW() - INTERVAL '1 month';
  
  GET DIAGNOSTICS v_trial_converted = ROW_COUNT;
  
  -- Reset all other driver ranks (silver, gold) to bronze at start of new month
  -- This ensures ranks are recalculated fresh each month
  -- (but keep trial drivers who are still in their first month)
  UPDATE users
  SET rank = 'bronze',
      updated_at = NOW()
  WHERE role = 'driver'
    AND rank IN ('silver', 'gold');
  
  GET DIAGNOSTICS v_drivers_updated = ROW_COUNT;
  
  RETURN jsonb_build_object(
    'success', true,
    'trial_converted', v_trial_converted,
    'drivers_reset', v_drivers_updated,
    'message', 'Trial drivers converted to bronze, other ranks reset for new month'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 12. TRIGGER TO UPDATE ONLINE HOURS WHEN DRIVER GOES ONLINE/OFFLINE
-- =====================================================================================

-- Function to track online time when driver status changes
CREATE OR REPLACE FUNCTION track_driver_online_status()
RETURNS TRIGGER AS $$
DECLARE
  v_current_time TIMESTAMPTZ := NOW();
  v_last_seen TIMESTAMPTZ;
  v_hours_online DECIMAL;
BEGIN
  -- Only process for drivers
  IF NEW.role != 'driver' THEN
    RETURN NEW;
  END IF;
  
  -- When driver goes offline, calculate hours online since last seen
  IF OLD.is_online = TRUE AND NEW.is_online = FALSE THEN
    -- Get last seen time or use updated_at
    v_last_seen := COALESCE(OLD.last_seen_at, OLD.updated_at, NOW() - INTERVAL '1 hour');
    
    -- Calculate hours online (minimum 0.01 hours to avoid zero)
    v_hours_online := GREATEST(
      EXTRACT(EPOCH FROM (v_current_time - v_last_seen)) / 3600.0,
      0.01
    );
    
    -- Record online hours
    PERFORM record_driver_online_time(NEW.id, v_hours_online);
    
    -- Update last_seen_at
    NEW.last_seen_at := v_current_time;
  END IF;
  
  -- When driver goes online, update last_seen_at
  IF NEW.is_online = TRUE THEN
    NEW.last_seen_at := v_current_time;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS track_driver_online_status_trigger ON users;
CREATE TRIGGER track_driver_online_status_trigger
  BEFORE UPDATE ON users
  FOR EACH ROW
  WHEN (OLD.is_online IS DISTINCT FROM NEW.is_online)
  EXECUTE FUNCTION track_driver_online_status();

-- =====================================================================================
-- 13. UPDATE TRIGGER FOR UPDATED_AT ON DRIVER_WALLETS
-- =====================================================================================

CREATE OR REPLACE FUNCTION update_driver_wallets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_driver_wallets_updated_at_trigger ON driver_wallets;
CREATE TRIGGER update_driver_wallets_updated_at_trigger
  BEFORE UPDATE ON driver_wallets
  FOR EACH ROW
  EXECUTE FUNCTION update_driver_wallets_updated_at();

-- =====================================================================================
-- 14. GRANT PERMISSIONS
-- =====================================================================================

-- Grant select on driver_wallets to authenticated users (for their own wallet)
GRANT SELECT ON driver_wallets TO authenticated;
GRANT SELECT ON driver_wallet_transactions TO authenticated;
GRANT SELECT ON driver_online_hours TO authenticated;

-- =====================================================================================
-- DONE! Driver rank and wallet system is ready
-- =====================================================================================

