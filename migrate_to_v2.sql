-- =======================================================
-- MIGRATION SCRIPT: Update Live Delivery DB to V2 Schema
-- Instructions: Copy and paste this script into the 
-- Supabase SQL Editor for the Delivery App Project and run it.
-- =======================================================

-- 1. Rename columns in delivery_profiles to match the updated Flutter app model
ALTER TABLE delivery_profiles 
  RENAME COLUMN phone TO phone_number;

ALTER TABLE delivery_profiles 
  RENAME COLUMN avatar_url TO profile_photo_url;

ALTER TABLE delivery_profiles 
  RENAME COLUMN address_line1 TO current_address;

-- Note: The Flutter app has already been refactored to use 'id' instead of 'auth_user_id' 
-- for its primary lookups. 'id' already exists in your table so no column rename is needed there.

-- If you wish to drop the old auth_user_id to clean up (optional but recommended once verified):
-- ALTER TABLE delivery_profiles DROP COLUMN auth_user_id;

-- 2. Ensure constraints and checks match V2 requirements if needed.
-- (The below is optional but aligns with the delivery_schema.sql V2)
-- ALTER TABLE delivery_profiles
--   ADD COLUMN IF NOT EXISTS state TEXT,
--   ADD COLUMN IF NOT EXISTS city TEXT;
