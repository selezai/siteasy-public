-- Update signup trigger to safely handle onboarding_completed column
-- Works whether the column exists or not

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    user_role_value user_role;
    has_onboarding_col BOOLEAN;
BEGIN
    -- Check if onboarding_completed column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'onboarding_completed'
    ) INTO has_onboarding_col;

    -- Extract role from user metadata, default to 'client'
    user_role_value := COALESCE(
        (NEW.raw_user_meta_data->>'role')::user_role,
        'client'::user_role
    );
    
    -- Insert profile with all basic info from metadata
    IF has_onboarding_col THEN
        INSERT INTO profiles (id, email, role, first_name, last_name, phone, city, suburb, onboarding_completed)
        VALUES (
            NEW.id, 
            NEW.email, 
            user_role_value,
            NEW.raw_user_meta_data->>'first_name',
            NEW.raw_user_meta_data->>'last_name',
            NEW.raw_user_meta_data->>'phone',
            NEW.raw_user_meta_data->>'city',
            NEW.raw_user_meta_data->>'suburb',
            FALSE
        );
    ELSE
        INSERT INTO profiles (id, email, role, first_name, last_name, phone, city, suburb)
        VALUES (
            NEW.id, 
            NEW.email, 
            user_role_value,
            NEW.raw_user_meta_data->>'first_name',
            NEW.raw_user_meta_data->>'last_name',
            NEW.raw_user_meta_data->>'phone',
            NEW.raw_user_meta_data->>'city',
            NEW.raw_user_meta_data->>'suburb'
        );
    END IF;
    
    RETURN NEW;
EXCEPTION
    WHEN others THEN
        -- Log error but don't fail the signup
        RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
        -- Still try to create a basic profile
        BEGIN
            IF has_onboarding_col THEN
                INSERT INTO profiles (id, email, role, onboarding_completed)
                VALUES (NEW.id, NEW.email, 'client'::user_role, FALSE)
                ON CONFLICT (id) DO NOTHING;
            ELSE
                INSERT INTO profiles (id, email, role)
                VALUES (NEW.id, NEW.email, 'client'::user_role)
                ON CONFLICT (id) DO NOTHING;
            END IF;
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
