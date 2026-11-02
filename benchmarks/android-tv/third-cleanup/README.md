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
| Smooth modern card transitions | Faster critically damped motion; held navigation keeps the row expanded | Awaiting OK |
| Smooth row changes | Retargetable scroll spring preserves velocity; row focus space no longer changes row height | Awaiting OK |
| Keep the same artwork on focus | Collapsed cards crop the same wide image revealed by expansion; prefetch and card reuse one decode | Awaiting OK |
| Improve Home/details loading | Home coalesces arrivals within a frame; details publish main seasons/episodes or initial collection/playlist members with the first ready state | Awaiting OK |
| Improve receiver audio startup | Initial Media3 streaming buffer reduced from 1,000 to 500 ms; source-to-AudioTrack/advancing diagnostics added | Awaiting OK |
| Double-Back exit toast | Two-second toast at root; separate second press exits, route changes reset it, duplicate dispatch is ignored | Awaiting OK |
| Restart for movies/episodes | Secondary player control seeks the current stream to zero then resumes, retaining queue/source/tracks and cancelling stale scrub state | Awaiting OK |

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

## Shield gate

**Ready, awaiting explicit user OK.** No ADB calls, installation, launch or Shield
checks were performed for this round. The existing separate test app's data was not
cleared. After approval, validate startup, sustained D-pad/card and row movement,
movie/series details, movie and episode Restart, root Back behavior, subtitles,
seek/resume, HDR/passthrough and audio-startup timing against the prior build.

APK size is a static footprint result; runtime performance still needs those checks.
