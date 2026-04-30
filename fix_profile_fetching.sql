-- ==============================================================================
-- GKK DELIVERY APP - DATABASE SCHEMA FIX
-- ==============================================================================
-- Run this in Supabase SQL Editor to fix profile fetching issues
-- 
-- Issues fixed:
-- 1. RLS policies for nested SELECT queries
-- 2. Missing indexes for performance
-- 3. Updated trigger to handle all sign-in methods
-- ==============================================================================

-- ==============================================================================
-- 1. FIX RLS POLICIES FOR NESTED SELECTS
-- ==============================================================================

-- The nested SELECT in Supabase requires proper RLS on child tables
-- Ensure user_id matches auth.uid() for all related tables

-- KYC Documents - Fix policy to work with nested selects
DROP POLICY IF EXISTS "Users can view own kyc documents" ON public.kyc_documents;
CREATE POLICY "Users can view own kyc documents" 
ON public.kyc_documents 
FOR SELECT 
USING (user_id = auth.uid());

-- Vehicle Details - Fix policy to work with nested selects  
DROP POLICY IF EXISTS "Users can view own vehicle details" ON public.vehicle_details;
CREATE POLICY "Users can view own vehicle details" 
ON public.vehicle_details 
FOR SELECT 
USING (user_id = auth.uid());

-- Delivery Profiles - Ensure proper policy
DROP POLICY IF EXISTS "Users can view own delivery profile" ON public.delivery_profiles;
CREATE POLICY "Users can view own delivery profile" 
ON public.delivery_profiles 
FOR SELECT 
USING (id = auth.uid());

-- ==============================================================================
-- 2. ADD MISSING INDEXES FOR PERFORMANCE
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_delivery_profiles_email ON public.delivery_profiles(email);
CREATE INDEX IF NOT EXISTS idx_delivery_profiles_verification_status ON public.delivery_profiles(verification_status);
CREATE INDEX IF NOT EXISTS idx_kyc_documents_user_id ON public.kyc_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_details_user_id ON public.vehicle_details(user_id);

-- ==============================================================================
-- 3. FIX TRIGGER FOR ALL SIGN-IN METHODS (Google, Email)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_delivery_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Create/Update google_auth_logins entry
    INSERT INTO public.google_auth_logins (id, email, google_display_name, google_photo_url)
    VALUES (
        new.id, 
        new.email, 
        COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        google_display_name = EXCLUDED.google_display_name,
        google_photo_url = EXCLUDED.google_photo_url,
        last_login_at = now(),
        updated_at = now();

    -- 2. Create/Update delivery_profiles entry
    INSERT INTO public.delivery_profiles (id, email, full_name, profile_photo_url, verification_status)
    VALUES (
        new.id, 
        new.email, 
        COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'avatar_url',
        'pending'
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = COALESCE(public.delivery_profiles.full_name, EXCLUDED.full_name),
        profile_photo_url = COALESCE(public.delivery_profiles.profile_photo_url, EXCLUDED.profile_photo_url),
        updated_at = now();

    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
DROP TRIGGER IF EXISTS on_auth_user_created_delivery ON auth.users;
CREATE TRIGGER on_auth_user_created_delivery
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_delivery_user();

-- ==============================================================================
-- 4. ADD TRIGGER FOR SIGN IN (Update existing users on login)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_delivery_user_signin()
RETURNS TRIGGER AS $$
BEGIN
    -- Update last login time
    UPDATE public.google_auth_logins 
    SET last_login_at = now(), updated_at = now()
    WHERE id = new.id;
    
    -- Ensure delivery profile exists
    INSERT INTO public.delivery_profiles (id, email, full_name, profile_photo_url)
    VALUES (
        new.id, 
        new.email, 
        COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
        new.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on user sign in (update)
DROP TRIGGER IF EXISTS on_auth_user_signin_delivery ON auth.users;
CREATE TRIGGER on_auth_user_signin_delivery
AFTER UPDATE OF last_sign_in_at ON auth.users
FOR EACH ROW 
WHEN (OLD.last_sign_in_at IS DISTINCT FROM NEW.last_sign_in_at)
EXECUTE FUNCTION public.handle_delivery_user_signin();

-- ==============================================================================
-- 5. GRANT EXECUTE PERMISSIONS
-- ==============================================================================

GRANT EXECUTE ON FUNCTION public.check_agent_status(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.check_agent_status(TEXT) TO authenticated;

-- ==============================================================================
-- VERIFICATION QUERY - Run this to check if your profile is accessible
-- ==============================================================================
-- SELECT 
--     dp.*,
--     (SELECT json_agg(k) FROM kyc_documents k WHERE k.user_id = dp.id) as kyc_documents,
--     (SELECT json_agg(v) FROM vehicle_details v WHERE v.user_id = dp.id) as vehicle_details
-- FROM delivery_profiles dp
-- WHERE dp.id = auth.uid();

-- ==============================================================================
-- DONE! Profile fetching should now work correctly.
-- ==============================================================================
