# Padel Stats

A cross-platform padel match tracker built with Flutter and Supabase. Record matches, track your ELO rating, and analyze your performance with detailed statistics.

## Features

- **Authentication** — Email/password sign-up and login via Supabase Auth
- **Match Recording** — Log singles and doubles matches with set-by-set scores, opponent names, location, surface, and match type
- **Match Statistics** — Track serves (aces, double faults, first serve %), winners, unforced errors, and padel-specific shots (bandeja, vibora, smash, lob, volley)
- **ELO Rating System** — Automatic rating calculation after each match with score margin adjustments
- **Rating History** — Line chart showing your rating progression over time
- **Match Filtering** — Filter match history by result, match type, court surface, and date range
- **Stats Dashboard** — Overview (win rate, W/L record), serve trends, shot distribution pie chart, and performance breakdown by surface and match type
- **Profile Management** — Edit display name, preferred position, handedness, and level
- **Localization** — English and Spanish

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.x (Dart) |
| State Management | Riverpod 2.x |
| Navigation | GoRouter |
| Charts | fl_chart |
| Backend | Supabase (PostgreSQL, Auth, RLS) |
| i18n | Flutter intl / ARB files |

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- A Supabase project with the migrations applied (see `supabase/migrations/`)

### Run the app

```bash
flutter run \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

### Database Setup

Run the SQL migrations in order against your Supabase project:

1. `supabase/migrations/20260315000001_initial_schema.sql` — Tables, RLS policies, auto-profile trigger
2. `supabase/migrations/20260315000002_ratings_insert_policy.sql` — Additional RLS policies
3. `supabase/migrations/20260315000003_ratings_cascade_fix.sql` — FK cascade fix

## Project Structure

```
lib/
├── core/           # Theme, router, network, shared widgets
├── features/
│   ├── auth/       # Login, register, profile setup
│   ├── match/      # Match CRUD, history, filtering
│   ├── rating/     # ELO calculator, rating history, chart
│   ├── statistics/ # Stats dashboard, aggregation, charts
│   └── player_profile/ # Profile view and edit
└── l10n/           # English + Spanish localizations
```

Each feature follows clean architecture: `data/` (repositories), `domain/` (models, services), `presentation/` (screens, widgets, providers).

## Roadmap

- [x] Phase 1: MVP — Auth, match recording, ELO ratings, stats dashboard
- [ ] Phase 2: Social + Leagues — Head-to-head, league standings, invitations
- [ ] Phase 3: Camera + CV — Record matches, auto-detect stats via computer vision
- [ ] Phase 4: AI Coach — Post-match analysis and training recommendations via Claude API
- [ ] Phase 5: Advanced AI — Real-time overlays, 3D court reconstruction, highlight reels
