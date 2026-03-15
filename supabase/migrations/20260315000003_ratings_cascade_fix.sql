-- When a match is deleted, keep the rating record but null out the match reference
ALTER TABLE public.ratings DROP CONSTRAINT fk_ratings_match;
ALTER TABLE public.ratings
    ADD CONSTRAINT fk_ratings_match
    FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE SET NULL;
