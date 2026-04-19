CREATE TABLE court_calibrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,

    -- Input: 12 keypoints from Flutter (some may be null)
    keypoints JSONB NOT NULL,

    -- Output: 3×3 homography matrix (9 floats, row-major)
    -- Example: [[h11, h12, h13], [h21, h22, h23], [h31, h32, h33]]
    homography_matrix JSONB,

    -- How many non-null keypoints were provided
    keypoints_count INTEGER NOT NULL,

    -- Whether homography computation succeeded
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed')),
    error_message TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(match_id)
);

CREATE INDEX idx_court_calibrations_match_id ON court_calibrations(match_id);
CREATE INDEX idx_court_calibrations_status ON court_calibrations(status);

-- Enable RLS on court_calibrations
ALTER TABLE court_calibrations ENABLE ROW LEVEL SECURITY;

-- No policies needed - only the backend service (using service key) should access this table
-- The service role bypasses RLS, so the backend will continue to work
