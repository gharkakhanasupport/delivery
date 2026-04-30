-- =======================================================
-- MIGRATION SCRIPT: Clean Slate Factory Reset & Test Agent Setup
-- WARNING: This script PERMANENTLY DELETES all delivery project data.
-- =======================================================

-- 1. [OPTIONAL] Clear Auth Users
-- ONLY uncomment the line below if you want to delete ALL users from your 
-- Supabase project. Warning: This affects Admin and Customer apps too!
-- DELETE FROM auth.users;

-- 2. Clear All Delivery Data (Ordered to respect dependencies)
-- We use a TRUNCATE and DELETE approach to ensure a clean slate
DELETE FROM public.withdrawal_requests;
DELETE FROM public.wallet_transactions;
DELETE FROM public.agent_earnings;
DELETE FROM public.agent_wallets;
DELETE FROM public.order_status_history;
DELETE FROM public.location_history;
DELETE FROM public.agent_locations;
DELETE FROM public.delivery_orders;
DELETE FROM public.vehicle_details;
DELETE FROM public.kyc_documents;
DELETE FROM public.delivery_profiles;
-- NOTE: 'notifications' table was skipped as it does not exist in this project yet.


-- 3. Setup Test Agent (UID: 620482d2-b6e0-40fd-a44b-90dac64b2d98)
DO $$ 
DECLARE
  test_agent_id UUID := '620482d2-b6e0-40fd-a44b-90dac64b2d98';
BEGIN

  -- 3.1 Insert Main Profile
  INSERT INTO public.delivery_profiles (
    id, 
    full_name, 
    email, 
    phone_number, 
    current_address, 
    verification_status, 
    is_active, 
    total_earnings, 
    rating,
    profile_photo_url
  ) VALUES (
    test_agent_id, 
    'Test Agent Bob', 
    'test@gkk.delivery', 
    '+919876543210', 
    '123 Test Street, New Delhi', 
    'verified', 
    TRUE,
    250.00,
    5.0,
    'https://ui-avatars.com/api/?name=Test+Agent&background=10b981&color=fff'
  );

  -- 3.2 Insert Vehicle Details
  INSERT INTO public.vehicle_details (
    user_id, 
    vehicle_type, 
    vehicle_number
  ) VALUES (
    test_agent_id,
    'twoWheeler',
    'DL-01-AB-1234'
  );

  -- 3.3 Insert KYC Documents
  INSERT INTO public.kyc_documents (user_id, document_type, document_number, is_verified)
  VALUES 
    (test_agent_id, 'aadhar', '123456789012', TRUE),
    (test_agent_id, 'pan', 'ABCDE1234F', TRUE);

  -- 3.4 Initialize Wallet Profile
  INSERT INTO public.agent_wallets (agent_id, total_earnings, earnings_today, cash_on_hand, total_withdrawn)
  VALUES (test_agent_id, 250.00, 0.00, 0.00, 0.00);


  -- 3.5 Add a Welcome Transaction
  INSERT INTO public.wallet_transactions (
    agent_id, 
    amount, 
    type, 
    category, 
    description
  ) VALUES (
    test_agent_id,
    250.00,
    'credit',
    'bonus',
    'Welcome bonus for testing!'
  );

  -- 4. Set Backdoor Password for test@gkk.delivery
  -- This allows the app to perform a 'hidden' password login instead of sending an OTP
  -- Note: We use the UID provided by you
  -- We use EXECUTE for extension creation to avoid issues in some environments
  EXECUTE 'CREATE EXTENSION IF NOT EXISTS pgcrypto';
  
  UPDATE auth.users 
  SET encrypted_password = crypt('testing_password_123', gen_salt('bf')),
      email_confirmed_at = NOW(),
      updated_at = NOW(),
      is_sso_user = false
  WHERE id = test_agent_id;

END $$;


