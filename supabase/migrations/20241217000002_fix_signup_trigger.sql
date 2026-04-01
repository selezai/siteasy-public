-- Fix the signup trigger to properly handle user metadata and role

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Recreate with better error handling and role extraction
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    user_role_value user_role;
BEGIN
    -- Extract role from user metadata, default to 'client'
    user_role_value := COALESCE(
        (NEW.raw_user_meta_data->>'role')::user_role,
        'client'::user_role
    );
    
    -- Insert profile
    INSERT INTO profiles (id, email, role)
    VALUES (NEW.id, NEW.email, user_role_value);
    
    RETURN NEW;
EXCEPTION
    WHEN others THEN
        -- Log error but don't fail the signup
        RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
        -- Still try to create a basic profile
        BEGIN
            INSERT INTO profiles (id, email, role)
            VALUES (NEW.id, NEW.email, 'client'::user_role)
            ON CONFLICT (id) DO NOTHING;
        EXCEPTION
            WHEN others THEN
                RAISE WARNING 'Could not create profile: %', SQLERRM;
        END;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
