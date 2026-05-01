-- Fix bulk_orders constraints for neighborhood_items
-- The old constraint on neighborhoods TEXT[] array should be updated to check neighborhood_items JSONB

-- First, ensure neighborhood_items column exists (it should be added by 20260204000000_update_bulk_orders_for_multiple_orders.sql)
-- But if it doesn't exist, add it here
ALTER TABLE bulk_orders
ADD COLUMN IF NOT EXISTS neighborhood_items JSONB DEFAULT '[]'::jsonb;

-- Drop the old constraint on neighborhoods array (we're using neighborhood_items now)
ALTER TABLE bulk_orders
DROP CONSTRAINT IF EXISTS bulk_orders_min_neighborhoods;

-- Add constraint to ensure at least 3 neighborhood_items in the JSONB array
-- This replaces the old constraint on neighborhoods TEXT[] array
ALTER TABLE bulk_orders
DROP CONSTRAINT IF EXISTS bulk_orders_min_neighborhood_items;

ALTER TABLE bulk_orders
ADD CONSTRAINT bulk_orders_min_neighborhood_items
CHECK (
  jsonb_array_length(COALESCE(neighborhood_items, '[]'::jsonb)) >= 3
);

-- Also ensure per_delivery_fee is not null (required for multiple orders)
-- Only set NOT NULL if it's currently nullable
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bulk_orders' 
    AND column_name = 'per_delivery_fee'
    AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE bulk_orders
    ALTER COLUMN per_delivery_fee SET NOT NULL;
  END IF;
END $$;

-- Update status constraint to include all valid statuses
-- Status can be: 'draft', 'pending', 'assigned', 'accepted', 'active', 'completed', 'cancelled', 'rejected', 'posting'
ALTER TABLE bulk_orders
DROP CONSTRAINT IF EXISTS bulk_orders_status_check;

ALTER TABLE bulk_orders
ADD CONSTRAINT bulk_orders_status_check
CHECK (
  status IN ('draft', 'pending', 'assigned', 'accepted', 'active', 'completed', 'cancelled', 'rejected', 'posting')
);

-- Update wallet_transactions transaction_type constraint to include 'bulk_order_fee'
ALTER TABLE wallet_transactions
DROP CONSTRAINT IF EXISTS wallet_transactions_transaction_type_check;

ALTER TABLE wallet_transactions
ADD CONSTRAINT wallet_transactions_transaction_type_check
CHECK (
  transaction_type IN ('top_up', 'order_fee', 'refund', 'adjustment', 'initial_gift', 'bulk_order_fee')
);

-- Ensure the deduct_bulk_order_fee_from_wallet function exists
-- This function should be created by 20260204000000_update_bulk_orders_for_multiple_orders.sql
-- But we'll recreate it here to ensure it exists
CREATE OR REPLACE FUNCTION deduct_bulk_order_fee_from_wallet(
  p_merchant_id UUID,
  p_amount DECIMAL(10,2),
  p_bulk_order_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet_id UUID;
  v_current_balance DECIMAL(10,2);
  v_credit_limit DECIMAL(10,2);
  v_new_balance DECIMAL(10,2);
  v_transaction_id UUID;
BEGIN
  -- Get current balance
  SELECT id, balance, credit_limit 
  INTO v_wallet_id, v_current_balance, v_credit_limit
  FROM merchant_wallets
  WHERE merchant_id = p_merchant_id;
  
  -- If wallet doesn't exist, create it
  IF v_wallet_id IS NULL THEN
    INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
    VALUES (p_merchant_id, 10000.00, 500.00, -10000.00)
    RETURNING id, balance, credit_limit 
    INTO v_wallet_id, v_current_balance, v_credit_limit;
  END IF;
  
  -- Check if balance is sufficient
  IF v_current_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INSUFFICIENT_BALANCE',
      'message', 'رصيد غير كافٍ',
      'current_balance', v_current_balance,
      'required_amount', p_amount
    );
  END IF;
  
  -- Calculate new balance
  v_new_balance := v_current_balance - p_amount;
  
  -- Update wallet balance
  UPDATE merchant_wallets
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE id = v_wallet_id;
  
  -- Record transaction
  INSERT INTO wallet_transactions (
    merchant_id,
    transaction_type,
    amount,
    balance_before,
    balance_after,
    notes
  ) VALUES (
    p_merchant_id,
    'bulk_order_fee',
    -p_amount,
    v_current_balance,
    v_new_balance,
    COALESCE(p_notes, 'رسوم طلبات متعددة - ' || substring(p_bulk_order_id::text, 1, 8))
  ) RETURNING id INTO v_transaction_id;
  
  -- Return result
  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'balance_before', v_current_balance,
    'balance_after', v_new_balance,
    'amount', p_amount
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION deduct_bulk_order_fee_from_wallet(UUID, DECIMAL, UUID, TEXT) TO authenticated, anon;

-- Update comment
COMMENT ON FUNCTION deduct_bulk_order_fee_from_wallet IS 
  'Deducts bulk order fee (1000 IQD) from merchant wallet when creating multiple orders';
COMMENT ON CONSTRAINT bulk_orders_min_neighborhood_items ON bulk_orders IS 
  'Ensures at least 3 neighborhood items are provided in the neighborhood_items JSONB array';
COMMENT ON CONSTRAINT bulk_orders_status_check ON bulk_orders IS 
  'Valid statuses: draft, pending, assigned, accepted, active, completed, cancelled, rejected, posting';

