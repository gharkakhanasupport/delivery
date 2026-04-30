-- =======================================================
-- MIGRATION SCRIPT: Fix Auth Trigger Issue
-- Instructions: Run this in the Supabase SQL Editor.
-- =======================================================

-- This fixes the "Database error creating new user" issue.
-- When we renamed 'phone' to 'phone_number', the old Supabase auth trigger
-- broke because it was still trying to insert into the old 'phone' column.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert into the newly updated schema columns.
  -- We provide NEW.id into both id and auth_user_id just in case 
  -- either is expected as the primary reference to auth.users.
  INSERT INTO public.delivery_profiles (
    id,
    auth_user_id, 
    email, 
    full_name, 
    created_at
  )
  VALUES (
    NEW.id,
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    NOW()
  )
  ON CONFLICT DO NOTHING;
  
  RETURN NEW;
EXCEPTION
  WHEN others THEN
    RAISE LOG 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
