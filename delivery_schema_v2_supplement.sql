-- ============================================================
-- GKK DELIVERY SCHEMA v2 SUPPLEMENT
-- Run this AFTER the v1 schema to add missing tables
-- and fix the auto-profile trigger
-- ============================================================

-- 1. KYC_DOCUMENTS table
CREATE TABLE IF NOT EXISTS kyc_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL,
  document_type TEXT NOT NULL DEFAULT 'aadhar',
  document_number TEXT,
  document_image_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, document_type)
);

ALTER TABLE kyc_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "agents_own_kyc" ON kyc_documents
  FOR ALL USING (user_id = auth.uid());

-- 2. VEHICLE_DETAILS table
CREATE TABLE IF NOT EXISTS vehicle_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE,
  vehicle_type TEXT DEFAULT 'cycle',
  engine_type TEXT,
  vehicle_number TEXT,
  vehicle_make TEXT,
  driving_license_url TEXT,
  vehicle_photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE vehicle_details ENABLE ROW LEVEL SECURITY;
CREATE POLICY "agents_own_vehicle" ON vehicle_details
  FOR ALL USING (user_id = auth.uid());

-- 3. Auto-create profile trigger (uses auth_user_id column)
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO delivery_profiles (auth_user_id, email, full_name, created_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    NOW()
  )
  ON CONFLICT (auth_user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 4. check_agent_status RPC (for login flow)
CREATE OR REPLACE FUNCTION check_agent_status(email_input TEXT)
RETURNS TEXT AS $$
DECLARE
  v_status TEXT;
BEGIN
  SELECT verification_status INTO v_status
  FROM delivery_profiles
  WHERE email = email_input
  LIMIT 1;
  RETURN v_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Allow inserts on delivery_orders for syncing
CREATE POLICY "allow_insert_delivery_orders" ON delivery_orders
  FOR INSERT WITH CHECK (true);

-- 6. Allow inserts on wallet_transactions for earnings recording
CREATE POLICY "allow_insert_wallet_tx" ON wallet_transactions
  FOR INSERT WITH CHECK (agent_id = auth.uid());

-- 7. Allow inserts on agent_earnings  
CREATE POLICY "allow_insert_agent_earnings" ON agent_earnings
  FOR INSERT WITH CHECK (agent_id = auth.uid());

-- 8. Allow inserts on order_status_history
CREATE POLICY "allow_insert_status_history" ON order_status_history
  FOR INSERT WITH CHECK (changed_by = auth.uid());

-- 9. Allow inserts on location_history
CREATE POLICY "allow_insert_location_history" ON location_history
  FOR INSERT WITH CHECK (partner_id = auth.uid());

-- DONE!
