-- Batch operations for cron jobs and profile updates
-- Reduces N+1 queries to single bulk operations for better performance and atomicity

-- ============================================================================
-- 1. Batch: Transition confirmed → in_progress + release 50% payout
-- ============================================================================
DROP FUNCTION IF EXISTS batch_start_bookings(DATE, INT);
CREATE OR REPLACE FUNCTION batch_start_bookings(p_today DATE, p_batch_limit INT DEFAULT 20)
RETURNS TABLE(
  booking_id UUID,
  client_id UUID,
  sitter_id UUID,
  start_date DATE,
  end_date DATE,
  sitter_payout INTEGER,
  release_amount INTEGER
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Create temp table of bookings to process
  CREATE TEMP TABLE _bookings_to_start ON COMMIT DROP AS
    SELECT b.id, b.client_id, b.sitter_id, b.start_date, b.end_date,
           b.sitter_payout, b.amount_released_to_sitter,
           FLOOR(b.sitter_payout / 2)::INTEGER AS release_amt
    FROM bookings b
    WHERE b.status = 'confirmed'
      AND b.payment_status = 'in_escrow'
      AND b.start_date <= p_today
    LIMIT p_batch_limit;

  -- Transition all to in_progress
  UPDATE bookings b
  SET status = 'in_progress'
  FROM _bookings_to_start t
  WHERE b.id = t.id;

  -- Insert payout_releases (skip duplicates via ON CONFLICT)
  INSERT INTO payout_releases (booking_id, release_type, amount, recipient_id, recipient_type, release_percentage, notes)
  SELECT t.id, 'booking_started'::escrow_release_type, t.release_amt, t.sitter_id, 'sitter', 50,
         '50% released when booking started'
  FROM _bookings_to_start t
  WHERE t.sitter_payout > 0
  ON CONFLICT (booking_id, release_type) DO NOTHING;

  -- Insert payment_transactions for successful payout_releases
  INSERT INTO payment_transactions (booking_id, transaction_type, amount, is_dummy, status, description)
  SELECT t.id, 'sitter_payout', t.release_amt, TRUE, 'completed', '50% payout - booking started'
  FROM _bookings_to_start t
  WHERE t.sitter_payout > 0;

  -- Update payment_status to partially_released
  UPDATE bookings b
  SET payment_status = 'partially_released',
      amount_released_to_sitter = COALESCE(b.amount_released_to_sitter, 0) + t.release_amt
  FROM _bookings_to_start t
  WHERE b.id = t.id
    AND t.sitter_payout > 0;

  -- Return processed bookings for notification generation
  RETURN QUERY
    SELECT t.id, t.client_id, t.sitter_id, t.start_date, t.end_date, t.sitter_payout, t.release_amt
    FROM _bookings_to_start t;
END;
$$;

-- ============================================================================
-- 2. Batch: Recover stuck in_progress bookings (status changed but payout not released)
-- ============================================================================
DROP FUNCTION IF EXISTS batch_recover_stuck_started(DATE, INT);
CREATE OR REPLACE FUNCTION batch_recover_stuck_started(p_today DATE, p_batch_limit INT DEFAULT 20)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  recovered INT := 0;
BEGIN
  CREATE TEMP TABLE _stuck_started ON COMMIT DROP AS
    SELECT b.id, b.sitter_id, b.sitter_payout, b.amount_released_to_sitter,
           FLOOR(b.sitter_payout / 2)::INTEGER AS release_amt
    FROM bookings b
    WHERE b.status = 'in_progress'
      AND b.payment_status = 'in_escrow'
      AND b.start_date <= p_today
      AND b.sitter_payout > 0
    LIMIT p_batch_limit;

  GET DIAGNOSTICS recovered = ROW_COUNT;

  IF recovered = 0 THEN
    RETURN 0;
  END IF;

  INSERT INTO payout_releases (booking_id, release_type, amount, recipient_id, recipient_type, release_percentage, notes)
  SELECT t.id, 'booking_started'::escrow_release_type, t.release_amt, t.sitter_id, 'sitter', 50,
         '50% released - recovery'
  FROM _stuck_started t
  ON CONFLICT (booking_id, release_type) DO NOTHING;

  INSERT INTO payment_transactions (booking_id, transaction_type, amount, is_dummy, status, description)
  SELECT t.id, 'sitter_payout', t.release_amt, TRUE, 'completed', '50% payout - booking started (recovered)'
  FROM _stuck_started t;

  UPDATE bookings b
  SET payment_status = 'partially_released',
      amount_released_to_sitter = COALESCE(b.amount_released_to_sitter, 0) + t.release_amt
  FROM _stuck_started t
  WHERE b.id = t.id;

  RETURN recovered;
END;
$$;

-- ============================================================================
-- 3. Batch: Transition in_progress → completed + release remaining 50%
-- ============================================================================
DROP FUNCTION IF EXISTS batch_complete_bookings(DATE, TIMESTAMPTZ, INT);
CREATE OR REPLACE FUNCTION batch_complete_bookings(p_today DATE, p_now TIMESTAMPTZ, p_batch_limit INT DEFAULT 20)
RETURNS TABLE(
  booking_id UUID,
  client_id UUID,
  sitter_id UUID,
  start_date DATE,
  end_date DATE,
  sitter_payout INTEGER,
  release_amount INTEGER
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  CREATE TEMP TABLE _bookings_to_complete ON COMMIT DROP AS
    SELECT b.id, b.client_id, b.sitter_id, b.start_date, b.end_date,
           b.sitter_payout, b.amount_released_to_sitter,
           (b.sitter_payout - COALESCE(b.amount_released_to_sitter, 0))::INTEGER AS release_amt
    FROM bookings b
    WHERE b.status = 'in_progress'
      AND b.payment_status = 'partially_released'
      AND b.end_date < p_today
    LIMIT p_batch_limit;

  -- Transition all to completed
  UPDATE bookings b
  SET status = 'completed',
      completed_at = p_now
  FROM _bookings_to_complete t
  WHERE b.id = t.id;

  -- Insert payout_releases (skip duplicates)
  INSERT INTO payout_releases (booking_id, release_type, amount, recipient_id, recipient_type, release_percentage, notes)
  SELECT t.id, 'booking_completed'::escrow_release_type, t.release_amt, t.sitter_id, 'sitter', 50,
         'Remaining 50% released when booking completed'
  FROM _bookings_to_complete t
  WHERE t.release_amt > 0
  ON CONFLICT (booking_id, release_type) DO NOTHING;

  -- Insert payment_transactions
  INSERT INTO payment_transactions (booking_id, transaction_type, amount, is_dummy, status, description)
  SELECT t.id, 'sitter_payout', t.release_amt, TRUE, 'completed', 'Final 50% payout - booking completed'
  FROM _bookings_to_complete t
  WHERE t.release_amt > 0;

  -- Update payment_status to fully_released
  UPDATE bookings b
  SET payment_status = 'fully_released',
      amount_released_to_sitter = t.sitter_payout,
      payout_completed_at = p_now
  FROM _bookings_to_complete t
  WHERE b.id = t.id
    AND t.release_amt > 0;

  RETURN QUERY
    SELECT t.id, t.client_id, t.sitter_id, t.start_date, t.end_date, t.sitter_payout, t.release_amt
    FROM _bookings_to_complete t;
END;
$$;

-- ============================================================================
-- 4. Batch: Recover stuck completed bookings (status changed but final payout not released)
-- ============================================================================
DROP FUNCTION IF EXISTS batch_recover_stuck_completed(DATE, TIMESTAMPTZ, INT);
CREATE OR REPLACE FUNCTION batch_recover_stuck_completed(p_today DATE, p_now TIMESTAMPTZ, p_batch_limit INT DEFAULT 20)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  recovered INT := 0;
BEGIN
  CREATE TEMP TABLE _stuck_completed ON COMMIT DROP AS
    SELECT b.id, b.sitter_id, b.sitter_payout, b.amount_released_to_sitter,
           (b.sitter_payout - COALESCE(b.amount_released_to_sitter, 0))::INTEGER AS release_amt
    FROM bookings b
    WHERE b.status = 'completed'
      AND b.payment_status = 'partially_released'
      AND b.end_date < p_today
      AND b.sitter_payout > 0
    LIMIT p_batch_limit;

  GET DIAGNOSTICS recovered = ROW_COUNT;

  IF recovered = 0 THEN
    RETURN 0;
  END IF;

  INSERT INTO payout_releases (booking_id, release_type, amount, recipient_id, recipient_type, release_percentage, notes)
  SELECT t.id, 'booking_completed'::escrow_release_type, t.release_amt, t.sitter_id, 'sitter', 50,
         'Remaining 50% released - recovery'
  FROM _stuck_completed t
  WHERE t.release_amt > 0
  ON CONFLICT (booking_id, release_type) DO NOTHING;

  INSERT INTO payment_transactions (booking_id, transaction_type, amount, is_dummy, status, description)
  SELECT t.id, 'sitter_payout', t.release_amt, TRUE, 'completed', 'Final 50% payout - completed (recovered)'
  FROM _stuck_completed t
  WHERE t.release_amt > 0;

  UPDATE bookings b
  SET payment_status = 'fully_released',
      amount_released_to_sitter = t.sitter_payout,
      payout_completed_at = p_now
  FROM _stuck_completed t
  WHERE b.id = t.id;

  RETURN recovered;
END;
$$;

-- ============================================================================
-- 5. Batch: Auto-cancel stale meet & greets (72+ hours)
-- ============================================================================
DROP FUNCTION IF EXISTS batch_auto_cancel_meet_greets(TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION batch_auto_cancel_meet_greets(p_now TIMESTAMPTZ)
RETURNS TABLE(
  meet_greet_id UUID,
  booking_id UUID,
  client_id UUID,
  sitter_id UUID,
  start_date DATE,
  end_date DATE
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  CREATE TEMP TABLE _to_cancel ON COMMIT DROP AS
    SELECT mg.id AS mg_id, b.id AS b_id, b.client_id, b.sitter_id, b.start_date, b.end_date
    FROM meet_greets mg
    JOIN bookings b ON b.id = mg.booking_id
    WHERE mg.status = 'proposed'
      AND mg.proposed_time < (p_now - INTERVAL '72 hours')
      AND b.status != 'cancelled';

  -- Cancel bookings
  UPDATE bookings b
  SET status = 'cancelled',
      cancelled_at = p_now,
      cancellation_reason = 'Auto-cancelled: Meet & greet not confirmed within 72 hours'
  FROM _to_cancel t
  WHERE b.id = t.b_id;

  -- Cancel meet & greets
  UPDATE meet_greets mg
  SET status = 'cancelled',
      auto_cancelled_at = p_now
  FROM _to_cancel t
  WHERE mg.id = t.mg_id;

  RETURN QUERY
    SELECT t.mg_id, t.b_id, t.client_id, t.sitter_id, t.start_date, t.end_date
    FROM _to_cancel t;
END;
$$;

-- ============================================================================
-- 6. Batch: Send 48h meet & greet warnings
-- ============================================================================
DROP FUNCTION IF EXISTS batch_meet_greet_48h_warnings(TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION batch_meet_greet_48h_warnings(p_now TIMESTAMPTZ)
RETURNS TABLE(
  meet_greet_id UUID,
  booking_id UUID,
  client_id UUID,
  sitter_id UUID
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  CREATE TEMP TABLE _48h_warnings ON COMMIT DROP AS
    SELECT mg.id AS mg_id, b.id AS b_id, b.client_id, b.sitter_id
    FROM meet_greets mg
    JOIN bookings b ON b.id = mg.booking_id
    WHERE mg.status = 'proposed'
      AND mg.proposed_time < (p_now - INTERVAL '48 hours')
      AND mg.proposed_time >= (p_now - INTERVAL '72 hours')
      AND mg.reminder_48h_sent_at IS NULL
      AND b.status != 'cancelled';

  UPDATE meet_greets mg
  SET reminder_48h_sent_at = p_now
  FROM _48h_warnings t
  WHERE mg.id = t.mg_id;

  RETURN QUERY
    SELECT t.mg_id, t.b_id, t.client_id, t.sitter_id
    FROM _48h_warnings t;
END;
$$;

-- ============================================================================
-- 7. Batch: Send 24h meet & greet reminders
-- ============================================================================
DROP FUNCTION IF EXISTS batch_meet_greet_24h_reminders(TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION batch_meet_greet_24h_reminders(p_now TIMESTAMPTZ)
RETURNS TABLE(
  meet_greet_id UUID,
  booking_id UUID,
  client_id UUID,
  sitter_id UUID
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  CREATE TEMP TABLE _24h_reminders ON COMMIT DROP AS
    SELECT mg.id AS mg_id, b.id AS b_id, b.client_id, b.sitter_id
    FROM meet_greets mg
    JOIN bookings b ON b.id = mg.booking_id
    WHERE mg.status = 'proposed'
      AND mg.proposed_time < (p_now - INTERVAL '24 hours')
      AND mg.proposed_time >= (p_now - INTERVAL '48 hours')
      AND mg.reminder_24h_sent_at IS NULL
      AND b.status != 'cancelled';

  UPDATE meet_greets mg
  SET reminder_24h_sent_at = p_now
  FROM _24h_reminders t
  WHERE mg.id = t.mg_id;

  RETURN QUERY
    SELECT t.mg_id, t.b_id, t.client_id, t.sitter_id
    FROM _24h_reminders t;
END;
$$;

-- ============================================================================
-- 8. Atomic profile update across multiple tables
-- ============================================================================
DROP FUNCTION IF EXISTS update_profile_batch(UUID, JSONB, JSONB, JSONB);
CREATE OR REPLACE FUNCTION update_profile_batch(
  p_user_id UUID,
  p_profile JSONB DEFAULT NULL,
  p_client JSONB DEFAULT NULL,
  p_sitter JSONB DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  result JSONB := '{"success": true}'::JSONB;
BEGIN
  -- Update profiles table
  IF p_profile IS NOT NULL AND p_profile != '{}'::JSONB THEN
    UPDATE profiles
    SET first_name = COALESCE(p_profile->>'first_name', first_name),
        last_name = COALESCE(p_profile->>'last_name', last_name),
        phone = CASE WHEN p_profile ? 'phone' THEN (p_profile->>'phone') ELSE phone END,
        city = CASE WHEN p_profile ? 'city' THEN (p_profile->>'city') ELSE city END,
        suburb = CASE WHEN p_profile ? 'suburb' THEN (p_profile->>'suburb') ELSE suburb END
    WHERE id = p_user_id;

    IF NOT FOUND THEN
      RETURN '{"success": false, "error": "Profile not found"}'::JSONB;
    END IF;
  END IF;

  -- Update client_profiles table
  IF p_client IS NOT NULL AND p_client != '{}'::JSONB THEN
    UPDATE client_profiles
    SET address = CASE WHEN p_client ? 'address' THEN (p_client->>'address') ELSE address END,
        home_type = CASE WHEN p_client ? 'home_type' THEN (p_client->>'home_type') ELSE home_type END,
        has_garden = CASE WHEN p_client ? 'has_garden' THEN (p_client->>'has_garden')::BOOLEAN ELSE has_garden END,
        has_pool = CASE WHEN p_client ? 'has_pool' THEN (p_client->>'has_pool')::BOOLEAN ELSE has_pool END,
        is_pool_fenced = CASE WHEN p_client ? 'is_pool_fenced' THEN (p_client->>'is_pool_fenced')::BOOLEAN ELSE is_pool_fenced END,
        has_alarm = CASE WHEN p_client ? 'has_alarm' THEN (p_client->>'has_alarm')::BOOLEAN ELSE has_alarm END,
        has_camera_system = CASE WHEN p_client ? 'has_camera_system' THEN (p_client->>'has_camera_system')::BOOLEAN ELSE has_camera_system END,
        has_wifi = CASE WHEN p_client ? 'has_wifi' THEN (p_client->>'has_wifi')::BOOLEAN ELSE has_wifi END,
        special_instructions = CASE WHEN p_client ? 'special_instructions' THEN (p_client->>'special_instructions') ELSE special_instructions END,
        emergency_contact_name = CASE WHEN p_client ? 'emergency_contact_name' THEN (p_client->>'emergency_contact_name') ELSE emergency_contact_name END,
        emergency_contact_phone = CASE WHEN p_client ? 'emergency_contact_phone' THEN (p_client->>'emergency_contact_phone') ELSE emergency_contact_phone END
    WHERE user_id = p_user_id;
  END IF;

  -- Update sitter_profiles table
  IF p_sitter IS NOT NULL AND p_sitter != '{}'::JSONB THEN
    -- Verify sitter profile exists
    IF NOT EXISTS (SELECT 1 FROM sitter_profiles WHERE user_id = p_user_id) THEN
      RETURN '{"success": false, "error": "Sitter profile not found"}'::JSONB;
    END IF;

    UPDATE sitter_profiles
    SET bio = CASE WHEN p_sitter ? 'bio' THEN (p_sitter->>'bio') ELSE bio END,
        services = CASE WHEN p_sitter ? 'services' THEN (SELECT ARRAY(SELECT jsonb_array_elements_text(p_sitter->'services'))) ELSE services END,
        pet_types = CASE WHEN p_sitter ? 'pet_types' THEN (SELECT ARRAY(SELECT jsonb_array_elements_text(p_sitter->'pet_types'))) ELSE pet_types END,
        years_experience = CASE WHEN p_sitter ? 'years_experience' THEN (p_sitter->>'years_experience')::INTEGER ELSE years_experience END,
        has_own_transport = CASE WHEN p_sitter ? 'has_own_transport' THEN (p_sitter->>'has_own_transport')::BOOLEAN ELSE has_own_transport END
    WHERE user_id = p_user_id;
  END IF;

  RETURN result;
END;
$$;

-- Grant execute permissions to service role (cron jobs use service role key)
GRANT EXECUTE ON FUNCTION batch_start_bookings TO service_role;
GRANT EXECUTE ON FUNCTION batch_recover_stuck_started TO service_role;
GRANT EXECUTE ON FUNCTION batch_complete_bookings TO service_role;
GRANT EXECUTE ON FUNCTION batch_recover_stuck_completed TO service_role;
GRANT EXECUTE ON FUNCTION batch_auto_cancel_meet_greets TO service_role;
GRANT EXECUTE ON FUNCTION batch_meet_greet_48h_warnings TO service_role;
GRANT EXECUTE ON FUNCTION batch_meet_greet_24h_reminders TO service_role;
GRANT EXECUTE ON FUNCTION update_profile_batch TO authenticated;

COMMENT ON FUNCTION batch_start_bookings IS 'Bulk transition confirmed→in_progress + release 50% payout';
COMMENT ON FUNCTION batch_recover_stuck_started IS 'Recover bookings stuck in in_progress with unreleased payouts';
COMMENT ON FUNCTION batch_complete_bookings IS 'Bulk transition in_progress→completed + release remaining 50%';
COMMENT ON FUNCTION batch_recover_stuck_completed IS 'Recover completed bookings with unreleased final payouts';
COMMENT ON FUNCTION batch_auto_cancel_meet_greets IS 'Auto-cancel meet & greets not confirmed within 72 hours';
COMMENT ON FUNCTION batch_meet_greet_48h_warnings IS 'Mark 48h warnings as sent for stale meet & greets';
COMMENT ON FUNCTION batch_meet_greet_24h_reminders IS 'Mark 24h reminders as sent for stale meet & greets';
COMMENT ON FUNCTION update_profile_batch IS 'Atomic profile update across profiles, client_profiles, sitter_profiles';
