-- Simplified signup trigger that handles errors gracefully
-- This version will not fail the signup even if profile creation has issues

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Try to insert profile with minimal required fields
    -- Use ON CONFLICT to handle any duplicate key issues
    INSERT INTO profiles (id, email, role)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'client'::user_role)
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        role = COALESCE(profiles.role, EXCLUDED.role);
    
    RETURN NEW;
EXCEPTION
    WHEN others THEN
        -- Log the error but DO NOT fail the signup
        RAISE WARNING 'Error in handle_new_user for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
