# Padel App — Project Context for Claude Code

## What this app is

AI-powered padel match analysis using just an iPhone camera. Player places phone in back corner of padel court (Gimadd-style mount, 1–1.5m height), records a match, and automatically receives player heatmaps, distance stats, and rally analysis. No club infrastructure required — works on any court, anywhere.

**Target platform:** iOS first (iPhone), Android later via Flutter. All CV runs server-side.

## Positioning in one sentence

"Court-installed camera analytics, in your pocket, on any court."

---

## Codebase structure

```
padel_app/                  ← Flutter mobile app
  lib/
    features/
      auth/                 ← Login (Supabase Auth) — COMPLETE
      match/                ← Match history, manual entry — COMPLETE
      player_profile/       ← Player profiles — COMPLETE
      rating/               ← ELO rating system — COMPLETE
      recording/            ← In-app recording — TO BUILD (Sprint 1)
      analysis/             ← Results display — TO BUILD (Sprint 3)

cv_backend/                 ← Python FastAPI server (cloud GPU) — SCAFFOLDED (Sprint 0 ✓)
  pipeline/
    analyze_match.py        ← Core function, provider-agnostic
    player_tracker.py       ← YOLO11l + DeepOCSORT
    ball_tracker.py         ← TrackNetV4
    court_detector.py       ← Homography, already exists
  api/
    main.py                 ← FastAPI app
    models.py               ← Pydantic request/response models
    job_queue.py            ← Supabase-based queue
  infra/
    modal_runner.py         ← Modal wrapper (current)
    runpod_runner.py        ← RunPod wrapper (future)
```

---

## Technology stack

### Mobile (Flutter)
- State management: Riverpod + riverpod_generator
- Navigation: go_router
- Backend: Supabase (auth, DB, storage)
- Charts: fl_chart
- Models: Freezed + json_serializable

### Backend (Python)
- Framework: FastAPI
- Player tracking: YOLO11l + DeepOCSORT (BoxMOT) + OSNet embeddings
- Ball tracking: TrackNetV4 (fine-tuned on padel footage)
- Deployment: Modal (current), RunPod (future) — see Infrastructure section
- Results storage: Supabase (same instance as app)

---

## Architecture

```
iPhone (Flutter)
  └── Record video (locked settings: 1080p, 30fps, fixed exposure)
  └── Compress on-device before upload (~400–800 MB per 90-min match)
  └── Request pre-signed upload URL from backend (or generate client-side)
  └── Upload directly to Cloudflare R2 (S3-compatible, no size limit on free tier)
  └── Insert row in processing_jobs with R2 object URL
  └── Poll or receive push notification for results
  └── Render JSON results (heatmaps, stats)
          │
          ▼
Supabase  (auth + database + realtime only — NOT used for video storage)
  └── Auth (existing)
  └── Database: matches, players, match_analyses, processing_jobs
  └── Realtime / push: notify app when analysis is done
          │
          ▼
Cloudflare R2  (video storage — S3-compatible, no egress fees)
  └── Stores compressed match videos transiently (deleted after processing)
  └── Free tier: 10 GB storage, 1M Class A ops/month — plenty for prototyping
  └── No egress fee: backend downloads video at no cost
          │
          ▼
FastAPI backend (cloud GPU — Modal now, RunPod later)
  └── Polls processing_jobs table for queued jobs
  └── Downloads video from R2 using boto3 (S3-compatible endpoint)
  └── Runs analyze_match() pipeline on local copy
  └── Writes AnalysisResult back to Supabase
  └── Deletes raw video from R2 after success
```

### Job queue (Supabase-based, no Redis needed)

```sql
processing_jobs table:
  id, match_id, video_url, status (queued|processing|done|failed),
  created_at, started_at, completed_at, error_message, retry_count
```

Backend polls every 30s, picks up queued jobs, updates status throughout.
On failure: retry up to 3 times, then mark failed and notify user.

---

## Provider-agnostic CV interface — CRITICAL

