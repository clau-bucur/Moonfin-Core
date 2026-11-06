# Android TV upstream integration - 2026-11-06

This update integrates the 49 upstream commits after
`9d256720f972d09a76e8f65d005ca10d6fa83a99`, through
`f4f2899451a7e26e45d935cf4d5648235d8f9149`.

The pending player Back-button grace-period change was preserved and pushed
first as `0f90ec1a2`. It ignores remote/system Back for 750 ms after controls
automatically hide, without extending that grace period on ignored presses.
The integration retains upstream merge ancestry for subsequent updates.

## Included updates

- Media3 keeps E-AC-3 tracks above 5.1 out of MPEG-TS, allowing the server to
  copy them into fMP4 instead of repeatedly restarting the audio decoder.
- mpv waits for the new file's real tracks before applying audio/subtitle
  selection, rather than treating its initial auto/no entries as ready.
- Auto bitrate uses a saved per-server measurement for normal stream
  negotiation and measures when transcoding is necessary. Direct play no
  longer waits for the speed probe; live streams retain their startup probe.
- Subtitle delay has a cue timeline near the top of the player. Ordinary
  controls stay mounted but hidden while the delay panel is open.
- Poster labels support icons and country flags. Requests are batched/cached
  by the upstream repository, and external Seerr cards do not request labels
  using their external IDs. The flags include their upstream MIT license.
- Studio artwork/logo and multi-server studio/genre navigation corrections,
  resilient multi-server genre loading, collection/playlist removal actions,
  Premiere ratings placement and Frost media filename display.
- Shared server API, setup, localization and workflow updates.

## Preserved TV behavior

Android remains the only app runner/build target. Deleted offline/download,
Apple/web and desktop deployment files remain deleted. The Android TV workflow
keeps a single TV job, imports the upstream action/runner versions and CI
Gradle memory limits, and retains Flutter 3.47.2.

Home retains its finite Modern card motion, single-background artwork with
independent logos/titles, bounded prefetch and deferred loading, visibility
gates and startup cover. The studio navigation fixes and poster label IDs
were adapted into that retained row implementation.

The player starts with controls hidden, retains Restart and the Back grace
period, and keeps speculative seek-preview downloads disabled during ordinary
viewing. Next-season requests still wait for the current stream to open.
Display-aware version selection and manual version overrides remain shared by
all nine detail layouts. Modern remains the default details style.

Seerr, achievements, readers/games and native Cast/DLNA senders remain outside
the TV profile. Their retained shared-code changes do not restore those routes
or startup services. Root dependencies/lockfile are unchanged; the pubspec
addition declares the new flag artwork assets.

## Validation

Logs and machine-readable evidence are in
`artifacts/upstream-sync-2026-11-06` in the integration worktree.

- Upstream feature regressions: 274 passed.
- Player controls/Restart/preview loading/Back grace: 14 passed.
- TV profile, startup/loading, artwork, display selection and playback session
  regressions: 169 passed.
- Detail layouts, membership/removal dialogs and studio matching: 54 passed.
- Android app native tests: 47 passed across seven suites.
- Native video tests: 512 passed across 51 suites.
- Server package suites: 150 core, 113 Emby, 70 Jellyfin, 82 Plex and 719 Silo
  tests passed. The 54 credential-dependent live Emby/Jellyfin cases were
  skipped because no live-server credentials were supplied.
- Full analysis: zero errors, with the same 11 unique warnings as the prior
  integration. Informational lints remain.

The Windows `flutter_tester.exe` terminated natively with exit code
`-1073741819` in some larger widget batches, reporting cases as "did not
complete" without a Dart assertion failure. All 15 Modern-card motion cases
passed when run in separate fresh test processes. The context-menu case about
the originating card disappearing also passed independently. These successful
runs cover 527 selected Flutter cases in total. The unsuccessful
batch logs are retained alongside the passing isolated runs; they are not
reported as full-suite passes.

This is selected regression coverage rather than a full inherited application
suite pass. No measured startup/frame-rate gain or receiver resume-audio fix
is claimed from these changes.
