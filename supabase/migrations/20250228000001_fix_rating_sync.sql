-- Fix rating drift by recalculating rating_average and rating_count from actual reviews
-- This ensures sitter_profiles.rating_average and rating_count match actual review data

UPDATE public.sitter_profiles sp
SET 
  rating_average = COALESCE(
    (SELECT ROUND(AVG(rating)::NUMERIC, 2) 
     FROM public.reviews 
     WHERE reviewee_id = sp.user_id),
    0
  ),
  rating_count = COALESCE(
    (SELECT COUNT(*)::INT 
     FROM public.reviews 
     WHERE reviewee_id = sp.user_id),
    0
  )
WHERE sp.user_id IN (
  SELECT user_id FROM check_rating_drift()
);
