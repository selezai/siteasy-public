-- Fix: check_rating_drift() was joining on reviews.sitter_id which doesn't exist.
-- The correct column is reviews.reviewee_id (the person being reviewed).

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
  LEFT JOIN public.reviews r ON r.reviewee_id = sp.user_id
  GROUP BY sp.user_id, sp.rating_average, sp.rating_count
  HAVING sp.rating_count != COUNT(r.id)::INT
     OR ABS(sp.rating_average - COALESCE(ROUND(AVG(r.rating)::NUMERIC, 2), 0)) > 0.01;
END;
$$;
