-- ============================================================
-- GKK DELIVERY AGENT DATABASE SCHEMA v2
-- Target: Delivery Supabase (uinictqyoycnwrnggznz)
-- Run this in Supabase Dashboard > SQL Editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. DELIVERY PROFILES — Agent profile & verification
--    PK = auth.uid() so app code can do .eq('id', userId)
-- ============================================================
CREATE TABLE IF NOT EXISTS delivery_profiles (
  id UUID PRIMARY KEY,                     -- = auth.uid()
  full_name TEXT NOT NULL DEFAULT '',
  email TEXT,
  phone_number TEXT,
  age INTEGER DEFAULT 0,
  gender TEXT DEFAULT 'male',
  current_address TEXT,
  state TEXT,
  city TEXT,
  profile_photo_url TEXT,
  -- Status
  verification_status TEXT DEFAULT 'pending', -- pending, underReview, verified, rejected
  is_active BOOLEAN DEFAULT TRUE,
  -- Financial
  total_earnings DOUBLE PRECISION DEFAULT 0,
  total_deliveries INTEGER DEFAULT 0,
  rating DOUBLE PRECISION DEFAULT 5.0,
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. KYC_DOCUMENTS — ID verification documents
-- ============================================================
CREATE TABLE IF NOT EXISTS kyc_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES delivery_profiles(id),
  document_type TEXT NOT NULL DEFAULT 'aadhar',  -- aadhar, pan
  document_number TEXT,
  document_image_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, document_type)
);