The CV pipeline must be completely decoupled from infrastructure.
`analyze_match()` takes a local file path and returns a Python dataclass.
It knows nothing about Modal, RunPod, queues, or HTTP.
Switching providers = rewriting only `infra/modal_runner.py`. Nothing else changes.

```python
# This is the ONLY contract between infrastructure and CV code.
# Never let infrastructure concerns leak into pipeline code.

def analyze_match(video_path: str, config: AnalysisConfig) -> AnalysisResult:
    ...

@dataclass
class AnalysisConfig:
    fps_sample_rate: int = 10     # process every Nth frame (10fps sufficient)
    court_side: str = "auto"      # which end camera is on
    player_count: int = 4         # hard prior — always 4 in padel

@dataclass
class AnalysisResult:
    players: list[PlayerAnalysis]
    processing_meta: ProcessingMeta  # duration, frames processed, warnings

@dataclass
class PlayerAnalysis:
    track_id: str
    total_distance_m: float
    court_coverage_pct: float
    heatmap: list[list[float]]    # 20×10 grid, values 0–1
    positions: list[Position]     # 1 position per second of match

@dataclass
class Position:
    t: float    # seconds from match start
    x: float    # meters from left baseline (court is 10m wide)
    y: float    # meters from sideline (court is 20m long)
```

### REST API contract (Flutter ↔ backend)

```
POST /analyze
  body: { match_id: string, video_url: string }
  returns: { job_id: string, status: "queued" }

GET /analyze/{job_id}
  returns: { status: "queued"|"processing"|"done"|"failed",
             progress_pct?: number,
             results?: AnalysisResult,
             error?: string }
```

---

## CV pipeline details

### Player tracking
- Detector: YOLO11l
- Tracker: DeepOCSORT (via BoxMOT) with OSNet embeddings
- `max_age=600` frames (covers drink breaks at 30fps)
- `min_hits=1` for immediate re-entry after occlusion
- Hard prior: exactly 4 players. Flag states with >4 active tracks or <3 sustained.
- Output: per-player (x, y) in court meters via homography

### Ball tracking (Sprint 5+)
- Model: TrackNetV4 (fine-tuned on padel footage)
- Physics outlier rejection: speed-cone checks, parabolic arc constraints
- Batch parabola fitting per rally segment (full rally available server-side)
- RTS backward smoother at segment boundaries
- Classical CV (MOG2, blob filter, CHT) as lightweight pre-filter

### Court detection
- Already implemented
- Run once at start of video to compute homography matrix
- Also used pre-match in app to validate camera angle ("looks good ✓")

---

## iPhone recording requirements (Sprint 1)

When taking control of the camera in Flutter, lock these settings:

| Setting | Value | Why |
|---|---|---|
| Resolution | 1080p | 4K is overkill, wastes storage |
| Frame rate | 30fps locked | Prevents variable FPS confusing tracker |
| Exposure | Lock after 3 seconds | Prevents drift when players move into shadow |
| Focus | Lock to infinity | Court is always far, no hunting needed |
| HDR | Disabled | Inconsistent tone mapping breaks CV |
| Stabilization | Off or locked | Can subtly shift frame geometry |

**On-device compression before upload:**
- Target: ~5 Mbps bitrate, 1080p
- Result: 90-min match ≈ 400–800 MB (down from 4–8 GB raw)
- Upload time on 4G: ~3–8 minutes instead of 40+ minutes
- This is non-negotiable for UX — do it in Sprint 1

---

## Infrastructure & pricing

### Current: Modal (serverless GPU)
- ~$0.00034/second on A10G = ~$0.74/hour
- 90-min match takes ~35 min to process → ~$0.43/match
- Scales to zero: pay nothing between matches
- Free tier: $30/month (covers ~65 matches — enough for prototyping)
- Cold start: 2–5s, acceptable for async processing

### Future (>50 users): RunPod
- Spot A10G: ~$0.14–0.22/hour → ~$0.08–0.13/match
- On-demand A10G: ~$0.34/hour → ~$0.20/match
- Requires queue management and retry logic (already designed above)

