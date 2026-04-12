# Padel Stats

AI-powered padel match analytics using just an iPhone camera. Place your phone in the back corner of any court, record a match, and automatically receive player heatmaps, distance stats, and rally analysis. No club infrastructure required.

> **Sprint 1 complete (2026-04-12)** — In-app recording screen with court detection overlay, on-device compression (~5 Mbps), background upload to Cloudflare R2 (NSURLSession iOS / WorkManager Android), processing job queue insertion, and "Analysing…" badges in match history all done. Starting Sprint 2 — real CV pipeline (YOLO11l + DeepOCSORT). See [ROADMAP.md](ROADMAP.md) for the full sprint plan.

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
- A Cloudflare R2 bucket for video storage (see External Services below)

### Run the Flutter app

```bash
flutter run \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key \
  --dart-define=BACKEND_URL=https://your-modal-endpoint.modal.run \
  --dart-define=CLOUDFLARE_R2_ACCOUNT_ID=your_r2_account_id \
  --dart-define=CLOUDFLARE_R2_BUCKET=padel-match-videos
```

For local backend testing on Android emulator use `BACKEND_URL=http://10.0.2.2:8000`; for iOS simulator use `http://localhost:8000`.

### Database Setup

Run the SQL migrations in order against your Supabase project:

1. `supabase/migrations/20260315000001_initial_schema.sql` — Tables, RLS policies, auto-profile trigger
2. `supabase/migrations/20260315000002_ratings_insert_policy.sql` — Additional RLS policies
3. `supabase/migrations/20260315000003_ratings_cascade_fix.sql` — FK cascade fix
4. `supabase/migrations/20260411000001_processing_jobs.sql` — Async CV job queue table
5. `supabase/migrations/20260411000002_match_analyses.sql` — CV analysis results table

### External Services

| Service | Purpose | Free tier |
|---|---|---|
| [Supabase](https://supabase.com) | Auth, PostgreSQL, Realtime | 500 MB DB, 2 projects |
| [Cloudflare R2](https://developers.cloudflare.com/r2/) | Video storage (400–800 MB per match) | 10 GB storage, no egress fees |
| [Modal](https://modal.com) | Serverless GPU for CV pipeline | $30/month credit |

**Why R2 and not Supabase Storage?** Supabase Storage has a 50 MB file size limit
on the free tier. Match videos are 400–800 MB compressed. R2 has no per-file size
limit and charges no egress fees (important — the CV backend downloads each video).

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
- [x] Sprint 1 — Record & Upload: in-app recording, on-device compression, R2 upload pipeline, analysis badges
- [ ] Sprint 2 — Analysis Pipeline: real YOLO tracking, court homography, results to Supabase
- [ ] Sprint 3 — Results UI: heatmaps, distance stats, processing states
- [ ] Sprint 4 — Polish & First Real Users: onboarding, GDPR, TestFlight
- [ ] Sprint 5+ — Ball tracking, rally analysis, social features
