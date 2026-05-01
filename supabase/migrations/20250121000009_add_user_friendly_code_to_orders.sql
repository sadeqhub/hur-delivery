-- =====================================================================================
-- ADD USER FRIENDLY CODE TO ORDERS TABLE
-- =====================================================================================
-- Adds a user_friendly_code field to orders table for sharing with customers/support
-- Code is a unique 6-character alphanumeric string generated automatically on insert
-- =====================================================================================

-- Add user_friendly_code column to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS user_friendly_code TEXT UNIQUE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_orders_user_friendly_code ON orders(user_friendly_code);

-- Function to generate a unique 6-character alphanumeric code
CREATE OR REPLACE FUNCTION generate_user_friendly_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  code TEXT := '';
  i INTEGER;
  char_index INTEGER;
BEGIN
  -- Generate a random 6-character code
  FOR i IN 1..6 LOOP
    char_index := floor(random() * length(chars) + 1)::INTEGER;
    code := code || substr(chars, char_index, 1);
  END LOOP;
  
  -- Check if code already exists, regenerate if it does
  WHILE EXISTS (SELECT 1 FROM orders WHERE user_friendly_code = code) LOOP
    code := '';
    FOR i IN 1..6 LOOP
      char_index := floor(random() * length(chars) + 1)::INTEGER;
      code := code || substr(chars, char_index, 1);
    END LOOP;
  END LOOP;
  
  RETURN code;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to auto-generate code on insert
CREATE OR REPLACE FUNCTION set_user_friendly_code()
RETURNS TRIGGER AS $$
BEGIN
  -- Only generate if code is not already set
  IF NEW.user_friendly_code IS NULL OR NEW.user_friendly_code = '' THEN
    NEW.user_friendly_code := generate_user_friendly_code();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-generate code on insert
DROP TRIGGER IF EXISTS trigger_set_user_friendly_code ON orders;
CREATE TRIGGER trigger_set_user_friendly_code
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION set_user_friendly_code();

-- Backfill existing orders with codes
DO $$
DECLARE
  order_record RECORD;
  new_code TEXT;
BEGIN
  FOR order_record IN SELECT id FROM orders WHERE user_friendly_code IS NULL OR user_friendly_code = '' LOOP
    new_code := generate_user_friendly_code();
    UPDATE orders SET user_friendly_code = new_code WHERE id = order_record.id;
  END LOOP;
END $$;

-- Add comment for documentation
COMMENT ON COLUMN orders.user_friendly_code IS 'User-friendly 6-character alphanumeric code for sharing with customers/support instead of UUID';

