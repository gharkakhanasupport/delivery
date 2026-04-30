-- ================================================================
-- DEBUG & FIX - Disable RLS temporarily and insert test order
-- Run this ENTIRE script in Delivery DB SQL Editor
-- ================================================================

-- STEP 1: Temporarily disable RLS for testing
ALTER TABLE public.delivery_orders DISABLE ROW LEVEL SECURITY;

-- STEP 2: Delete any existing test order and re-insert with correct coordinates
DELETE FROM public.delivery_orders WHERE order_number LIKE 'GKK-TEST%';

-- Plus Code 9C7J+X82 Baruipur = approx 22.3655, 88.4335 (Quality Restaurant)
-- Plus Code 9C9M+R3 Baruipur = approx 22.3715, 88.4385 (User location - Gobindapur)

INSERT INTO public.delivery_orders (
    id,
    order_number,
    user_id,
    user_name,
    user_phone,
    kitchen_id,
    kitchen_name,
    kitchen_phone,
    status,
    pickup_address,
    delivery_address,
    items,
    total_amount,
    delivery_fee,
    agent_earnings,
    estimated_distance_km,
    estimated_time_minutes,
    delivery_instructions,
    created_at,
    ready_at
) VALUES (
    gen_random_uuid(),
    'GKK-TEST-001',
    NULL,
    'Aditya Dey',
    '+91 9876543210',
    gen_random_uuid(),
    'Quality Restaurant',
    '+91 9123456789',
    'ready_for_pickup',
    -- Pickup: Quality Restaurant - 9C7J+X82, Baruipur Station Rd, Subuddhipur
    '{
        "address": "Quality Restaurant, Baruipur Station Rd, Subuddhipur, Baruipur, West Bengal 700144",
        "lat": 22.3655,
        "lng": 88.4335
    }'::jsonb,
    -- Delivery: 9C9M+R3 - Padmapukur, Amtala-Baruipur Rd, Gobindapur
    '{
        "address": "Padmapukur, Amtala - Baruipur Rd, Gobindapur, Madhya Kalyanpur, Baruipur, Kolkata, West Bengal 700144",
        "lat": 22.3715,
        "lng": 88.4385
    }'::jsonb,
    -- Order items
    '[
        {"id": "item-1", "name": "Butter Chicken", "qty": 2, "price": 280},
        {"id": "item-2", "name": "Naan", "qty": 4, "price": 40},
        {"id": "item-3", "name": "Jeera Rice", "qty": 1, "price": 120}
    ]'::jsonb,
    560.00,   -- total_amount
    40.00,    -- delivery_fee
    35.00,    -- agent_earnings
    1.5,      -- estimated_distance_km
    10,       -- estimated_time_minutes
    'Please call when you arrive. Building: Sunrise Apartments',
    NOW() - INTERVAL '20 minutes',
    NOW() - INTERVAL '2 minutes'
);

-- STEP 3: Verify the order was inserted
SELECT 
    id,
    order_number,
    user_name,
    kitchen_name,
    status,
    delivery_partner_id,
    pickup_address->>'address' as pickup,
    delivery_address->>'address' as delivery,
    agent_earnings,
    created_at
FROM public.delivery_orders;

-- STEP 4: Check table count
SELECT 'Total orders in delivery_orders:' as info, COUNT(*) as count FROM public.delivery_orders;

-- NOTE: After testing, re-enable RLS with:
-- ALTER TABLE public.delivery_orders ENABLE ROW LEVEL SECURITY;
