-- =======================================================
-- MIGRATION SCRIPT: Create a Verified Test Delivery Agent
-- Instructions: 
-- 1. Create a user via the Supabase Dashboard -> Authentication -> Add User.
--    Email: test@gkk.delivery
--    Password: testing_password_123
-- 2. Copy the new User's UID from the Dashboard.
-- 3. Replace 'YOUR_NEW_USER_UID_HERE' below with that actual UID.
-- 4. Run this script in the Supabase SQL Editor.
-- =======================================================

DO $$ 
DECLARE
  test_agent_id UUID := '620482d2-b6e0-40fd-a44b-90dac64b2d98'; -- UID PROVIDED BY USER
BEGIN


  -- 1. Ensure the agent exists in delivery_profiles 
  -- (if the auto-trigger didn't create it or you want to upsert)
  INSERT INTO delivery_profiles (
    id, full_name, email, phone_number, current_address, 
    verification_status, is_active, total_earnings, rating
  ) VALUES (
    test_agent_id, 
    'Test Agent Bob', 
    'test@gkk.delivery', 
    '+919876543210', 
    '123 Test Street, New Delhi', 
    'verified', -- ✅ Bypasses the Admin Approval Flow
    TRUE,
    250.00,
    5.0
  )

  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone_number = EXCLUDED.phone_number,
    current_address = EXCLUDED.current_address,
    verification_status = 'verified',
    is_active = TRUE;

  -- 2. Insert dummy vehicle details to ensure all screens load gracefully
  INSERT INTO vehicle_details (user_id, vehicle_type, vehicle_number)
  VALUES (
    test_agent_id,
    'twoWheeler',
    'DL-01-AB-1234'
  )
  ON CONFLICT (user_id) DO NOTHING;

  -- 3. Insert dummy KYC documents (Aadhar & PAN)
  INSERT INTO kyc_documents (user_id, document_type, document_number, is_verified)
  VALUES 
    (test_agent_id, 'aadhar', '123456789012', TRUE),
    (test_agent_id, 'pan', 'ABCDE1234F', TRUE)
  ON CONFLICT (user_id, document_type) DO NOTHING;

  -- 4. Add some starting balance so the wallet screen isn't empty!
  INSERT INTO wallet_transactions (agent_id, amount, type, category, description)
  VALUES (
    test_agent_id,
    250.00,
    'credit',
    'bonus',
    'Welcome bonus for testing!'
  )
  ON CONFLICT DO NOTHING;

END $$;
