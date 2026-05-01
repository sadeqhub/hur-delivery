-- =====================================================================================
-- ADD NATIONAL ID VALIDATION REQUIREMENT
-- =====================================================================================
-- This migration adds a constraint that requires id_number to be exactly 12 digits
-- when document_type is 'national_id'. For other document types (driver_license, passport),
-- id_number can be any format or NULL.
-- =====================================================================================

BEGIN;

-- Step 1: Clean existing data - remove non-digit characters from id_number for national_id users
UPDATE users
SET id_number = regexp_replace(id_number, '[^0-9]', '', 'g')
WHERE document_type = 'national_id' 
  AND id_number IS NOT NULL
  AND id_number !~ '^[0-9]{12}$';

-- Step 2: For rows that still don't match (after cleaning), set id_number to NULL
-- This allows the constraint to pass, and they can be updated later
UPDATE users
SET id_number = NULL
WHERE document_type = 'national_id' 
  AND id_number IS NOT NULL
  AND length(regexp_replace(id_number, '[^0-9]', '', 'g')) != 12;

-- Step 3: Drop existing constraint if it exists (in case it was re-added)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_id_number_national_id_format;

-- Step 4: Add conditional constraint: if document_type is 'national_id', id_number must be exactly 12 digits
ALTER TABLE users ADD CONSTRAINT users_id_number_national_id_format 
  CHECK (
    -- If document_type is NULL or not 'national_id', allow any format or NULL
    document_type IS NULL 
    OR document_type != 'national_id' 
    OR id_number IS NULL
    -- If document_type is 'national_id' and id_number is provided, it must be exactly 12 digits
    OR (document_type = 'national_id' AND id_number ~ '^[0-9]{12}$')
  );

-- Update the comment to reflect the new requirement
COMMENT ON COLUMN users.id_number IS 'ID number - must be exactly 12 digits if document_type is national_id, otherwise any format allowed';

-- Update the update_user_id_verification function to validate national ID format
CREATE OR REPLACE FUNCTION update_user_id_verification(
  p_user_id UUID,
  p_id_number TEXT,
  p_legal_first_name TEXT,
  p_legal_father_name TEXT,
  p_legal_grandfather_name TEXT,
  p_legal_family_name TEXT,
  p_id_front_url TEXT,
  p_id_back_url TEXT,
  p_selfie_url TEXT,
  p_id_expiry_date DATE DEFAULT NULL,
  p_id_birth_date DATE DEFAULT NULL,
  p_verification_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_document_type TEXT;
  cleaned_id_number TEXT;
BEGIN
  -- Get the user's document_type
  SELECT document_type INTO v_document_type
  FROM users
  WHERE id = p_user_id;
  
  -- If document_type is 'national_id', validate that id_number is exactly 12 digits
  IF v_document_type = 'national_id' AND p_id_number IS NOT NULL THEN
    -- Remove any non-digit characters for validation
    cleaned_id_number := regexp_replace(p_id_number, '[^0-9]', '', 'g');
    IF length(cleaned_id_number) != 12 THEN
      RAISE EXCEPTION 'رقم الهوية الوطني يجب أن يكون 12 رقمًا بالضبط عندما يكون نوع الوثيقة هو البطاقة الوطنية. الرقم المقدم: %', p_id_number;
    END IF;
    -- Use cleaned version (assign back to parameter)
    p_id_number := cleaned_id_number;
  END IF;
  
  -- Check if ID number is already used by another user
  IF NOT check_id_number_unique(p_id_number, p_user_id) THEN
    RAISE EXCEPTION 'هذا الرقم الوطني مسجل بالفعل في النظام';
  END IF;
  
  -- Update user record
  UPDATE users
  SET 
    id_number = p_id_number,
    legal_first_name = p_legal_first_name,
    legal_father_name = p_legal_father_name,
    legal_grandfather_name = p_legal_grandfather_name,
    legal_family_name = p_legal_family_name,
    id_front_url = p_id_front_url,
    id_back_url = p_id_back_url,
    selfie_url = p_selfie_url,
    id_expiry_date = p_id_expiry_date,
    id_birth_date = p_id_birth_date,
    id_verified_at = NOW(),
    id_verification_notes = p_verification_notes,
    verification_status = 'approved',
    updated_at = NOW()
  WHERE id = p_user_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger function to validate id_number on insert/update
CREATE OR REPLACE FUNCTION validate_national_id_number()
RETURNS TRIGGER AS $$
DECLARE
  cleaned_id_number TEXT;
BEGIN
  -- If document_type is 'national_id' and id_number is provided, validate format
  IF NEW.document_type = 'national_id' AND NEW.id_number IS NOT NULL THEN
    -- Remove any non-digit characters for validation
    cleaned_id_number := regexp_replace(NEW.id_number, '[^0-9]', '', 'g');
    IF length(cleaned_id_number) != 12 THEN
      RAISE EXCEPTION 'رقم الهوية الوطني يجب أن يكون 12 رقمًا بالضبط عندما يكون نوع الوثيقة هو البطاقة الوطنية. الرقم المقدم: %', NEW.id_number;
    END IF;
    -- Use cleaned version
    NEW.id_number := cleaned_id_number;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS validate_national_id_number_trigger ON users;

-- Create trigger
CREATE TRIGGER validate_national_id_number_trigger
  BEFORE INSERT OR UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION validate_national_id_number();

COMMIT;

