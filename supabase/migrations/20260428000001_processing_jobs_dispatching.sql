-- Adds 'dispatching' to the status CHECK constraint and adds updated_at column.
--
-- The dispatching status is used by the CPU poller to atomically claim a job
-- before spawning the GPU worker. This prevents double-dispatch if two poller
-- instances run simultaneously.
--
-- Status lifecycle after this migration:
--   queued → dispatching → processing → done
--                ↓               ↓
--              failed           failed
--
-- Constraint name note: the original CHECK was defined inline (no explicit name),
-- so PostgreSQL auto-named it processing_jobs_status_check ({table}_{column}_check).

-- 1. Replace CHECK constraint to include 'dispatching'
ALTER TABLE public.processing_jobs
    DROP CONSTRAINT IF EXISTS processing_jobs_status_check;

ALTER TABLE public.processing_jobs
    ADD CONSTRAINT processing_jobs_status_check
    CHECK (status IN ('queued', 'dispatching', 'processing', 'done', 'failed'));

-- 2. Add updated_at column for stuck-job cleanup.
--    The CPU poller resets jobs stuck in 'dispatching' for >10 min back to 'queued'.
--    Existing rows get the default (now()), which is safe.
ALTER TABLE public.processing_jobs
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- 3. Auto-update updated_at on every row update
CREATE OR REPLACE FUNCTION _update_processing_jobs_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_processing_jobs_updated_at ON public.processing_jobs;
CREATE TRIGGER trg_processing_jobs_updated_at
    BEFORE UPDATE ON public.processing_jobs
    FOR EACH ROW EXECUTE FUNCTION _update_processing_jobs_updated_at();

-- 4. Keep the existing poller index (status + created_at for FIFO queued ordering).
--    Add a partial index for the stuck-dispatching cleanup query.
CREATE INDEX IF NOT EXISTS idx_processing_jobs_dispatching
    ON public.processing_jobs (updated_at ASC)
    WHERE status = 'dispatching';
