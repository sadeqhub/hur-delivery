-- Update bulk orders to support multiple orders with neighborhood-phone pairs
-- Change from "book driver for day" to "multiple orders" model

-- Add column to store neighborhood items with phone numbers (JSONB)
ALTER TABLE bulk_orders
ADD COLUMN IF NOT EXISTS neighborhood_items JSONB DEFAULT '[]'::jsonb;

-- Update bulk_order_fee default to 1000 IQD (was 1500)
ALTER TABLE bulk_orders
ALTER COLUMN bulk_order_fee SET DEFAULT 1000.00;

-- Update existing bulk orders to have 1000 as fee if they have 1500
UPDATE bulk_orders
SET bulk_order_fee = 1000.00
WHERE bulk_order_fee = 1500.00;

-- Add comment explaining the new structure
COMMENT ON COLUMN bulk_orders.neighborhood_items IS 'Array of neighborhood items with optional customer phone numbers: [{"neighborhood": "name", "customer_phone": "+964..."}]';
COMMENT ON COLUMN bulk_orders.bulk_order_fee IS 'Fixed fee (1000 IQD) deducted from merchant wallet when creating multiple orders';

-- Create function to deduct bulk order fee from merchant wallet
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
    COALESCE(p_notes, 'رسوم طلبات متعددة')
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

COMMENT ON FUNCTION deduct_bulk_order_fee_from_wallet IS 
  'Deducts bulk order fee (1000 IQD) from merchant wallet when creating multiple orders';