-- ============================================================
-- 3. VEHICLE_DETAILS — Agent vehicle information
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicle_details (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES delivery_profiles(id),
  vehicle_type TEXT DEFAULT 'cycle',       -- cycle, twoWheeler, others
  engine_type TEXT,                         -- electric, nonElectric
  vehicle_number TEXT,
  vehicle_make TEXT,
  driving_license_url TEXT,
  vehicle_photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. AGENT_LOCATIONS — Live GPS tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_locations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID UNIQUE NOT NULL,        -- = auth.uid()
  latitude DOUBLE PRECISION DEFAULT 0,
  longitude DOUBLE PRECISION DEFAULT 0,
  heading DOUBLE PRECISION DEFAULT 0,
  speed DOUBLE PRECISION DEFAULT 0,
  accuracy DOUBLE PRECISION,
  is_online BOOLEAN DEFAULT FALSE,
  last_order_id UUID,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. DELIVERY_ORDERS — Synced orders from User/Kitchen DB
-- ============================================================
CREATE TABLE IF NOT EXISTS delivery_orders (
  id UUID PRIMARY KEY,                   -- Same ID as User DB orders.id
  order_number TEXT,
  source_db TEXT DEFAULT 'user',
  source_order_id UUID,
  -- Kitchen / Restaurant info
  kitchen_id TEXT,
  kitchen_name TEXT,
  kitchen_phone TEXT,
  kitchen_location TEXT,
  pickup_address JSONB DEFAULT '{}',
  -- Customer info
  user_id TEXT,
  user_name TEXT,
  user_phone TEXT,
  delivery_address JSONB DEFAULT '{}',
  delivery_address_text TEXT,
  delivery_instructions TEXT,
  -- Order contents
  items JSONB DEFAULT '[]',
  -- Financials
  total_amount DOUBLE PRECISION DEFAULT 0,
  delivery_fee DOUBLE PRECISION DEFAULT 0,
  agent_earnings DOUBLE PRECISION DEFAULT 25,
  payment_method TEXT DEFAULT 'online',
  -- Distance & time estimates
  estimated_distance_km DOUBLE PRECISION DEFAULT 0,
  estimated_time_minutes INTEGER DEFAULT 0,
  -- Assignment
  delivery_partner_id UUID,
  -- Status tracking
  status TEXT DEFAULT 'pending',
  current_location JSONB,
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  ready_at TIMESTAMPTZ,
  assigned_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_synced_at TIMESTAMPTZ,
  last_synced_from TEXT
);

CREATE INDEX IF NOT EXISTS idx_delivery_orders_status ON delivery_orders(status);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_partner ON delivery_orders(delivery_partner_id);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_created ON delivery_orders(created_at DESC);

-- ============================================================
-- 6. ORDER_STATUS_HISTORY — Audit trail
-- ============================================================
CREATE TABLE IF NOT EXISTS order_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL,
  previous_status TEXT,
  new_status TEXT NOT NULL,
  changed_by UUID,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_status_history_order ON order_status_history(order_id);

-- ============================================================
-- 7. LOCATION_HISTORY — Breadcrumb trail during deliveries
-- ============================================================
CREATE TABLE IF NOT EXISTS location_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partner_id UUID NOT NULL,
  order_id UUID,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  heading DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_location_history_partner ON location_history(partner_id, created_at DESC);

-- ============================================================
-- 8. WALLET_TRANSACTIONS — Agent earnings ledger
-- ============================================================
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL,
  amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  type TEXT NOT NULL DEFAULT 'credit',
  category TEXT NOT NULL DEFAULT 'delivery_pay',
  description TEXT,
  reference_id TEXT,
  order_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_agent ON wallet_transactions(agent_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_category ON wallet_transactions(agent_id, category);

-- ============================================================
-- 9. AGENT_EARNINGS — Legacy / simplified earnings per delivery
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_earnings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL,
  order_id UUID,
  amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  earning_type TEXT DEFAULT 'delivery',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_earnings_agent ON agent_earnings(agent_id, created_at DESC);

-- ============================================================
-- 10. WITHDRAWAL_REQUESTS — Payout requests
-- ============================================================
CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  bank_details JSONB DEFAULT '{}',
  status TEXT DEFAULT 'pending',
  processed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_agent ON withdrawal_requests(agent_id);

-- ============================================================
-- 11. RPC: get_agent_balance
-- ============================================================
CREATE OR REPLACE FUNCTION get_agent_balance(p_agent_id UUID)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  v_balance DOUBLE PRECISION;
BEGIN
  SELECT COALESCE(
    SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END),
    0
  ) INTO v_balance
  FROM wallet_transactions
  WHERE agent_id = p_agent_id;
  
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 12. RPC: check_agent_status (used by login flow)
-- ============================================================
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

-- ============================================================
-- 13. TRIGGER: Auto-create delivery_profiles on signup
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO delivery_profiles (id, email, full_name, created_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists, then create
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 14. ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE delivery_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- delivery_profiles
CREATE POLICY "agents_own_profile" ON delivery_profiles
  FOR ALL USING (id = auth.uid());

-- kyc_documents
CREATE POLICY "agents_own_kyc" ON kyc_documents
  FOR ALL USING (user_id = auth.uid());

-- vehicle_details
CREATE POLICY "agents_own_vehicle" ON vehicle_details
  FOR ALL USING (user_id = auth.uid());

-- agent_locations
CREATE POLICY "agents_own_location" ON agent_locations
  FOR ALL USING (agent_id = auth.uid());

-- delivery_orders: see available + own assigned
CREATE POLICY "agents_see_available_orders" ON delivery_orders
  FOR SELECT USING (
    delivery_partner_id IS NULL 
    OR delivery_partner_id = auth.uid()
  );

CREATE POLICY "agents_update_own_orders" ON delivery_orders
  FOR UPDATE USING (
    delivery_partner_id = auth.uid() 
    OR delivery_partner_id IS NULL
  );

-- Allow inserts for order sync (service role will do this)
CREATE POLICY "service_insert_orders" ON delivery_orders
  FOR INSERT WITH CHECK (true);

-- order_status_history
CREATE POLICY "agents_own_status_history" ON order_status_history
  FOR ALL USING (changed_by = auth.uid());

-- location_history
CREATE POLICY "agents_own_location_history" ON location_history
  FOR ALL USING (partner_id = auth.uid());

-- wallet_transactions
CREATE POLICY "agents_own_transactions" ON wallet_transactions
  FOR SELECT USING (agent_id = auth.uid());

-- agent_earnings
CREATE POLICY "agents_own_earnings" ON agent_earnings
  FOR SELECT USING (agent_id = auth.uid());

-- withdrawal_requests
CREATE POLICY "agents_own_withdrawals" ON withdrawal_requests
  FOR ALL USING (agent_id = auth.uid());

-- ============================================================
-- 15. REALTIME — Enable on key tables
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE delivery_orders;
ALTER PUBLICATION supabase_realtime ADD TABLE agent_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE wallet_transactions;

-- ============================================================
-- 16. AUTO-TIMESTAMP TRIGGERS
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_delivery_orders_updated_at
  BEFORE UPDATE ON delivery_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_delivery_profiles_updated_at
  BEFORE UPDATE ON delivery_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_agent_locations_updated_at
  BEFORE UPDATE ON agent_locations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 17. STORAGE BUCKETS (run separately if needed)
-- ============================================================
-- INSERT INTO storage.buckets (id, name, public) VALUES ('profile_photos', 'profile_photos', true) ON CONFLICT DO NOTHING;
-- INSERT INTO storage.buckets (id, name, public) VALUES ('kyc_documents', 'kyc_documents', false) ON CONFLICT DO NOTHING;
-- INSERT INTO storage.buckets (id, name, public) VALUES ('vehicle_documents', 'vehicle_documents', false) ON CONFLICT DO NOTHING;

-- ============================================================
-- DONE! Schema v2 is ready for the GKK Delivery Agent App.
-- ============================================================
