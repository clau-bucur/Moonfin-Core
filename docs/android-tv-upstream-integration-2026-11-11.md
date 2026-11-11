# Android TV upstream integration - 2026-11-11

Follow-up: Seerr was restored after this deployment at the user's request and
is now a required TV feature. The Seerr exclusions recorded below describe the
earlier build and are superseded by [the restoration record](android-tv-seerr-restoration.md)
and [branch requirements](../AGENTS.md).

This sync integrates 194 upstream commits after
`f4f2899451a7e26e45d935cf4d5648235d8f9149`, through
`d31a38f8bd8cd9c1b15f6a4e6a1831187fc53b7f`. It retains real upstream merge
ancestry for the next update.

Pending local work was committed and pushed first as `9e13e0bb1`: TV chapter
filmstrips and transport navigation, replay of automatically skipped segments,
Next Up countdown cancellation on focus departure, and the detail autoplay
loading gate. Their localization and regression tests were included.

## Included upstream changes

- Subtitle bold, outline/shadow, downloadable font support and direct-play ASS
  sizing; Media3 MOV_TEXT placement fixes and recovery from container-reader
  failures. Track matching preserves the chosen subtitle across episodes.
- Configurable control hiding and HDR dimming, playback speed choices and TV
  sleep handling that waits for the playback stop report.
- Expanded Moonbase watch parties, rooms, voting, invitations, chat/reactions
  and synchronized playback, adapting the retained Flutter playback path.
- Detail action rows settle together, episode lists start at the current
  episode, richer season/episode cast, HDR format badges, and poster-label
  coverage in search, folders and details.
- Home row sorting/reload fixes, See All cards for latest/collection rows,
  library matches for external lists, and corrected server-side random media
  bar selection. The shared artwork helpers were imported while retaining
  this branch's card motion and rendering policy.
- Settings live previews, localized section headers and date formatting,
  responsive account picking, TV voice-search focus, Watch Next updates,
  Plex/Moonbase diagnostics and retained shared API/localization changes.

## Preserved Android TV behavior

Android TV remains the only app runner/build target. Removed downloads,
offline storage, push, native Cast/DLNA sender, reader and emulator stacks
remain removed. Newly introduced After Hours arcade code, assets and entry
points are excluded. Apple/desktop/web runner changes and the upstream
multi-platform CI workflows are excluded; the existing TV workflow and pinned
Flutter 3.47.2 SDK remain. Root dependencies and their lockfile are unchanged.
Shared models and widgets for excluded library types do not enable those
libraries or routes in the video profile.

Home retains its bounded/deferred work, startup cover, finite Modern card
motion, stable decode sizes and independent background/title artwork.
Seerr/Watching Now rows and automatic previews remain disabled in the TV
profile. Modern remains the default details layout. Display-aware version
selection and manual overrides remain shared by all nine detail layouts.

The detail view model still waits for its primary playback/navigation choices
before publishing ready. The new action-row settling timeout applies to the
remaining optional action inputs. Upstream concurrency tests were adapted to
start controlled pending loads without awaiting them before their responses
are supplied; they retain their stale-response assertions.

Playback retains hidden initial controls, Restart, the 750 ms Back grace
period, deferred preview metadata and disabled speculative preview downloads.
The local chapter filmstrip and skip-replay behavior are combined with the
upstream outro completion and track-selector remote-key fixes.

## Verification evidence

Logs, test results and deployment evidence are stored under the ignored
`artifacts/upstream-sync-2026-11-11` directory in the regular TV checkout.
The integration worktree is `.sync-1111` inside that checkout. Selected checks
are used; a complete inherited application-suite pass is not claimed.

Initial combined Windows widget runs stopped with incomplete cases before
the merge. Their logs are retained. Asynchronous upstream detail tests also
initially timed out under the retained TV readiness barrier; the adapted
tests passed separately after adaptation.

## Validation results

- 366 selected Flutter cases passed across TV startup/profile, display source
  selection/HDR probing, Home loading/artwork/See All/sorting, detail data and
  layouts, subtitles, watch parties, settings/date/locale/deep links, sleep,
  chapter navigation, autoplay, skip replay/countdowns and player controls.
- Native app: 47 cases across seven suites; native video: 516 cases across
  52 suites. No failures, errors or skips.
- Server/playback packages: 166 core, 115 Emby, 71 Jellyfin, 82 Plex, 720 Silo,
  three Plex playback and 102 Silo playback cases passed. The 54 live
  Emby/Jellyfin cases requiring credentials were skipped.
- Total: 2,188 selected cases passed. Full static analysis passed with zero
  errors and the same 11 existing warnings. Informational lints remain.

The successful final runs are enumerated in `validation-summary.json`.
Earlier failed/incomplete batches remain in the evidence directory and are
excluded from these counts. The three playback-card files were rerun in
separate processes; all 14 cases passed. This does not establish a complete
inherited-suite pass or a measured performance/audio-output improvement.

## Release build

`build-android-tv-video.ps1` passed with the pinned Flutter 3.47.2 SDK from
merge revision `53e8ea1a0e76d2c6f84eabd5cd88c0869cd686ce`.

- Package/label: `org.moonfin.androidtv.videoexperiment`, Moonfin Video Experiment.
- Version: `3.0.0`, build `2000023`.
- APK: 68,331,419 bytes; SHA-256
  `acae463279f2fd1dc5c9c94a6ee0760e98da60cbe8aba5241a186b762474684a`.
- Signing certificate SHA-256:
  `3af2f489977eec2dd8d1382d655e79e8f2b68ebf806275e87a9f859bf9ee3f82`,
  verified against the actual prior Shield APK.
- Delivery APK and size/provenance JSON:
  `artifacts/upstream-sync-2026-11-11/release-android-arm64` in the regular TV
  checkout. Flutter AOT targets ARM64; inherited support JNI libraries retain
  their existing ABI policy.

The earlier Shield APK (last updated November 8) was backed up before this
installation, with matching on-device and backup SHA-256 checksums. No app
data was cleared.

## Shield deployment

Installed with `adb install -r` on `shield.gme:5555`. The installed APK's
SHA-256 matches the release above. The first-install timestamp remains
`2026-11-02 18:27:32`, and the update timestamp is `2026-11-11 21:31:29`
(device local time).

The updated MainActivity resumed in the foreground on the awake Shield.
The screenshot shows a populated Home screen with its focused expanded card,
existing library/session and artwork. Its process remained running and the
startup log contained no fatal exception, fatal signal or unhandled exception
entries. `shield-deployment.json`, `shield-startup.log` and `shield-launch.png`
record these checks.

This was an installation and Home-screen smoke check. Media playback, HDR,
passthrough and receiver resume-audio behavior were not exercised, and the
Android launch timing is not a measurement of usable-Home performance.
