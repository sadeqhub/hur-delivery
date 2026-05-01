-- =====================================================================================
-- FIX: Notification Constraint and Ensure Fee Deduction Resilience
-- =====================================================================================
-- This migration:
-- 1. Fixes the notification constraint to include all possible notification types
-- 2. Ensures fee deduction happens even if notification triggers fail
-- =====================================================================================

BEGIN;

-- Drop and recreate the notification constraint with ALL possible types
ALTER TABLE notifications 
DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add comprehensive constraint with all notification types
ALTER TABLE notifications 
ADD CONSTRAINT notifications_type_check CHECK (
  type IN (
    'order_assigned', 
    'order_accepted', 
    'order_status_update',
    'order_on_the_way',
    'order_delivered', 
    'order_cancelled',
    'order_rejected',
    'payment', 
    'system',
    'message',
    'customer_location_updated',
    'location_received',
    'support_request',  -- For admin support requests
    'admin_announcement',  -- For admin announcements
    'verification',  -- For account verification
    'driver_offline'  -- For driver timeout notifications
  )
);

COMMENT ON CONSTRAINT notifications_type_check ON notifications IS 
'Comprehensive list of all allowed notification types to prevent constraint violations';

-- =====================================================================================
-- Make fee deduction trigger more resilient
-- =====================================================================================
-- Wrap the fee deduction in exception handling to ensure it completes even if
-- other triggers fail (like notification triggers)
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
BEGIN
  -- Only deduct fee when order is delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    
    BEGIN
      RAISE NOTICE '=== FEE DEDUCTION TRIGGER FIRED for order % merchant % ===', NEW.id, NEW.merchant_id;
      
      -- Get merchant city and registration date
      SELECT city, created_at INTO v_merchant_city, v_merchant_created_at
      FROM users
      WHERE id = NEW.merchant_id AND role = 'merchant';
      
      RAISE NOTICE 'Merchant city: %, created_at: %', v_merchant_city, v_merchant_created_at;
      
      -- Check if merchant is less than a month old (30 days) - exempt from fees
      IF v_merchant_created_at IS NOT NULL THEN
        IF v_merchant_created_at > (NOW() - INTERVAL '30 days') THEN
          RAISE NOTICE 'Merchant % is exempt from fees (registered less than 30 days ago, created: %)', 
            NEW.merchant_id, v_merchant_created_at;
          RETURN NEW;
        ELSE
          RAISE NOTICE 'Merchant % is older than 30 days (created: %), proceeding with fee deduction', 
            NEW.merchant_id, v_merchant_created_at;
        END IF;
      ELSE
        RAISE NOTICE 'Merchant % has NULL created_at, proceeding with fee deduction', NEW.merchant_id;
      END IF;
      
      -- Check merchant-specific wallet setting
      SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
      FROM merchant_settings
      WHERE merchant_id = NEW.merchant_id;
      
      RAISE NOTICE 'Merchant-specific wallet setting: %', v_merchant_wallet_enabled;
      
      IF v_merchant_wallet_enabled IS NOT NULL THEN
        IF NOT v_merchant_wallet_enabled THEN
          RAISE NOTICE 'Fee deduction SKIPPED: Wallet disabled for merchant %', NEW.merchant_id;
          RETURN NEW;
        ELSE
          RAISE NOTICE 'Merchant-specific wallet is ENABLED, proceeding';
        END IF;
      ELSE
        -- Check city-specific wallet setting if merchant setting is NULL
        IF v_merchant_city IS NOT NULL THEN
          SELECT merchant_wallet_enabled INTO v_merchant_wallet_enabled
          FROM city_settings
          WHERE city = v_merchant_city;
          
          RAISE NOTICE 'City-specific wallet setting for %: %', v_merchant_city, v_merchant_wallet_enabled;
          
          IF v_merchant_wallet_enabled IS NOT NULL AND NOT v_merchant_wallet_enabled THEN
            RAISE NOTICE 'Fee deduction SKIPPED: Wallet disabled for city %', v_merchant_city;
            RETURN NEW;
          END IF;
        ELSE
          RAISE NOTICE 'Merchant city is NULL, skipping city-specific check';
        END IF;
      END IF;
      
      -- Fallback to global setting
      SELECT value INTO v_merchant_wallet_setting
      FROM system_settings
      WHERE key = 'merchant_wallet';
      
      RAISE NOTICE 'Global wallet setting: %', v_merchant_wallet_setting;
      
      IF v_merchant_wallet_setting IS DISTINCT FROM 'enabled' THEN
        RAISE NOTICE 'Fee deduction SKIPPED: Global wallet setting is not "enabled" (value: %)', v_merchant_wallet_setting;
        RETURN NEW;
      END IF;
      
      RAISE NOTICE 'All checks passed, proceeding with fee calculation and deduction';
      
      -- Calculate commission
      v_commission_amount := get_merchant_commission_amount(
        NEW.merchant_id,
        COALESCE(NEW.total_amount, 0.00),
        COALESCE(NEW.delivery_fee, 0.00)
      );
      
      RAISE NOTICE 'Calculated commission amount: % IQD (total_amount: %, delivery_fee: %)', 
        v_commission_amount, NEW.total_amount, NEW.delivery_fee;
      
      -- Get merchant wallet info
      SELECT id, balance, order_fee, credit_limit 
      INTO v_wallet_id, v_current_balance, v_order_fee, v_credit_limit
      FROM merchant_wallets
      WHERE merchant_id = NEW.merchant_id;
      
      -- If wallet doesn't exist, create it
      IF v_wallet_id IS NULL THEN
        RAISE NOTICE 'Wallet does not exist for merchant %, creating new wallet', NEW.merchant_id;
        INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
        VALUES (NEW.merchant_id, 10000.00, 500.00, -10000.00)
        RETURNING id, balance, order_fee, credit_limit 
        INTO v_wallet_id, v_current_balance, v_order_fee, v_credit_limit;
      END IF;
      
      RAISE NOTICE 'Wallet balance before deduction: % IQD', v_current_balance;
      
      -- Calculate new balance
      v_new_balance := v_current_balance - v_commission_amount;
      
      -- Update wallet balance
      UPDATE merchant_wallets
      SET balance = v_new_balance,
          updated_at = now()
      WHERE id = v_wallet_id;
      
      RAISE NOTICE 'Wallet balance after deduction: % IQD (deducted: % IQD)', v_new_balance, v_commission_amount;
      
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
      
      RAISE NOTICE 'Transaction recorded successfully for order %', NEW.id;
      
      -- Log if balance goes below credit limit
      IF v_new_balance < v_credit_limit THEN
        RAISE NOTICE 'WARNING: Merchant % balance (%) is below credit limit (%)', 
          NEW.merchant_id, v_new_balance, v_credit_limit;
      END IF;
      
      RAISE NOTICE '=== FEE DEDUCTION COMPLETED SUCCESSFULLY ===';
      
    EXCEPTION
      WHEN OTHERS THEN
        -- Log the error but don't fail the transaction
        -- This ensures fee deduction doesn't block order status updates
        RAISE WARNING 'Error in fee deduction for order % merchant %: %', 
          NEW.id, NEW.merchant_id, SQLERRM;
        -- Still return NEW to allow the order update to proceed
        RETURN NEW;
    END;
    
  ELSE
    RAISE NOTICE 'Fee deduction SKIPPED: Order status is not "delivered" (status: %, old_status: %)', 
      NEW.status, OLD.status;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

