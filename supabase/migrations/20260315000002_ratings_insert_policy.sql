-- Allow users to insert their own ratings, or match creators to insert
-- ratings for participants (needed for opponent ELO updates).
CREATE POLICY "Match participants can insert ratings" ON public.ratings
    FOR INSERT WITH CHECK (
        auth.uid() = player_id
        OR EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.id = match_id
            AND auth.uid() = m.created_by
        )
    );

-- Allow match creators to update stats (needed for upsert on edit)
CREATE POLICY "Match creator can update stats" ON public.match_stats
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.id = match_id AND auth.uid() = m.created_by
        )
    );

-- Allow match creators to delete their matches
CREATE POLICY "Match creator can delete" ON public.matches
    FOR DELETE USING (auth.uid() = created_by);
