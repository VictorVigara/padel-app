-- Stores the CV analysis result for a match.
-- result is JSONB (not typed columns) so the schema never needs a migration
-- when AnalysisResult gains new fields (ball tracking Sprint 5, rally data, etc.).
-- One row per match (UNIQUE constraint). Backend writes via service key.
CREATE TABLE public.match_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'done', 'failed')),
    result JSONB,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processing_started_at TIMESTAMPTZ,
    processing_completed_at TIMESTAMPTZ,
    UNIQUE(match_id)
);

CREATE INDEX idx_match_analyses_match_id ON public.match_analyses (match_id);

ALTER TABLE public.match_analyses ENABLE ROW LEVEL SECURITY;

-- Flutter app can fetch results for matches it participates in
CREATE POLICY "Analysis viewable by match participants" ON public.match_analyses
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.id = match_id
            AND auth.uid() IN (
                m.team1_player1_id, m.team1_player2_id,
                m.team2_player1_id, m.team2_player2_id,
                m.created_by
            )
        )
    );
-- Backend writes via SUPABASE_SERVICE_KEY — no INSERT/UPDATE policy needed from app side
