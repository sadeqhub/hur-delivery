-- Fix bulk_orders table constraints to allow NULL values
-- This fixes issues with vehicle_type and delivery_fee NOT NULL constraints

-- Allow vehicle_type to be NULL (for "any" vehicle type)
-- Only alter if column exists and has NOT NULL constraint
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bulk_orders' 
    AND column_name = 'vehicle_type'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE bulk_orders
    ALTER COLUMN vehicle_type DROP NOT NULL;
  END IF;
END $$;

-- Update vehicle_type constraint to allow NULL and 'any'
ALTER TABLE bulk_orders DROP CONSTRAINT IF EXISTS bulk_orders_vehicle_type_check;
ALTER TABLE bulk_orders 
  ADD CONSTRAINT bulk_orders_vehicle_type_check 
  CHECK (vehicle_type IS NULL OR vehicle_type IN ('motorcycle', 'car', 'truck', 'motorbike', 'any'));

-- Allow delivery_fee to be NULL (not needed for new multiple orders model)
-- Only alter if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bulk_orders' 
    AND column_name = 'delivery_fee'
  ) THEN
    ALTER TABLE bulk_orders
    ALTER COLUMN delivery_fee DROP NOT NULL;
    
    -- Set default to NULL if not already set
    ALTER TABLE bulk_orders
    ALTER COLUMN delivery_fee SET DEFAULT NULL;
  END IF;
END $$;

-- Update existing NULL vehicle_type values to 'any' for consistency (optional)
-- Don't force update - allow NULL to mean 'any'

-- Add comment
COMMENT ON COLUMN bulk_orders.vehicle_type IS 'Vehicle type required: motorcycle, car, truck, motorbike, or any (NULL = any)';
COMMENT ON COLUMN bulk_orders.delivery_fee IS 'Delivery fee per order (optional, not used in new multiple orders model)';

