-- Make customer_phone optional in orders table
-- This allows merchants to create orders without customer phone numbers
-- Drivers will be prompted to enter the phone number when marking orders as picked up

-- Alter the customer_phone column to allow NULL
ALTER TABLE orders
ALTER COLUMN customer_phone DROP NOT NULL;

-- Add comment explaining the change
COMMENT ON COLUMN orders.customer_phone IS 'Customer phone number. Optional when order is created, but required before driver marks order as picked up.';

