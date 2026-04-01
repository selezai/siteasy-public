-- Fix: "column reference 'booking_id' is ambiguous" in batch RPC functions
-- The RETURNS TABLE output columns collided with INSERT target column names.
-- Solution: prefix all output columns with "out_" to avoid ambiguity.
-- Must DROP first because CREATE OR REPLACE cannot change return type.

DROP FUNCTION IF EXISTS batch_start_bookings(DATE, INT);
DROP FUNCTION IF EXISTS batch_complete_bookings(DATE, TIMESTAMPTZ, INT);
DROP FUNCTION IF EXISTS batch_auto_cancel_meet_greets(TIMESTAMPTZ);
DROP FUNCTION IF EXISTS batch_meet_greet_48h_warnings(TIMESTAMPTZ);
DROP FUNCTION IF EXISTS batch_meet_greet_24h_reminders(TIMESTAMPTZ);

-- ============================================================================
-- 1. batch_start_bookings — fix ambiguous booking_id
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_start_bookings(p_today DATE, p_batch_limit INT DEFAULT 20)
RETURNS TABLE(
  out_booking_id UUID,
  out_client_id UUID,
  out_sitter_id UUID,
  out_start_date DATE,
  out_end_date DATE,
  out_sitter_payout INTEGER,
  out_release_amount INTEGER
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  CREATE TEMP TABLE _bookings_to_start ON COMMIT DROP AS
    SELECT b.id, b.client_id, b.sitter_id, b.start_date, b.end_date,
           b.sitter_payout, b.amount_released_to_sitter,
           FLOOR(b.sitter_payout / 2)::INTEGER AS release_amt
    FROM bookings b
    WHERE b.status = 'confirmed'
      AND b.payment_status = 'in_escrow'
      AND b.start_date <= p_today
    LIMIT p_batch_limit;

  UPDATE bookings b
  SET status = 'in_progress'
  FROM _bookings_to_start t
  WHERE b.id = t.id;

  INSERT INTO payout_releases (booking_id, release_type, amount, recipient_id, recipient_type, release_percentage, notes)
  SELECT t.id, 'booking_started'::escrow_release_type, t.release_amt, t.sitter_id, 'sitter', 50,
         '50% released when booking started'
  FROM _bookings_to_start t
  WHERE t.sitter_payout > 0
  ON CONFLICT (booking_id, release_type) DO NOTHING;

  INSERT INTO payment_transactions (booking_id, transaction_type, amount, is_dummy, status, description)
  SELECT t.id, 'sitter_payout', t.release_amt, TRUE, 'completed', '50% payout - booking started'
  FROM _bookings_to_start t
  WHERE t.sitter_payout > 0;

  UPDATE bookings b
  SET payment_status = 'partially_released',
      amount_released_to_sitter = COALESCE(b.amount_released_to_sitter, 0) + t.release_amt
  FROM _bookings_to_start t
  WHERE b.id = t.id
    AND t.sitter_payout > 0;

  RETURN QUERY
    SELECT t.id, t.client_id, t.sitter_id, t.start_date, t.end_date, t.sitter_payout, t.release_amt
    FROM _bookings_to_start t;
END;
$$;

-- ============================================================================
-- 2. batch_complete_bookings — fix ambiguous booking_id
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_complete_bookings(p_today DATE, p_now TIMESTAMPTZ, p_batch_limit INT DEFAULT 20)
RETURNS TABLE(
  out_booking_id UUID,
  out_client_id UUID,
  out_sitter_id UUID,
  out_start_date DATE,
  out_end_date DATE,
  out_sitter_payout INTEGER,
  out_release_amount INTEGER
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

  UPDATE bookings b
  SET status = 'completed',
      completed_at = p_now
  FROM _bookings_to_complete t
  WHERE b.id = t.id;

  INSERT INTO payout_releases (booking_id, release_type, amount, recipient_id, recipient_type, release_percentage, notes)
  SELECT t.id, 'booking_completed'::escrow_release_type, t.release_amt, t.sitter_id, 'sitter', 50,
         'Remaining 50% released when booking completed'
  FROM _bookings_to_complete t
  WHERE t.release_amt > 0
  ON CONFLICT (booking_id, release_type) DO NOTHING;

  INSERT INTO payment_transactions (booking_id, transaction_type, amount, is_dummy, status, description)
  SELECT t.id, 'sitter_payout', t.release_amt, TRUE, 'completed', 'Final 50% payout - booking completed'
  FROM _bookings_to_complete t
  WHERE t.release_amt > 0;

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
-- 3. batch_auto_cancel_meet_greets — fix ambiguous booking_id/meet_greet_id
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_auto_cancel_meet_greets(p_now TIMESTAMPTZ)
RETURNS TABLE(
  out_meet_greet_id UUID,
  out_booking_id UUID,
  out_client_id UUID,
  out_sitter_id UUID,
  out_start_date DATE,
  out_end_date DATE
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  CREATE TEMP TABLE _to_cancel ON COMMIT DROP AS
    SELECT mg.id AS mg_id, b.id AS b_id, b.client_id, b.sitter_id, b.start_date, b.end_date
    FROM meet_greets mg
    JOIN bookings b ON b.id = mg.booking_id
    WHERE mg.status = 'proposed'
      AND mg.proposed_time < (p_now - INTERVAL '72 hours')
      AND b.status != 'cancelled';

  UPDATE bookings b
  SET status = 'cancelled',
      cancelled_at = p_now,
      cancellation_reason = 'Auto-cancelled: Meet & greet not confirmed within 72 hours'
  FROM _to_cancel t
  WHERE b.id = t.b_id;

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
-- 4. batch_meet_greet_48h_warnings — fix ambiguous columns
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_meet_greet_48h_warnings(p_now TIMESTAMPTZ)
RETURNS TABLE(
  out_meet_greet_id UUID,
  out_booking_id UUID,
  out_client_id UUID,
  out_sitter_id UUID
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
-- 5. batch_meet_greet_24h_reminders — fix ambiguous columns
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_meet_greet_24h_reminders(p_now TIMESTAMPTZ)
RETURNS TABLE(
  out_meet_greet_id UUID,
  out_booking_id UUID,
  out_client_id UUID,
  out_sitter_id UUID
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

-- Re-grant permissions (CREATE OR REPLACE preserves them, but be safe)
GRANT EXECUTE ON FUNCTION batch_start_bookings TO service_role;
GRANT EXECUTE ON FUNCTION batch_complete_bookings TO service_role;
GRANT EXECUTE ON FUNCTION batch_auto_cancel_meet_greets TO service_role;
GRANT EXECUTE ON FUNCTION batch_meet_greet_48h_warnings TO service_role;
GRANT EXECUTE ON FUNCTION batch_meet_greet_24h_reminders TO service_role;
