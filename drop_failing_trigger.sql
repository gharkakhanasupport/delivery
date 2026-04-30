-- =======================================================
-- MIGRATION SCRIPT: Ultimate Trigger Cleanup
-- Instructions: Run this in the Supabase SQL Editor.
-- =======================================================

-- This script finds ANY custom trigger attached to auth.users 
-- that calls a function in the 'public' schema and automatically
-- drops it. It also drops the common functions using CASCADE.

-- 1. Drop the function with CASCADE (this instantly kills any trigger using it, no matter what it was named)
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.create_profile_for_user() CASCADE;

-- 2. Dynamically hunt down and drop ANY other custom triggers on auth.users pointing to the 'public' schema
DO $$ 
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN 
        SELECT t.tgname AS trigger_name
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE t.tgrelid = 'auth.users'::regclass
          AND n.nspname = 'public'
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(trigger_record.trigger_name) || ' ON auth.users';
        RAISE NOTICE 'Dropped custom trigger: %', trigger_record.trigger_name;
    END LOOP;
END $$;

-- 3. Confirm script completion
-- If this runs successfully, nothing in the public schema can block your user creation anymore!
