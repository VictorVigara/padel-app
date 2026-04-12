# Padel App — Product Roadmap

## Development setup

**No Mac available.** Daily development and testing happens on Android via USB (`flutter run`). iOS builds are produced via [Codemagic](https://codemagic.io) (cloud CI/CD, free tier: 500 min/month) and distributed via TestFlight. The end-user target is iOS — Android is the development proxy.

- Set up Codemagic + Apple Developer account ($99/year) before Sprint 4
- First TestFlight smoke test scheduled in Sprint 2/3 to validate camera lock + background upload on iPhone early
- Do not wait until Sprint 4 to find out iOS behaves differently

---

Pro-level padel match analysis from any court, using just your iPhone. No club infrastructure, no complex setup — place your phone in the back corner (Gimadd-style mount), tap record, and get the stats that court-installed cameras provide, in your pocket.

## Positioning

| | Us | SwingVision | Wingfield / Clutch |
|---|---|---|---|
| Works anywhere | ✅ | ✅ (tennis) | ❌ club-only |
| Padel-specific | ✅ | coming 2025 | ✅ |
| Corner mount 1–1.5m | ✅ | ✅ | ❌ needs 3m+ |
| Player movement analytics | ✅ | ✅ | ✅ |
| No hardware cost | ✅ | ✅ | ❌ ~$5k |

## Core MVP user story

> A player opens the app, taps record, places their phone in the back corner, plays a full match, taps stop, and within 15 minutes receives heatmaps and distance stats for all 4 players automatically.

---

## Sprint plan

### Sprint 0 — Foundation (2 weeks)
**Goal:** Clean architecture that everything else plugs into. No new features, just structure.

- [x] Audit existing Flutter app — document what works, what's unused, dead code
- [x] Define Supabase schema additions: `processing_jobs`, `match_analyses` tables
- [x] Scaffold `cv_backend/` directory structure (pipeline / api / infra separation)
- [x] Implement provider-agnostic interface: `analyze_match(video_path) → AnalysisResult`
- [x] Set up Supabase storage bucket for video files (using Cloudflare R2 instead — free tier suitable)
- [x] Scaffold FastAPI app with `/analyze` endpoint (stub, no real CV yet)
- [x] Set up Modal account and verify GPU deployment works end-to-end
- [x] Set up CI/CD for backend (GitHub Actions → Modal deploy)
- [x] Update `CLAUDE.md` with any decisions made during sprint

**Done when:** App can upload a dummy file to Supabase storage, backend receives the job, runs a stub, writes a result row to Supabase.

**Sprint 0 completed: 2026-04-11** ✓

---

### Sprint 1 — Record & Upload (3 weeks)
**Goal:** User can record a match inside the app and upload it correctly for processing.

**Recording:**
- [x] Recording screen: camera preview, start/stop, elapsed time display
- [x] Lock camera settings: 1080p, 30fps, fixed exposure after 3s, focus infinity
- [x] Court detection validation before recording — show "angle looks good ✓" or guide to adjust
- [x] On-device compression after recording (~5 Mbps, target 400–800 MB for 90-min match)

**Upload:**
- [x] Upload compressed video directly to Cloudflare R2 (pre-signed URL flow, S3-compatible)
- [x] Resumable upload — handle interrupted connections (background_downloader 3× retry)
- [x] Background upload — continues if user locks phone (NSURLSession iOS / WorkManager Android)
- [x] Insert row in `processing_jobs` (with R2 object URL) after upload completes
- [x] "Match pending analysis" state visible in match history ("Analysing..." / "Analysis failed" badges)
- [x] Camera button creates draft match directly — no form before recording
- [x] Post-upload navigates to match edit screen (fill in results after playing)
- [x] Match status state machine: draft → recording → processing → completed
- [x] Supabase migration: nullable match fields + status column

**Sprint 1 completed: 2026-04-12** ✓

**Done when:** A real 90-min match video is uploaded, compressed, stored in Cloudflare R2, and a processing job is queued. Upload completes in under 10 minutes on 4G.

---

### Sprint 2 — Analysis Pipeline (3 weeks)
**Goal:** Backend processes real match video and returns structured tracking data.

- [ ] **First Codemagic iOS build** — smoke test camera lock, compression, and background upload on a real iPhone via TestFlight. Do not skip this; camera behaviour differs between Android and iOS and Sprint 3 depends on it.
- [ ] Gallery upload: `image_picker` → same R2/processing_jobs flow as recording → match edit screen (no compression for gallery videos)
- [ ] Court homography: detect court keypoints, compute H matrix (pixel → court-meter transform), store in Supabase
- [ ] Replace `/analyze` stub with real job that runs homography on uploaded video
- [ ] Backend polls `processing_jobs` table every 30s, picks up queued jobs
- [ ] Player tracking: YOLO11l + DeepOCSORT, output per-player positions at 1fps
- [ ] Aggregate to heatmap grid (20×10), total distance, court coverage %
- [ ] Write `AnalysisResult` JSON to `match_analyses` table in Supabase
- [ ] Delete raw video from Cloudflare R2 after successful processing
- [ ] Push notification to phone when done
- [ ] Error handling: bad angle, <4 players, timeout, 3-retry exhaustion
- [ ] Processing progress updates (% complete) written to `processing_jobs`

**Done when:** A real match video produces real heatmap data visible in the database. End-to-end latency (upload start → results available) under 20 minutes.

---

### Sprint 3 — Results UI (2 weeks)
**Goal:** Player sees their results in a clear, satisfying way.

- [ ] Results screen: 4-player heatmap overlaid on court diagram
- [ ] Distance covered per player (styled card with player name)
- [ ] Court coverage % per player
- [ ] Link results to existing match history entry
- [ ] Replace ServeStatsCard and ShotDistributionCard with padel-specific equivalents (smash speed, bandeja frequency, court zone distribution) — these currently show zeros and use tennis-specific fields. CV data in Sprint 2 will populate match_stats with inputSource=cvAuto; update the widgets to consume it.
- [ ] Processing states: "uploading", "analysing (X% done)", "ready", "failed"
- [ ] Failed state: clear message, no charge note, option to retry
- [ ] Basic share: screenshot-friendly results card for WhatsApp/Instagram

**Done when:** A padel player who wasn't involved in building the app opens it, records a match, and understands the results without any explanation.

---

### Sprint 4 — Polish & First Real Users (2 weeks)
**Goal:** Ready to hand to strangers. Legal minimum met.

- [ ] Onboarding: how to position the phone, what angle looks like, what to expect
- [ ] Privacy policy published (video storage, retention, deletion, EU compliance)
- [ ] Consent flow: all 4 players acknowledge before recording starts
- [ ] Right to erasure: account deletion removes all associated data
- [ ] Crash reporting: Sentry or Firebase Crashlytics integrated
- [ ] Key funnel analytics: record → upload → analysis → results viewed
- [ ] Alert setup: notify if upload failure >5% or processing failure >10%
- [ ] Fix top 5 bugs from friend testing
- [ ] TestFlight distribution to first 10 external users
- [ ] Supabase RLS rules audited before strangers have accounts

**Done when:** 10 people outside your network have completed the full record → results loop.

---

### Sprint 5 — Rally & Ball Analysis (3 weeks)
**Goal:** Add ball tracking to unlock point-level insights.

- [ ] Ball tracking pipeline (TrackNetV4) integrated into `analyze_match()`
- [ ] Rally segmentation: divide match into individual points
- [ ] Rally count and length distribution per match
- [ ] Shot placement map: where balls land on court (zone heatmap)
- [ ] Results screen updated with rally tab
- [ ] Fine-tune TrackNetV4 on own padel footage if needed

---

### Sprint 6 — Social & Retention (2 weeks)
**Goal:** Make players come back and bring friends.

- [ ] Auto highlight clip: best 3–5 rallies, dead time removed
- [ ] Progress over time: heatmap and distance trends across matches
- [ ] Friend leaderboards: distance run, rally length, court coverage
- [ ] ELO rating connected to CV-verified match results (already built — just wire up)
- [ ] Share stats card: Instagram/WhatsApp-ready after each match

---

### Sprint 7 — Tactical Insights (V3, ongoing)
**Goal:** Features that no consumer app currently offers for padel.

- [ ] Shot classification: forehand / backhand / smash / lob / bandeja
- [ ] Ball speed estimation (serve speed, smash speed)
- [ ] Weak zone analysis: "you lose X% of points when pushed to back-left"
- [ ] Partner coordination score: how well you split the court
- [ ] AI coaching insights: LLM-generated advice from match stats
- [ ] Monetisation: introduce paid tier, define free tier limits

---

## Infrastructure

### Now → ~50 users: Modal
- Serverless GPU, scales to zero, no ops burden
- ~$0.43/match on A10G
- Free tier: $30/month (covers ~65 matches — enough for all prototyping)

### 50 → 500 users: RunPod
- Spot A10G: ~$0.10–0.16/match
- Requires queue management (already designed in Sprint 0)
- Switch is transparent: only `infra/runpod_runner.py` changes

### Unit economics (target)
- 8 matches/user/month × $0.15 = $1.20 compute cost
- Target subscription: €10–12/month
- Gross margin on compute: ~88% — healthy

### Video storage
- Delete raw video from Supabase Storage immediately after processing
- Keep only results JSON — no ongoing per-match storage cost
- Supabase free tier (1 GB) is sufficient for transient video

---

## Architecture decisions (locked)

1. **Flutter, not React Native or Swift-only** — cross-platform from day one
2. **Supabase as single app backend** — auth, DB, storage, push, all in one
3. **Cloud GPU for all CV** — phone is camera + display only, no on-device ML
4. **Async processing always** — upload → queue → notify, never synchronous
5. **Provider-agnostic CV interface** — `analyze_match()` knows nothing about infrastructure
6. **Supabase-based job queue** — no Redis, no extra infrastructure needed at this scale
7. **Delete raw video post-processing** — GDPR + cost requirement, non-negotiable
8. **1080p 30fps locked recording** — CV consistency over video quality

---

## Open questions (decide before Sprint 3)

- **Free tier limits:** How many matches per month free? 2? 4? Unlimited during beta?
- **Processing SLA:** What do you promise users? ("Results within 20 minutes" or "Results within 1 hour"?)
- **Player identification UX:** How does a user tag which heatmap belongs to which player? Manual tag after match? Automatic by jersey color?
- **App Store pricing:** Free download with subscription, or paid upfront?

---

## October decision checkpoint

By October the goal is evidence to make a "go full-time" decision:

- ≥ 50 users who have completed the full record → results loop
- ≥ 5 users who have used it 3+ times (retention signal)
- At least 1 person saying "I'd pay for this"
- Clear view of which feature drives retention
- Unit economics validated: actual compute cost per active user measured


---

## Open questions & unresolved decisions

These must be decided before the sprint indicated. Do not build the dependent feature without resolving them first.

### Before Sprint 3 — Results UI

**Player identification UX**
When analysis returns 4 anonymous tracks, how does the user know which heatmap is theirs?
Options:
- Manual tagging post-match: user taps each heatmap and assigns a name
- Automatic by jersey color: CV attempts color-based identification (unreliable, extra work)
- Court position labels: "front-left", "back-right" etc. (no CV needed, but less personal)
Recommendation: start with court position labels in MVP, add manual tagging in V2.

**Processing time SLA**
What do you promise users in the UI? This affects trust and support load.
Options: "Results within 20 minutes" / "Results within 1 hour" / "We'll notify you when ready" (no promise)
Recommendation: "usually ready in 15–20 minutes" with no hard guarantee during beta.

### Before Sprint 4 — First Real Users

**Free tier limits**
Without limits, a viral moment could generate hundreds of dollars in GPU costs overnight.
Options:
- 2 free matches/month forever
- Unlimited during beta period (e.g. first 60 days after signup), then requires subscription
- No free tier — paid from day one (reduces volume but ensures only motivated users)
Recommendation: unlimited during beta with a clear "beta ends [date]" message, then 2 free/month.

**App Store submission + no Mac constraint**
No Mac available for local iOS builds. iOS builds are handled via Codemagic (cloud CI/CD, free tier sufficient).
Codemagic should be set up in Sprint 2 (first smoke test build). By Sprint 4 it should already be working.
Setup required before Sprint 4 if not done in Sprint 2:
- Apple Developer account ($99/year) — activate early, takes 24–48h
- Connect GitHub repo to codemagic.io
- Add Apple signing credentials to Codemagic once
- First TestFlight build needs ~1 day Apple review; subsequent builds are instant

### Before Sprint 7 — Monetisation

**Pricing model: subscription vs pay-per-match**
- Subscription (e.g. €10–12/month): predictable revenue, simpler to reason about, standard in this space
- Pay-per-match (e.g. €1–2/match): aligns with usage, lower barrier to try, harder to predict revenue
- Hybrid: N free matches/month, subscription for unlimited
Recommendation: monthly subscription, same model as SwingVision. Decide price before Sprint 7.

**Payment integration**
Apple requires in-app purchases for subscriptions sold inside iOS apps (30% cut on year 1, 15% after).
Options: Apple IAP only (simplest, required for App Store), or web-based subscription + unlock code (avoids Apple cut but violates App Store guidelines if done wrong).
Recommendation: use Apple IAP via RevenueCat library — handles entitlements, restores, and cross-platform cleanly.

