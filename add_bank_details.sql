-- Add bank details to delivery_profiles for withdrawal setup
ALTER TABLE delivery_profiles
ADD COLUMN IF NOT EXISTS bank_name TEXT,
ADD COLUMN IF NOT EXISTS account_number TEXT,
ADD COLUMN IF NOT EXISTS ifsc_code TEXT,
ADD COLUMN IF NOT EXISTS upi_id TEXT;

-- update the withdrawal_requests table to use these as defaults if needed
COMMENT ON COLUMN delivery_profiles.bank_name IS 'Primary bank for withdrawals';
