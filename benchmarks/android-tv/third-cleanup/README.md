# Third cleanup: streaming-only playback and browsing

Compiled source: `eefa0a9f73d07fbe178b850a37afabc766be661d`.
Measured on 2026-11-02. This report commit changes documentation only.
The fork's `main` remains at `f95909b13187c0d7168c96ac0e3e09982b2ac96b`.

## Removed

The offline database and catalogue, saved-media screens, download and smart-download
services, offline playback/reporting, background refresh workers, removable-media
storage channels and local-notification infrastructure are deleted. Server clients,
stream resolution and playback reporting now use the server directly. Plex's online
resume/watched refresh after stopping is preserved.

The native Media3 Transformer download exporter and its channels/dependency are
also removed. The dependency inventory falls from **241 to 227 packages**, with
**14 removals, no additions and no retained-version changes**. See
[dependency-diff.json](dependency-diff.json).

Artwork/theme/message caches, server-side subtitle acquisition, client certificates,
media-session controls and Watch Next remain. Artwork caching still uses sqflite;
removing the separate offline SQLite bindings does not remove Android's cache DB.

## Requests from android-tv.todo

| Request | Implemented behavior | Shield status |
| --- | --- | --- |
| Smooth modern card transitions | Faster critically damped motion; held navigation keeps the row expanded | Exercised on Shield; see results below |
| Smooth row changes | Retargetable scroll spring preserves velocity; row focus space no longer changes row height | Exercised on Shield; see results below |
| Keep the same artwork on focus | Collapsed cards crop the same wide image revealed by expansion; prefetch and card reuse one decode | Exercised on Shield; see results below |
| Improve Home/details loading | Home coalesces arrivals within a frame; details publish main seasons/episodes or initial collection/playlist members with the first ready state | Exercised on Shield; see results below |
| Improve receiver audio startup | Initial Media3 streaming buffer reduced from 1,000 to 500 ms; source-to-AudioTrack/advancing diagnostics added | Audio output works; resume delay unresolved |
| Double-Back exit toast | Two-second toast at root; separate second press exits, route changes reset it, duplicate dispatch is ignored | Exercised on Shield; see results below |
| Restart for movies/episodes | Secondary player control seeks the current stream to zero then resumes, retaining queue/source/tracks and cancelling stale scrub state | Exercised on Shield; see results below |

Optional ratings/recommendations still load asynchronously. No Netflix-equivalent
frame pacing or audible receiver startup result is claimed. HDMI mode-switch settling,
steady-state buffering and rebuffer protection remain; removing these without device
evidence risks passthrough failures or stalls.

## Local verification

- Focused video/Home/auth/profile/subtitle run: 313 passed and one remote-banner
  failure. The root Overlay lookup was corrected; the remote-command/root-Back
  retry passed all 72 tests.
- Streaming manager, detail models/layouts, chapter and artwork run: **207 passed**.
- Live-stream completion/recovery, run in isolation: **61 passed**.
- Final real-card artwork, motion, scrolling and exit tests: **15 passed**. Expanding
  a card from portrait to wide dimensions retains one prewarmed image decode.
- Android app and native video JVM tasks: **315 passed**, zero failures/skips.
  This includes subtitle, passthrough-recovery and HDMI/display-policy coverage.
- Analyzer over lib, playback_core and test: **zero errors**, 11 inherited warnings
  and 127 informational lints. No full inherited-suite pass is claimed; the earlier
  whole-suite runner/completion limitation remains documented in the parent report.

[Local validation](local-validation.json) and [JVM suites](native-tests.json) record
these runs. Counts from overlapping runs must not be added as unique tests.

The release build passed after a retry. A concurrent local test had refreshed
Flutter's generated registrant to include the dev-only integration_test plugin during
release compilation. Building after all test processes finished resolved it. Do not
run Flutter test/pub tooling concurrently with the release build.

Pre-existing generated Finnish, Italian and Chinese translation edits remain in the
working tree and were excluded from the commits; only the new toast fallback getters
were staged. These existing local translation deltas were also present during local
verification/build. They are unrelated to the video/runtime changes.

## APK audit

| ARM64 Flutter release, unchanged support-JNI ABI policy | Bytes | MiB |
| --- | ---: | ---: |
| Original baseline | 82,209,327 | 78.40 |
| Second cleanup | 69,424,326 | 66.21 |
| Third cleanup | 66,362,480 | 63.29 |

This round saves **3,061,846 bytes / 2.92 MiB / 4.41%**.
Total reduction from the original baseline is **15.11 MiB / 19.28%**.

