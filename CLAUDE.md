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
  analysis/          ⬜ Sprint 3

cv_backend/
  pipeline/          analyze_match.py, player_tracker.py, ball_tracker.py, court_detector.py
  api/               main.py, models.py, job_queue.py
  infra/             modal_runner.py (active), runpod_runner.py (future)
```

---

## Current sprint: Sprint 2 (Analysis Pipeline)

### Done
- [x] Gallery upload: `image_picker` → R2 → processing_jobs → edit screen
- [x] Court calibration screen: crosshair-based 12-keypoint placement (pan/zoom), Place/Skip/Undo/Confirm, tested on Android, payload confirmed correct — branch `feature/court-calibration-screen`
- [x] Frame extraction: `ffmpeg_kit_flutter_new` extracts 1 frame from local video after record/gallery pick → passes `framePath` to calibration screen

### In progress / next
- [ ] **Backend H matrix** (next): receive 12 keypoints (some null), `cv2.findHomography(RANSAC)`, store 3×3 H in Supabase as JSONB
- [ ] **First Codemagic iOS build**: smoke test camera lock + background upload on real iPhone via TestFlight — do not skip, iOS camera behaviour differs from Android
- [ ] Player tracking: YOLO11l + DeepOCSORT, output per-player positions at 1 fps
- [ ] Aggregate: heatmap grid (20×10), total distance, court coverage %
- [ ] Write AnalysisResult to match_analyses; delete raw video from R2
- [ ] Push notification on completion

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