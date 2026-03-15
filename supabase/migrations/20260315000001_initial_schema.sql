-- Profiles (extends Supabase auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    preferred_position TEXT CHECK (preferred_position IN ('left', 'right', 'both')),
    handedness TEXT CHECK (handedness IN ('left', 'right')),
    level TEXT CHECK (level IN ('beginner', 'intermediate', 'advanced', 'pro')),
    bio TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Player ratings (ELO history)
CREATE TABLE public.ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating NUMERIC(7,2) NOT NULL DEFAULT 1200.00,
    rating_change NUMERIC(6,2) NOT NULL DEFAULT 0.00,
    match_id UUID,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ratings_player_latest ON public.ratings (player_id, calculated_at DESC);

-- Matches
CREATE TABLE public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by UUID NOT NULL REFERENCES public.profiles(id),
    match_date TIMESTAMPTZ NOT NULL,
    location TEXT,
    court_surface TEXT CHECK (court_surface IN ('glass', 'cement', 'turf', 'other')),
    match_type TEXT NOT NULL CHECK (match_type IN ('friendly', 'league', 'tournament')),
    match_format TEXT NOT NULL CHECK (match_format IN ('best_of_3', 'best_of_5', 'single_set')),
    team1_player1_id UUID NOT NULL REFERENCES public.profiles(id),
    team1_player2_id UUID REFERENCES public.profiles(id),
    team2_player1_id UUID NOT NULL REFERENCES public.profiles(id),
    team2_player2_id UUID REFERENCES public.profiles(id),
    winner_team SMALLINT CHECK (winner_team IN (1, 2)),
    is_completed BOOLEAN NOT NULL DEFAULT false,
    set_scores JSONB NOT NULL DEFAULT '[]'::jsonb,
    video_url TEXT,
    league_id UUID,
    tournament_id UUID,
    round TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_matches_created_by ON public.matches (created_by, match_date DESC);

-- Match statistics (per player per match)
CREATE TABLE public.match_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES public.profiles(id),
    first_serve_in INTEGER DEFAULT 0,
    first_serve_total INTEGER DEFAULT 0,
    second_serve_in INTEGER DEFAULT 0,
    second_serve_total INTEGER DEFAULT 0,
    aces INTEGER DEFAULT 0,
    double_faults INTEGER DEFAULT 0,
    winners INTEGER DEFAULT 0,
    unforced_errors INTEGER DEFAULT 0,
    forced_errors INTEGER DEFAULT 0,
    bandeja_winners INTEGER DEFAULT 0,
    vibora_winners INTEGER DEFAULT 0,
    smash_winners INTEGER DEFAULT 0,
    lob_winners INTEGER DEFAULT 0,
    volley_winners INTEGER DEFAULT 0,
    net_points_won INTEGER DEFAULT 0,
    net_points_total INTEGER DEFAULT 0,
    break_points_won INTEGER DEFAULT 0,
    break_points_total INTEGER DEFAULT 0,
    total_points_won INTEGER DEFAULT 0,
    total_points_played INTEGER DEFAULT 0,
    input_source TEXT NOT NULL DEFAULT 'manual'
        CHECK (input_source IN ('manual', 'cvAuto', 'cvReviewed')),
    per_set_stats JSONB,
    shot_positions JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(match_id, player_id)
);

-- Leagues (Phase 2, schema created now for FK readiness)
CREATE TABLE public.leagues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    organizer_id UUID NOT NULL REFERENCES public.profiles(id),
    start_date DATE,
    end_date DATE,
    max_players INTEGER,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'registration', 'active', 'completed')),
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.league_members (
    league_id UUID NOT NULL REFERENCES public.leagues(id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES public.profiles(id),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'banned')),
    PRIMARY KEY (league_id, player_id)
);

-- Add FK from matches to leagues now that leagues table exists
ALTER TABLE public.matches
    ADD CONSTRAINT fk_matches_league
    FOREIGN KEY (league_id) REFERENCES public.leagues(id);

-- Add FK from ratings to matches
ALTER TABLE public.ratings
    ADD CONSTRAINT fk_ratings_match
    FOREIGN KEY (match_id) REFERENCES public.matches(id);

-- Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_members ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read all profiles, update only their own
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles
    FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Matches: users can read matches they're part of, create their own
CREATE POLICY "Users can view matches they participate in" ON public.matches
    FOR SELECT USING (
        auth.uid() IN (team1_player1_id, team1_player2_id, team2_player1_id, team2_player2_id, created_by)
    );
CREATE POLICY "Users can create matches" ON public.matches
    FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Match creator can update" ON public.matches
    FOR UPDATE USING (auth.uid() = created_by);

-- Match stats: viewable by match participants
CREATE POLICY "Stats viewable by match participants" ON public.match_stats
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.id = match_id
            AND auth.uid() IN (m.team1_player1_id, m.team1_player2_id, m.team2_player1_id, m.team2_player2_id, m.created_by)
        )
    );
CREATE POLICY "Match creator can insert stats" ON public.match_stats
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.matches m WHERE m.id = match_id AND auth.uid() = m.created_by
        )
    );

-- Ratings: viewable by everyone
CREATE POLICY "Ratings are viewable by everyone" ON public.ratings
    FOR SELECT USING (true);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email));
    INSERT INTO public.ratings (player_id, rating, rating_change)
    VALUES (NEW.id, 1200.00, 0.00);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