The APK remains `org.moonfin.androidtv.videoexperiment`, labelled Moonfin Video
Experiment, with required Leanback support. Native SQLite libraries for all three
support ABIs are absent. Downloader/local-notification DEX markers and Media3's
Transformer class are absent. ARM64 mpv, libass and libasskt are present. Removed
media-storage, notification and data-sync permissions are absent from the merged APK.
See [artifact-audit.json](artifact-audit.json) and [experiment-apk.json](experiment-apk.json).

Local APK: `artifacts/android-tv-video/release-android-arm64/moonfin-video-experiment.apk`.
SHA-256: `19e6105f252200a976e9598e0a37202affbae4e2f00707cedcbd578bf607420d`.

## Approved Shield follow-up

After explicit user approval, the audited APK was installed over the separate
experiment package without clearing app data. It opened signed in. The installed
APK hash matches the build audit above; no application code changed during this
follow-up. Main remains untouched.

Home artwork cropping/expansion, repeated horizontal movement, a held-key input,
row changes, search, movie/episode/series details, season switching, subtitles,
seek, pause/resume and Back navigation were exercised. Movie and episode Restart
were reached using D-pad navigation while paused: both returned the current title
to the beginning and resumed without advancing the queue. The first-Back toast,
expiry and a subsequent pair of Back presses returned to the launcher correctly.

Video coverage included a 1080p HEVC/AAC stereo episode, a 720p H.264/DTS 5.1 movie
and a 1080p H.264/E-AC-3 (DD+) 5.1 episode. Active Android audio tracks confirmed
encoded DTS and E-AC-3 output, six channels at 48 kHz. This confirms the Android
output path, not an independently measured receiver channel test. Existing movie
and episode resume points were returned near their earlier minute positions after
Restart checks. The additional Dolby episode was returned to its starting point.

### Audio finding: pause/resume remains delayed

The user reported prompt AAC startup, slower DTS startup than Netflix, and similar
DD+/DTS behavior with **1–2 seconds before audible audio after resuming**.

In a controlled DD+ pause/resume, the same track, audio session and port remained
allocated. Android's direct HDMI output entered standby while paused, then was
active and writing again in the first snapshot after a 300 ms post-resume wait
(plus command/dump overhead). The last write was 24 ms before that snapshot.
This points toward output/HDMI/receiver wake-up as a candidate; it does not isolate
the complete cause or prove how Netflix handles its output. A codec change alone
has not solved the observed gap. The smaller initial startup buffer does not
establish a pause/resume improvement. No baseline resume comparison was performed,
so this is not attributed to the cleanup as a regression.

The audio issue needs further investigation rather than removal of HDMI recovery
safeguards based on this observation. [Device validation](shield-validation.json)
records the controlled track states and the user feedback without media titles.

### Startup and memory, five paired samples

Both separate apps retained the same signed-in account, existing caches and their
default renderer policy. Both test packages were force-stopped before each launch;
PSS was captured after 15 seconds. Pair order was reversed on even pairs.

| Signed-in Home | Original runtime baseline | Third cleanup |
| --- | ---: | ---: |
| Median Activity launch | 998 ms | 868 ms |
| Activity launch range | 953–1,394 ms | 835–946 ms |
| Median settled process PSS | 328.6 MiB | 295.3 MiB |
| PSS range | 321.1–334.4 MiB | 293.3–315.3 MiB |

[Baseline samples](baseline-startup-signed-in.json),
[experiment samples](experiment-startup-signed-in.json) and
[summary](startup-summary.json) preserve the observations. This compares the whole
experiment with the original runtime baseline, not the isolated effect of round
three. The apps now load different poster/wide-artwork decodes and retain separate
caches. One small run does not establish a general performance improvement.
Activity launch time is not time to usable Home; PSS is one settled process sample,
not peak/playback memory or frame pacing.

The HWUI capture reported only one frame and SurfaceFlinger returned no presentation
history for the Flutter surface, so those captures cannot supply a scrolling FPS or
jank percentage. One startup warning about 42 skipped frames appeared on the first
post-install launch. No crash or stuck navigation was observed in the exercised flows.
HDR/Dolby Vision, TrueHD/DTS-HD/Atmos, live TV and mpv fallback remain outside this
follow-up's playback coverage.

The experiment was left signed in on Home with playback stopped. No settings or
caches were reset. Screenshots and raw playback/audio diagnostics remain local and
are not committed. Temporary test screenshots on the Shield were removed.
