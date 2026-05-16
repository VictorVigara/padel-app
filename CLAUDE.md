# Padel App — Claude Code Context

## What this is
AI-powered padel match analysis from any court using just an iPhone.
Phone placed in back corner (Gimadd mount, 1–1.5m), records match → cloud CV → heatmaps + distance stats.
**"Court-installed camera analytics, in your pocket, on any court."**

## Platform
- **End-user target: iOS (iPhone).** Flutter for cross-platform.
- **Daily dev: Android via USB** (`flutter run`). No Mac available.
- **iOS builds: Codemagic** (cloud CI/CD) → TestFlight.
- All CV is **server-side only** — phone is camera + display, no on-device ML.
- Recording locked at **1080p / 30fps / fixed exposure** — CV consistency over quality.

---

## Stack

### Mobile (Flutter)
| Concern | Library |
|---|---|
| State | Riverpod + riverpod_generator |
| Navigation | go_router |
| Backend | Supabase (auth, DB, realtime) |
| Charts | fl_chart |
| Models | Freezed + json_serializable |
| Recording | camera + ffmpeg_kit_flutter_new |
| Upload | background_downloader |
| Gallery | image_picker |

### Backend (Python)
| Concern | Tech |
|---|---|
| Framework | FastAPI |
| Player tracking | YOLO11l + DeepOCSORT (BoxMOT) + OSNet |
| Ball tracking | TrackNetV4 |
| Hosting | Modal (now) → RunPod (>50 users) |
| Video storage | Cloudflare R2 (deleted after processing) |
| Results/queue | Supabase |

---

## Architecture (data flow)
```
iPhone
  → compress on-device (ffmpeg, ~5 Mbps, 400–800 MB / 90 min)
  → upload direct to Cloudflare R2 (pre-signed URL)
  → insert row in processing_jobs (Supabase)
  → await push notification

Modal (FastAPI, GPU)
  → polls processing_jobs every 30s
  → downloads from R2 (boto3, S3-compatible)
  → analyze_match(video_path) → AnalysisResult
  → writes to match_analyses (Supabase)
  → deletes raw video from R2
  → notifies phone
```

## CV interface — NEVER leak infra into pipeline
```python
def analyze_match(video_path: str, config: AnalysisConfig) -> AnalysisResult: ...
# analyze_match() knows nothing about Modal/RunPod/queues/HTTP.
# Switching infra = rewrite only infra/modal_runner.py.
```

`analyze_match.py` imports from the `padeldet` package (the sibling repo at `../padeldet/`), not from any file inside `cv_backend/`. All CV improvements go into `padeldet/` and are picked up at the next Modal deploy. The GPU worker bundles padeldet via `add_local_python_source` — no git access needed inside Modal's build sandbox.

**Deploy command** (from `padel_app/`):
```bash
uv pip install --no-deps -e ../padeldet   # one-time setup
uv run python -m modal deploy cv_backend/infra/modal_runner.py
```

## DB tables (key ones)
- `processing_jobs`: id, match_id, video_url, status (queued|processing|done|failed), retry_count
- `match_analyses`: id, match_id, result (JSONB AnalysisResult), created_at
- `matches`: …, status (draft|recording|processing|completed), nullable player/score fields

---

## Codebase layout
```
padel_app/lib/features/
  auth/              ✓ complete
  match/             ✓ complete (history, ELO, edit form)
  player_profile/    ✓ complete
  rating/            ✓ complete (ELO)
  recording/         ✓ Sprint 1+2 (record, compress, upload, calibration screen)
  analysis/          ✓ Sprint 3 (heatmap, player chips, stat grid, distance bars)

cv_backend/
  pipeline/          analyze_match.py, player_tracker.py, ball_tracker.py, court_detector.py
  api/               main.py, models.py, job_queue.py
  infra/             modal_runner.py (active), runpod_runner.py (future)
```

---

## Sprint 3 — Results UI ✓ COMPLETE

### Shipped
- [x] **Task 0**: Player color constants in `AppColors` (player1–4: green, orange, blue, pink)
- [x] **Task 1**: Freezed models (`AnalysisResult`, `PlayerAnalysis`, `ProcessingMeta`), `AnalysisRepository`, `analysisResultProvider`
- [x] **Task 2**: `MatchAnalysisScreen` scaffold — loading/error/empty/data states; `/matches/:id/analysis` route; "View Analysis" button gated on `AnalysisStatus.done`
- [x] **Task 3**: `CourtHeatmapPainter` — half-court 10×10, cell opacity from intensity, court markings, "Your Side" / "Opponents' Side" ChoiceChip toggle — `lib/features/analysis/presentation/widgets/court_heatmap_painter.dart`
- [x] **Task 4**: Full screen layout — player selector chips (P1–P4, player colors), 2×2 stat grid (distance / coverage / inferred position), distance comparison bars (proportional Containers, no fl_chart)
- [x] **Task 5** (2026-05-15): Fix heatmap orientation, player-ID mapping, and court markings — see "Analysis results screen" notes below.

### Known issues / deferred
- Manual player tagging (name assignment) deferred to Sprint 6.

### Still pending from Sprint 2
- [ ] Push notification to phone when analysis completes
- [ ] Processing progress % written to `processing_jobs`
- [ ] First Codemagic iOS build — smoke test camera + background upload on real iPhone

