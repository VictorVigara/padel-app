-- Make player and match fields nullable to support draft/recording matches
ALTER TABLE public.matches 
  ALTER COLUMN match_type DROP NOT NULL,
  ALTER COLUMN match_format DROP NOT NULL,
  ALTER COLUMN team1_player1_id DROP NOT NULL,
  ALTER COLUMN team2_player1_id DROP NOT NULL;

-- Add status state machine for match lifecycle
ALTER TABLE public.matches 
  ADD COLUMN status TEXT NOT NULL DEFAULT 'draft'
  CHECK (status IN ('draft', 'recording', 'processing', 'completed'));

-- Backfill existing completed matches
UPDATE public.matches 
SET status = 'completed' 
WHERE is_completed = true;