-- ================================================================
-- FIX RLS FOR DELIVERY_ORDERS - Allow unassigned orders to be visible
-- Run this in Delivery DB SQL Editor
-- ================================================================

-- First, check if the table exists and has data
SELECT COUNT(*) as order_count FROM public.delivery_orders;

-- Check current RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'delivery_orders';

-- Option 1: Temporarily disable RLS for testing
-- (Comment this out after testing is complete)
-- ALTER TABLE public.delivery_orders DISABLE ROW LEVEL SECURITY;

-- Option 2: Update RLS policies to be more permissive for unassigned orders
-- Drop existing policies
DROP POLICY IF EXISTS "delivery_orders_select" ON public.delivery_orders;
DROP POLICY IF EXISTS "delivery_orders_update" ON public.delivery_orders;
DROP POLICY IF EXISTS "delivery_orders_insert" ON public.delivery_orders;

-- Allow authenticated users to see:
-- 1. Orders assigned to them
-- 2. Unassigned orders that are ready for pickup
CREATE POLICY "delivery_orders_select" ON public.delivery_orders
    FOR SELECT TO authenticated
    USING (
        delivery_partner_id = auth.uid() 
        OR (delivery_partner_id IS NULL AND status = 'ready_for_pickup')
    );

-- Allow authenticated users to update orders they've accepted
CREATE POLICY "delivery_orders_update" ON public.delivery_orders
    FOR UPDATE TO authenticated
    USING (delivery_partner_id = auth.uid() OR delivery_partner_id IS NULL)
    WITH CHECK (delivery_partner_id = auth.uid());

-- Allow service role to insert (for sync functions)
-- Service role bypasses RLS anyway, but this is explicit
CREATE POLICY "delivery_orders_service_insert" ON public.delivery_orders
    FOR INSERT TO service_role
    WITH CHECK (true);

-- Also allow anon role for webhook calls (if using anon key)
CREATE POLICY "delivery_orders_anon_insert" ON public.delivery_orders
    FOR INSERT TO anon
    WITH CHECK (true);

-- Verify policies were created
SELECT policyname, tablename, cmd, qual 
FROM pg_policies 
WHERE tablename = 'delivery_orders';

-- Verify the test order is accessible
SELECT 
    order_number,
    user_name,
    kitchen_name,
    status,
    delivery_partner_id
FROM public.delivery_orders 
WHERE status = 'ready_for_pickup';