### Unit economics at scale
- User plays 8 matches/month
- Modal cost: ~$3.44/user/month
- RunPod cost: ~$1.04–1.60/user/month
- Target price: ~€10–15/month subscription → healthy margin on RunPod

### Video storage: Cloudflare R2 (not Supabase Storage)
Supabase Storage has a 50 MB file size limit — not suitable for match videos
(400–800 MB compressed). Use Cloudflare R2 instead.

- R2 free tier: 10 GB storage, 1M Class A (write) ops/month, 10M Class B (read) ops/month
- No egress fee: backend downloads video for free (unlike S3)
- S3-compatible API: use `boto3` with `endpoint_url=https://<account>.r2.cloudflarestorage.com`
- Delete raw video from R2 immediately after processing completes
- Supabase Storage is still used for user avatars / small assets if needed

---

## GDPR & privacy (required before TestFlight to strangers)

You are in the EU. Your app records video of real people, including players who may not have installed the app.

**Before going beyond friends:**
- [ ] Privacy policy (what data is collected, retention period, deletion rights)
- [ ] Consent flow in app — all 4 players should acknowledge before recording starts
- [ ] Right to erasure — users can delete their account and all associated data
- [ ] Raw video deleted from Cloudflare R2 after processing (not optional — minimise data)
- [ ] Processing purpose documented: "improve performance analytics, not sold to third parties"

