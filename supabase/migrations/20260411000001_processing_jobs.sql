-- Job queue for async CV processing.
-- Inserted by the Flutter app after video upload; updated by the CV backend.
-- Backend uses SUPABASE_SERVICE_KEY which bypasses RLS — no INSERT/UPDATE policy needed.
CREATE TABLE public.processing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'processing', 'done', 'failed')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- Poller queries: WHERE status='queued' ORDER BY created_at ASC
CREATE INDEX idx_processing_jobs_status ON public.processing_jobs (status, created_at ASC);

ALTER TABLE public.processing_jobs ENABLE ROW LEVEL SECURITY;

-- Flutter app can poll its own job status
CREATE POLICY "Job viewable by match participants" ON public.processing_jobs
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

-- Match creator inserts the job after upload completes (Sprint 1)
CREATE POLICY "Match creator can insert job" ON public.processing_jobs
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.id = match_id AND auth.uid() = m.created_by
        )
    );
