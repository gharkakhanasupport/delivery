-- ============================================================
-- GKK UNIFIED WALLET: DELIVERY AGENT MODULE
-- Run in Delivery DB (uinictqyoycnwrnggznz) SQL Editor
-- ============================================================

-- 1. AGENT WALLETS — Real-time balance tracking with COD
CREATE TABLE IF NOT EXISTS agent_wallets (
  agent_id UUID PRIMARY KEY,                -- = auth.uid()
  earnings_today NUMERIC(12, 2) DEFAULT 0.00,
  cash_on_hand NUMERIC(12, 2) DEFAULT 0.00, -- Tracks COD money agent has collected
  total_earnings NUMERIC(12, 2) DEFAULT 0.00,
  total_withdrawn NUMERIC(12, 2) DEFAULT 0.00,
  last_settled_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE agent_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "agents_own_wallet" ON agent_wallets
  FOR ALL USING (agent_id = auth.uid());

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE agent_wallets;

-- 2. RPC: process_delivery_earnings (atomic — prevents double-credit)
CREATE OR REPLACE FUNCTION process_delivery_earnings(
  p_agent_id UUID,
  p_order_id UUID,
  p_delivery_fee NUMERIC,
  p_is_cod BOOLEAN DEFAULT FALSE,
  p_cod_amount NUMERIC DEFAULT 0
)
RETURNS void AS $$
BEGIN
  -- Prevent double processing
  IF EXISTS (
    SELECT 1 FROM wallet_transactions 
    WHERE agent_id = p_agent_id AND order_id = p_order_id AND category = 'delivery_pay'
  ) THEN
    RAISE NOTICE 'Earnings already processed for order %', p_order_id;
    RETURN;
  END IF;

  -- 1. Credit delivery fee to wallet_transactions ledger
  INSERT INTO wallet_transactions (agent_id, amount, type, category, description, order_id, reference_id)
  VALUES (p_agent_id, p_delivery_fee, 'credit', 'delivery_pay', 'Delivery completed', p_order_id, p_order_id::TEXT);

  -- 2. If COD: record cash collection (agent now holds cash)
  IF p_is_cod AND p_cod_amount > 0 THEN
    INSERT INTO wallet_transactions (agent_id, amount, type, category, description, order_id, reference_id)
    VALUES (p_agent_id, p_cod_amount, 'debit', 'cod_collection', 'COD cash collected from customer', p_order_id, p_order_id::TEXT);
  END IF;

  -- 3. Update agent_wallets (upsert)
  INSERT INTO agent_wallets (agent_id, earnings_today, cash_on_hand, total_earnings)
  VALUES (
    p_agent_id,
    p_delivery_fee,
    CASE WHEN p_is_cod THEN p_cod_amount ELSE 0 END,
    p_delivery_fee
  )
  ON CONFLICT (agent_id) DO UPDATE SET
    earnings_today = agent_wallets.earnings_today + p_delivery_fee,
    cash_on_hand = agent_wallets.cash_on_hand + CASE WHEN p_is_cod THEN p_cod_amount ELSE 0 END,
    total_earnings = agent_wallets.total_earnings + p_delivery_fee,
    updated_at = NOW();

  -- 4. Also update legacy agent_earnings table
  INSERT INTO agent_earnings (agent_id, order_id, amount, earning_type)
  VALUES (p_agent_id, p_order_id, p_delivery_fee, 'delivery');

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RPC: settle_cod_cash (Admin calls this when agent hands over cash)
CREATE OR REPLACE FUNCTION settle_cod_cash(
  p_agent_id UUID,
  p_amount NUMERIC,
  p_reference TEXT DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  -- Record settlement in ledger
  INSERT INTO wallet_transactions (agent_id, amount, type, category, description, reference_id)
  VALUES (p_agent_id, p_amount, 'credit', 'cod_settlement', 'COD cash settled with admin', p_reference);

  -- Reduce cash_on_hand
  UPDATE agent_wallets
  SET cash_on_hand = GREATEST(cash_on_hand - p_amount, 0),
      last_settled_at = NOW(),
      updated_at = NOW()
  WHERE agent_id = p_agent_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC: reset_daily_earnings (cron job or admin trigger)
CREATE OR REPLACE FUNCTION reset_daily_earnings()
RETURNS void AS $$
BEGIN
  UPDATE agent_wallets SET earnings_today = 0, updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: get_agent_wallet (convenience function)
CREATE OR REPLACE FUNCTION get_agent_wallet(p_agent_id UUID)
RETURNS TABLE (
  balance NUMERIC,
  earnings_today NUMERIC,
  cash_on_hand NUMERIC,
  total_earnings NUMERIC,
  total_withdrawn NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(
      (SELECT SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END) 
       FROM wallet_transactions WHERE agent_id = p_agent_id), 0
    ) AS balance,
    COALESCE(aw.earnings_today, 0) AS earnings_today,
    COALESCE(aw.cash_on_hand, 0) AS cash_on_hand,
    COALESCE(aw.total_earnings, 0) AS total_earnings,
    COALESCE(aw.total_withdrawn, 0) AS total_withdrawn
  FROM agent_wallets aw
  WHERE aw.agent_id = p_agent_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DONE!