## Next: Sprint 4 (TBD — Modal deployment or ball tracking)

---

## Key decisions & constraints

### Routing
- **Never mix `context.go()` and `context.pop()`** — go() resets the stack, pop() will fail. Navigate explicitly to target routes.
- Calibration route: `/matches/:id/calibrate` (extra: `framePath` as `String?`). If null → skip calibration, redirect to edit.

### Court calibration (crosshair approach)
- Fixed crosshair on viewport; user pans/zooms image, taps Place.
- Coordinate math: `TransformationController.toScene(crosshairInViewport)` — no manual Matrix4.
- Dots stored as normalised 0–1 fractions; pixel coords stored separately for backend payload.
- Reset transform (`Matrix4.identity()`) when all 12 steps done.
- `_viewportKey` on `InteractiveViewer` itself (not the Expanded wrapper).
- 12 keypoints; minimum 4 non-null for valid homography.

### Analysis results screen (Sprint 3)
- Route: `/matches/:id/analysis` — added to `app_router.dart`, same pattern as `/calibrate`.
- Player identification: anonymous track IDs → court position labels inferred from heatmap center-of-mass. "Front Left / Back Left / Front Right / Back Right". Manual tagging deferred to Sprint 6.
- Backend `track_id` strings (`"player_N"`) carry the player tracker's `logical_player_id` (1=near-left, 2=near-right, 3=far-left, 4=far-right). The screen **parses and sorts by that integer** before building chips — `data.players` arrives in detection-insertion order from a `defaultdict`, so without the sort UI's "P1" can map to logical P3 and the heatmap lands in the wrong half.
- Heatmap: **half-court only** (10×10 cells, 1:1 aspect ratio) — full 20×10 court is too tall on iPhone portrait. "Your Side" = rows 0–9 reversed (net at top of display), "Opponents' Side" = rows 10–19 with **columns mirrored** so each team is displayed from its own forward-facing POV (display col 0 = the player's own left).
- `_showYourSide` lives on `_MatchAnalysisScreenState` (lifted out of the widget) and **auto-toggles** when a chip is tapped: `_showYourSide = logicalId <= 2`. Manual chip taps still work via `onSideChanged`.
- Court markings in `CourtHeatmapPainter`: amber net edge along the top, service line at **7/10** of the half-court height (3 m from the back wall, not the net), centre service line drawn between net and service line (it divides the two service boxes).
- Player selector: 4 ChoiceChip tabs above heatmap, labels and colors keyed by parsed `logicalId` (not list index), colors from `AppColors.player1`–`player4`.
- No fl_chart for bar chart — use sized Containers with proportional widths (avoids library dep + easier to style).
- `@JsonKey` required on all Freezed fields mapping to snake_case backend names. `List<List<double>>` heatmap requires a custom top-level converter (`_heatmapFromJson`) — json_serializable cannot auto-generate nested lists.
- "View Analysis" button lives in `_MatchDetailBody._buildAnalysisButton()`, watches `analysisStatusProvider`, only renders when `status == done`.
- Backend heatmap pipeline: `AnalysisConfig.heatmap_cell_size_m` (default 1.0) controls resolution; grid dims and coverage denominator are derived from `COURT_LENGTH` / `COURT_WIDTH` / `NET_POSITION` in `padeldet.court.models` — no hard-coded 20×10 / 200. Coverage % is computed against one half-court (`half_rows * grid_cols`), since a player only ever occupies their own half.

### Upload providers
- `GalleryUploadNotifier` is **not** autoDispose — must survive navigation.
- Gallery: do NOT delete source file after upload (it's from user's photo library).
- Recording: source temp file can be deleted after upload.

### Backend URL
```bash
# Local dev with physical Android device:
uv run uvicorn cv_backend.api.main:app --reload --host 0.0.0.0
ngrok http 8000   # use HTTPS URL as BACKEND_URL

# Compile-time inject:
flutter run --dart-define=BACKEND_URL=https://your-endpoint.modal.run
```

---

## Working rules for Claude Code sessions

### File discipline
1. **One file at a time.** Show before applying. Never multi-file chain edits.
2. **Debug prints**: add temporarily, remove once confirmed. Never commit them.
3. **After any bug fix**, re-run `flutter analyze` and confirm zero issues before proceeding.
4. **Update this file and ROADMAP.md** at sprint boundaries only — not mid-sprint.
5. When in doubt about a routing decision, check `app_router.dart` first.

### Task splitting (mandatory)
Every feature must be broken into subtasks before any code is written. Each subtask must:
- Touch the minimum number of files possible
- Have one clear, device-testable output
- Be completable and verifiable before the next subtask starts

Never plan or execute a feature as a single session. If a plan involves more than ~3 files or ~2 steps, split it further.

### Branch + approval workflow (default for every feature)
1. **Plan first**: propose the subtask breakdown and confirm with Victor before touching any code.
2. **Create a branch**: `git checkout -b feature/<name>` before writing any code. Never implement directly on `main`.
3. **Implement one subtask at a time**, with device testing between each.
4. **When the full feature is tested and working**: summarise what changed and what was tested.
5. **Wait for explicit approval** before running `git push` or opening a PR. Do not push automatically.
6. Only after Victor confirms → `git push origin feature/<name>`.

This workflow is the default. It applies to every new feature unless Victor explicitly says otherwise for a specific session.