**Practical data retention policy:**
- Raw video: deleted immediately after processing succeeds
- Position tracks: kept indefinitely (small, no biometric data)
- Match results JSON: kept indefinitely (user's own data)

---

## Error handling — CV failures

The pipeline will sometimes fail. Define behaviour for each case:

| Failure | Detection | User message |
|---|---|---|
| Bad camera angle | Court detection fails | "Adjust your phone angle and try again" |
| <4 players detected | Track count check | "We could only track X players — results may be incomplete" |
| Upload interrupted | Resumable upload | Auto-retry, show progress |
| Processing timeout | Job >60min | "Analysis is taking longer than expected — we'll notify you" |
| Processing failed | 3 retries exhausted | "Analysis failed — no charge applied" |

---

## Hard constraints — never violate

1. All CV inference runs server-side. Phone = camera + display only.
2. Fixed camera angle only. Back corner, 1–1.5m height. Not general-purpose.
3. Exactly 4 players always on court. Hard prior for sanity checks.
4. Async processing always. Never block UI waiting for CV results.
5. Supabase is the only app backend. CV backend writes results directly to Supabase.
6. Provider-agnostic CV interface. analyze_match() never knows where it runs.
7. Delete raw video after processing. Legal + cost requirement.

---

## Analytics & crash reporting (add before TestFlight)

Without this you're flying blind in production:
- Crash reporting: Sentry or Firebase Crashlytics (free tier sufficient)
- Key funnel to track: record_started → upload_complete → analysis_done → results_viewed
- Alert if: upload failure rate >5%, processing failure rate >10%

---

## What NOT to build before October

- Android-specific features (Flutter builds it, don't optimise for it)
- Coach / club dashboard
- Live streaming
- Training drill mode
- Line calling / VAR
- Web app
- Ball speed (requires fine-tuned model — post-MVP)

---

## Key existing files

- `lib/features/match/domain/models/match.dart` — core Match model
- `lib/features/auth/data/repositories/auth_repository.dart` — Supabase auth
- `lib/features/rating/domain/services/elo_calculator.dart` — ELO logic
- `ROADMAP.md` — sprint plan, feature backlog, decision checkpoint


---

## Open questions — check ROADMAP.md for full context

These are unresolved decisions that affect implementation. Do not build dependent features without resolving them first.

| Question | Affects | Decide before |
|---|---|---|
| Player identification UX (anonymous tracks → named players) | Results screen design | Sprint 3 |
| Processing time SLA (what to promise users) | Upload/waiting UI copy | Sprint 3 |
| Free tier limits (risk of GPU cost abuse) | Supabase RLS, usage tracking | Sprint 4 |
| Apple Developer account ($99/year, approval time) | TestFlight distribution | Sprint 4 |
| Pricing model: subscription vs pay-per-match | Paywall UI, backend entitlements | Sprint 7 |
| Payment integration: Apple IAP via RevenueCat recommended | Subscription flow | Sprint 7 |


---

## Development workflow

### Git conventions

**Branching:** Never commit directly to `main`. Always create a feature branch.
```
main                        ← always stable, always deployable
  └── feature/[description] ← new features
  └── fix/[description]     ← bug fixes
  └── chore/[description]   ← non-functional changes (docs, config)
```

**Branch naming examples:**
- `feature/recording-screen`
- `feature/video-upload-pipeline`
- `feature/results-heatmap-ui`
- `fix/court-detection-outdoor`

**Commit message format:**
```
feat: add camera recording screen with start/stop control
fix: court detection fails when court lines are faded
chore: update CLAUDE.md with Sprint 1 architecture decisions
test: add unit tests for heatmap grid normalization
refactor: extract video compression into separate service
```

**Session discipline:**
- Commit early and often — after every logical unit of work
- Always push before ending a session — no work lives only on disk
- If a session ends mid-feature, commit with `wip:` prefix so the state is clear

### Claude Code instructions

When starting a session:
1. Read `CLAUDE.md` fully before writing any code
2. Check `ROADMAP.md` to confirm which sprint is active
3. Create a feature branch before making any changes
4. Ask clarifying questions before implementing if the spec is ambiguous

When finishing a session:
1. Ensure all changes are committed with descriptive messages
2. Push the branch to remote
3. If feature is complete, say "ready for review on branch [name]"
4. If session ends mid-feature, commit with `wip:` and say which file to continue from

### Testing on device

**Important: no Mac available. Use this setup.**

**Daily development — Android via USB:**
```bash
flutter run -d [device-id]     # builds and installs directly to Android phone
flutter devices                # list connected devices
```
Android is the primary development and daily testing device. Already confirmed working (APK installed).

**iOS builds — Codemagic (no Mac needed):**
- Push to GitHub → Codemagic builds iOS on a cloud Mac → uploads to TestFlight automatically
- Free tier: 500 build minutes/month (~30–50 builds per month)
- A Flutter iOS build takes ~10–15 minutes
- Setup once: connect GitHub repo at codemagic.io, add Apple Developer credentials
- First TestFlight build requires ~1 day Apple review; subsequent builds are instant

**Validation rhythm:**
- Daily: test on Android phone via USB
- Weekly: push to main → Codemagic build → install from TestFlight on iPhone

**Camera behaviour difference:**
Camera locking (exposure, focus, frame rate) behaves differently on Android vs iOS.
Test CV pipeline on Android-recorded video in Sprint 1 to confirm quality is sufficient.
Do not assume iOS and Android produce identical video for the tracker.

### The planning ↔ implementation loop

```
Claude.ai (planning)          Claude Code (implementation)
────────────────────          ──────────────────────────
Define feature spec      →    Read CLAUDE.md
Resolve open questions        Create feature branch
Update CLAUDE.md         →    Implement
                         ←    "Ready for review on branch X"
Review on device
Give feedback            →    Fix issues
Confirm "approved"       →    Merge to main, delete branch
Update CLAUDE.md              Push main
```

### Backend deployment

```bash
# Deploy CV backend to Modal
modal deploy cv_backend/infra/modal_runner.py

# Test locally before deploying
modal run cv_backend/infra/modal_runner.py --video-path test.mp4
```

### Environment variables (never commit these)

Required in `.env` (local) and as secrets in CI:
```
SUPABASE_URL=
SUPABASE_SERVICE_KEY=           # backend only — never in Flutter app
SUPABASE_ANON_KEY=              # Flutter app (safe to expose)
MODAL_TOKEN_ID=
MODAL_TOKEN_SECRET=
CLOUDFLARE_R2_ACCOUNT_ID=       # backend + Flutter (for pre-signed URL generation)
CLOUDFLARE_R2_ACCESS_KEY=       # backend only
CLOUDFLARE_R2_SECRET_KEY=       # backend only
```

Flutter app only needs `CLOUDFLARE_R2_ACCOUNT_ID` if it generates pre-signed URLs
client-side (Sprint 1 decision). If the backend generates pre-signed URLs and hands
them to the app, none of the R2 credentials go near the Flutter app.

Flutter: use `--dart-define` or a `.env` loader. Never hardcode keys.

### Definition of "done" for a feature

A feature is not done until:
- [ ] Works on a real iPhone (not just simulator)
- [ ] Handles the main error case (network failure, bad input, etc.)
- [ ] Committed and pushed on a feature branch
- [ ] Reviewed and approved by Victor
- [ ] Merged to main
---

## Documentation rules

These apply to every session, not just Sprint 0.

### README.md (project root) must always contain:
- What the app does (one paragraph, non-technical)
- Repo structure overview
- How to run the Flutter app locally (exact commands, env vars needed)
- How to run the CV backend locally
- How to deploy the backend to Modal
- Current sprint and status (update every session)

### cv_backend/README.md must always contain:
- What the backend does
- How to install Python dependencies
- How to run locally for testing
- How to deploy to Modal
- API endpoint reference

### Rules:
- Treat outdated documentation as a bug — same priority as a code bug
- If you add an env var → update README immediately
- If you change a command → update README immediately
- If you finish a sprint task → update "Current sprint and status" in README.md
- Every session ends with: code committed + pushed, README.md status updated

### ROADMAP.md updates:
- When a task is completed, mark it `[x]` in ROADMAP.md
- When a sprint is fully done, add a completion date
- Never delete tasks — cross them out with a note if they were intentionally dropped

---

## Sprint 0 — Architectural decisions (2026-04-11)

These decisions were made during Sprint 0 and should not be revisited without good reason.

### Python project layout
`pyproject.toml` lives at the **repo root**, not inside `cv_backend/`. This lets
hatchling resolve `cv_backend/` as a top-level Python package. Running `uv sync`
from the repo root installs all dependencies into `.venv/` at the root.

### uv as Python package manager
Use `uv` for all Python dependency management. Key commands:
```bash
uv sync                    # install base deps into .venv
uv sync --extra cv         # also install heavy CV deps (GPU workers only)
uv run uvicorn cv_backend.api.main:app --reload   # run locally
uv run pytest              # run tests
```

### match_analyses.result is JSONB
The `result` column in `match_analyses` is JSONB, not typed columns. This keeps
the schema migration-free as `AnalysisResult` grows (ball tracking Sprint 5,
rally data, etc.). The CV pipeline serialises `AnalysisResult` with
`dataclasses.asdict()` before writing to Supabase.

### Job queue — single worker in Sprint 0
The Sprint 0 poller uses a simple fetch-then-update pattern (not
`FOR UPDATE SKIP LOCKED`). This is safe because Modal runs a single worker in
Sprint 0. Add `FOR UPDATE SKIP LOCKED` in Sprint 2 when scaling to multiple
workers.

### CI/CD workflow
`.github/workflows/deploy-backend.yml` deploys `cv_backend/infra/modal_runner.py`
to Modal on every push to `main` that touches `cv_backend/` or `pyproject.toml`.
Requires four GitHub repository secrets: `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`,
`SUPABASE_URL`, `SUPABASE_SERVICE_KEY`.

### Sprint 0 status (as of 2026-04-11)
- [x] Flutter app audited — all features complete and working
- [x] `cv_backend/` scaffolded with provider-agnostic `analyze_match()` stub
- [x] Supabase migrations written: `processing_jobs`, `match_analyses`
- [x] FastAPI stub: POST /analyze, GET /analyze/{job_id}
- [x] Job queue poller skeleton with retry logic
- [x] `pyproject.toml` + uv set up
- [x] CI/CD workflow written (`.github/workflows/deploy-backend.yml`)
- [x] Supabase migrations applied to project
- [x] Cloudflare R2 bucket created
- [x] Modal account set up and GPU deployment verified end-to-end (run_poller live, succeeding)
- [x] End-to-end smoke test: dummy upload → job queued → stub result in Supabase ✓
