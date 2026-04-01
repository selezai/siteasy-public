-- Heartbeat monitoring table for background processes
-- Each job upserts its timestamp after every run so a health check can detect stale/failed jobs

CREATE TABLE IF NOT EXISTS cron_heartbeats (
  job_name TEXT PRIMARY KEY,
  last_run_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_status TEXT NOT NULL DEFAULT 'success',
  last_result JSONB,
  expected_interval_minutes INT NOT NULL DEFAULT 1440
);

-- Seed rows for existing background processes
INSERT INTO cron_heartbeats (job_name, expected_interval_minutes) VALUES
  ('booking-status', 1440),
  ('meet-greet-reminders', 1440),
  ('paystack-webhook', 10080)
ON CONFLICT (job_name) DO NOTHING;

-- RLS: only service_role can read/write (cron jobs and health endpoint use service_role)
ALTER TABLE cron_heartbeats ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Health check RPC functions (SECURITY DEFINER — called by service_role only)
-- ============================================================================

-- 1. Count auth.users that have no matching profiles row (signup trigger broken)
CREATE OR REPLACE FUNCTION check_orphan_users()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  orphan_count INT;
BEGIN
  SELECT count(*)::INT INTO orphan_count
  FROM auth.users u
  LEFT JOIN public.profiles p ON u.id = p.id
  WHERE p.id IS NULL;
  RETURN orphan_count;
END;
$$;

-- 2. Find sitters whose stored rating_average differs from actual review average
CREATE OR REPLACE FUNCTION check_rating_drift()
RETURNS TABLE(user_id UUID, stored_avg NUMERIC, actual_avg NUMERIC, stored_count INT, actual_count INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.user_id,
    sp.rating_average::NUMERIC AS stored_avg,
    COALESCE(ROUND(AVG(r.rating)::NUMERIC, 2), 0) AS actual_avg,
    sp.rating_count::INT AS stored_count,
    COUNT(r.id)::INT AS actual_count
  FROM public.sitter_profiles sp
  LEFT JOIN public.reviews r ON r.sitter_id = sp.user_id
  GROUP BY sp.user_id, sp.rating_average, sp.rating_count
  HAVING sp.rating_count != COUNT(r.id)::INT
     OR ABS(sp.rating_average - COALESCE(ROUND(AVG(r.rating)::NUMERIC, 2), 0)) > 0.01;
END;
$$;

-- 3. Find sitters whose stored completed_bookings_count differs from actual
CREATE OR REPLACE FUNCTION check_booking_count_drift()
RETURNS TABLE(user_id UUID, stored_count INT, actual_count INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.user_id,
    sp.completed_bookings_count::INT AS stored_count,
    COUNT(b.id)::INT AS actual_count
  FROM public.sitter_profiles sp
  LEFT JOIN public.bookings b ON b.sitter_id = sp.user_id AND b.status = 'completed'
  GROUP BY sp.user_id, sp.completed_bookings_count
  HAVING sp.completed_bookings_count != COUNT(b.id)::INT;
END;
$$;
