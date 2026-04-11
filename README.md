# Padel Stats

AI-powered padel match analytics using just an iPhone camera. Place your phone in the back corner of any court, record a match, and automatically receive player heatmaps, distance stats, and rally analysis. No club infrastructure required.

> **Sprint 0 in progress** — Flutter app and Supabase backend are complete. CV backend is scaffolded (stubs only); real video processing begins in Sprint 2. See [ROADMAP.md](ROADMAP.md) for the full sprint plan.

## Features (live)

- **Authentication** — Email/password sign-up and login via Supabase Auth
- **Match Recording** — Log singles and doubles matches with set-by-set scores, opponent names, location, surface, and match type
- **ELO Rating System** — Automatic rating calculation after each match with score margin adjustments
- **Rating History** — Line chart showing your rating progression over time
- **Match Filtering** — Filter match history by result, match type, court surface, and date range
- **Stats Dashboard** — Win rate, serve trends, shot distribution, performance by surface and match type
- **Profile Management** — Edit display name, preferred position, handedness, and level
- **Localization** — English and Spanish

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.x (Dart) |
| State Management | Riverpod 2.x |
| Navigation | GoRouter |
| Charts | fl_chart |
| App Backend | Supabase (PostgreSQL, Auth, RLS, Storage) |
| CV Backend | Python, FastAPI, Modal (serverless GPU) |
| Player Tracking | YOLO11l + DeepOCSORT + OSNet (Sprint 2+) |
| i18n | Flutter intl / ARB files |

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- A Supabase project with all migrations applied (see Database Setup below)

### Run the Flutter app

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
4. `supabase/migrations/20260411000001_processing_jobs.sql` — Async CV job queue table
5. `supabase/migrations/20260411000002_match_analyses.sql` — CV analysis results table

## Project Structure

```
lib/                        Flutter app
├── core/                   Theme, router, network, shared widgets
├── features/
│   ├── auth/               Login, register, profile setup
│   ├── match/              Match CRUD, history, filtering
│   ├── rating/             ELO calculator, rating history, chart
│   ├── statistics/         Stats dashboard, aggregation, charts
│   └── player_profile/     Profile view and edit
└── l10n/                   English + Spanish localizations

cv_backend/                 Python FastAPI CV server (cloud GPU)
├── pipeline/
│   ├── analyze_match.py    Provider-agnostic interface (the only CV contract)
│   ├── player_tracker.py   YOLO11l + DeepOCSORT (Sprint 2)
│   ├── ball_tracker.py     TrackNetV4 (Sprint 5+)
│   └── court_detector.py   Homography detection (Sprint 2)
├── api/
│   ├── main.py             FastAPI app (POST /analyze, GET /analyze/{id})
│   ├── models.py           Pydantic request/response models
│   └── job_queue.py        Supabase poller — picks up queued jobs every 30s
└── infra/
    ├── modal_runner.py     Modal (current GPU provider)
    └── runpod_runner.py    RunPod (future, >50 users)

supabase/migrations/        SQL migrations (apply in order)
```

Each Flutter feature follows clean architecture: `data/` (repositories), `domain/` (models, services), `presentation/` (screens, widgets, providers).

## CV Backend

The CV backend runs on a cloud GPU (Modal, serverless A10G) and processes match videos asynchronously. The Flutter app uploads a video, inserts a row in `processing_jobs`, and polls until the result appears in `match_analyses`.

**Key design constraint:** `analyze_match()` in `cv_backend/pipeline/analyze_match.py` is the only contract between the CV pipeline and the infrastructure. It takes a local file path and returns an `AnalysisResult` dataclass. It knows nothing about Modal, queues, or HTTP. Switching GPU providers means rewriting only `infra/modal_runner.py`.

### Run locally (Sprint 0 stub — no GPU required)

```bash
cp .env.example .env   # fill in SUPABASE_URL and SUPABASE_SERVICE_KEY
uv sync
uv run uvicorn cv_backend.api.main:app --reload
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full sprint plan. Short version:

- [x] Sprint 0 — Foundation: Flutter app, Supabase schema, CV backend scaffold
- [ ] Sprint 1 — Record & Upload: in-app recording, on-device compression, upload pipeline
- [ ] Sprint 2 — Analysis Pipeline: real YOLO tracking, court homography, results to Supabase
- [ ] Sprint 3 — Results UI: heatmaps, distance stats, processing states
- [ ] Sprint 4 — Polish & First Real Users: onboarding, GDPR, TestFlight
- [ ] Sprint 5+ — Ball tracking, rally analysis, social features
